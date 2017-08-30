# Class profiles::gitlab
# This class will manage Gitlab installations.
# Currently supports stand-alone only.
#
# Parameters:
#  ['backup_location'] - NFS location for backups
#  ['smtp_relay']      - SMTP relay server and port ('server:port')
#
# Requires:
# - vshn/gitlab
# - puppetlabs/firewall
#
# Sample Usage:
#   class { 'profiles::gitlab': }
#
class profiles::gitlab (

  $package_version  = installed,
  $external_url     = 'http://localhost',
  $enable_backup    = false,
  $backup_location  = 'undef',
  $backup_retention = 3, # in days
  $gitlab_crt       = '',
  $gitlab_key       = '',
  $smtp_relay       = undef,
  $ldap_enabled     = false,
  $ldap_host        = 'undef',
  $ldap_base        = 'undef',
  $ldap_bind_dn     = 'undef',
  $ldap_password    = 'undef',
  $aws_acccess_key  = undef,
  $aws_secret_key   = undef,
  $backup_method    = undef

){

  file { '/etc/gitlab' :
    ensure => directory,
    owner  => root,
    group  => root,
    mode   => '0700'
  }

  file { '/etc/gitlab/ssl' :
    ensure => directory,
    owner  => root,
    group  => root,
    mode   => '0700'
  }

  file { '/etc/gitlab/ssl/gitlab.crt' :
    ensure  => present,
    content => $gitlab_crt,
    owner   => root,
    group   => root,
    mode    => '0644'
  }

  file { '/etc/gitlab/ssl/gitlab.key' :
    ensure  => present,
    content => $gitlab_key,
    owner   => root,
    group   => root,
    mode    => '0400'
  }

  class { '::gitlab' :
    package_ensure => $package_version,
    external_url   => $external_url,
    require        => File['/etc/gitlab/ssl/gitlab.crt',
      '/etc/gitlab/ssl/gitlab.key'],

    gitlab_rails   => {
      gitlab_default_theme => 4,
      ldap_enabled         => $ldap_enabled,
      ldap_servers         => template('profiles/ldap_servers.erb'),
      backup_path          => '/var/opt/gitlab/backups',
      backup_keep_time     => ((($backup_retention * 24) * 60) * 60)  # Value needs to be converted to seconds
    },

    nginx          => {
      redirect_http_to_https => true,
      ssl_certificate        => '/etc/gitlab/ssl/gitlab.crt',
      ssl_certificate_key    => '/etc/gitlab/ssl/gitlab.key',
    },

    logging        => {
      svlogd_size    => 209715200,
      svlogd_num     => 30,
      svlogd_timeout => 86400,
      svlogd_filter  => 'gzip',
    },
  }

  if $enable_backup == true {

    cron  { 'gitlab-backup':
      command => '/opt/gitlab/bin/gitlab-rake gitlab:backup:create',
      user    => root,
      hour    => 2,
      minute  => 0
    }

    #Set up s3 backups if on AWS
    if $backup_method == 's3' {

      package { 's3cmd':
        ensure => present,
      }

      cron  { 's3-backup-syc':
        command => "s3cmd sync /var/opt/gitlab/backups s3://lr-gitlab-backups --access_key=${aws_acccess_key} --secret_key=${aws_secret_key}",
        user    => root,
        hour    => 2,
        minute  => 30
      }
    }

    #Set up nfs mount for internal backups
    if $backup_method == 'nfs' {

      package { 'nfs-utils' :
        ensure => present
      }

      mount { '/var/opt/gitlab/backups':
        ensure  => 'mounted',
        device  => $backup_location,
        fstype  => 'nfs',
        options => 'defaults',
        atboot  => true,
        require => Package [ 'nfs-utils' ]
      }
    }
  }

  file_line { 'internal smtp relay config':
    ensure => present,
    line   => "relayhost = ${smtp_relay}",
    path   => '/etc/postfix/main.cf',
  }
}
