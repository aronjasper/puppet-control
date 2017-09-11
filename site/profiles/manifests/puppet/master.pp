# Class: profiles::puppet::master
#
# This class installs and configures a Puppet Master on Nginx / Unicorn
# Also configures agent on for self management
#
# Parameters:
#  ['control_repo'] - URI of control repository
#  ['hiera_path']   - Path where hiera configuration file is placed
#
# Requires:
# - puppetlabs/puppetdb
# - zack/r10k
# - puppetlabs/firewall
#
# Sample Usage:
#  class { 'profiles::puppet::master':
#    control_repo => 'https://github.com/LandRegistry-Ops/puppet-control.git',
#  }
#
class profiles::puppet::master (

  $control_repo = 'https://github.com/LandRegistry-Ops/puppet-control.git',
  $hiera_path   = '/etc/puppet/hiera.yaml',
  $arguments    = '--no-daemonize --onetime --logdest syslog > /dev/null 2>&1',
  $run_hours    = '08-16',
  $run_days     = '1-5'

  ){

  # Set puppet environment from fact (set as production if fact does not exist)
    if $::puppet_environment != undef {
      notify { "Puppet environment ${::puppet_environment} set by fact":}
      $environment = $::puppet_environment
    } else {
      notify { 'Puppet environment not set by fact defaulting to production':}
      $environment = 'production'
    }

    # Configure puppetdb firewall
    include profiles::puppet::puppetdb_firewall

    # Install nginx
    include ::profiles::nginx

    # Install puppet-server package
    package { 'puppet-server' :
      ensure  => installed
    }

    # Configure puppet
    file { '/etc/puppet/puppet.conf':
      content => template('profiles/puppet.conf.erb'),
      owner   => puppet,
      group   => puppet,
      mode    => '0644'
    }

    # Ensure permissions are set correctly on puppet/environments dir
    file { '/etc/puppet/environments' :
      ensure => directory,
      owner  => puppet,
      group  => puppet,
      mode   => '0644'
    }

    # Install build dependancies
    $build_dependencies = ['make', 'gcc'] #'rubygems','ruby-devel'
    package { $build_dependencies :
      ensure => installed
    }

    # Install required gems
    package { 'rack' :
      ensure   => '1.6.4', # 1.6.4 is not dependennt on specific ruby version
      provider => gem,
      require  => Package [ $build_dependencies, 'rubygems','ruby-devel']
    }
    package { 'unicorn' :
      ensure   => installed,
      provider => gem,
      require  => Package [ $build_dependencies, 'rubygems','ruby-devel']
    }

    file { '/etc/puppet/config.ru' :
      ensure  => present,
      owner   => 'puppet',
      group   => 'puppet',
      source  => 'puppet:///modules/profiles/puppet_rack_config.ru',
      require => Package ['puppet-server']
    }

    # Create unicorn config
    file {'/etc/puppet/unicorn.conf' :
      ensure => present,
      owner  => 'puppet',
      group  => 'puppet',
      source => 'puppet:///modules/profiles/puppet_master_unicorn.conf'
    }

    # Ensure unicorn logging target is present
    file { '/var/log/unicorn_stderr.log' :
      ensure => present,
      owner  => 'puppet',
      group  => 'puppet'
    }

    # Configure Nginx
    file { '/etc/nginx/conf.d/puppetmaster.conf':
      content => template('profiles/puppetmaster.conf.erb'),
      owner   => root,
      group   => root,
      mode    => '0600',
      require => Service ['puppetmaster-unicorn'],
      notify  => Service['nginx']
    }

    # Ensure old puppet service is stopped
    exec { 'stop-puppetmaster' :
      command => '/usr/sbin/service puppetmaster stop',
      onlyif  => '/usr/sbin/service puppetmaster status'
    }->
    # Remove old puppetmaster service from systemd
    file { '/usr/lib/systemd/system/puppetmaster.service' :
      ensure  => absent,
    }->
    # Configure systemd to start puppet unicorn service
    file { '/etc/systemd/system/puppetmaster-unicorn.service' :
      ensure  => present,
      owner   => 'root',
      group   => 'root',
      source  => 'puppet:///modules/profiles/puppetmaster-unicorn.service',
      notify  => Exec ['systemctl daemon-reload'],
      require => Package ['unicorn','rack']
    }->
    # Reload systemd to pick up config changexs
    exec {'systemctl daemon-reload' :
      command     => '/usr/bin/systemctl daemon-reload',
      refreshonly => true
    }->
    # Start puppet master service
    service { 'puppetmaster-unicorn' :
      ensure  => running,
      enable  => true,
      require => File ['/etc/systemd/system/puppetmaster-unicorn.service']
    }

    # Check that puppe-master cert file has been written
    exec {'check_presence':
      command => '/bin/true',
      onlyif  => '/usr/bin/test -e /var/lib/puppet/ssl/certs/puppet-master.dev.ctp.local.pem',
    }

    # puppetlabs/puppetdb
    class { '::puppetdb':
      listen_address     => '0.0.0.0',
      ssl_set_cert_paths => true,
      ssl_cert_path      => "/var/lib/puppet/ssl/certs/${::fqdn}.pem",
      ssl_key_path       => "/var/lib/puppet/ssl/private_keys/${::fqdn}.pem",
      ssl_ca_cert_path   => '/var/lib/puppet/ssl/certs/ca.pem',
      require            => Exec ['check_presence']
    }

    class { 'puppetdb::master::config':
      puppetdb_server     => $::fqdn,
      puppetdb_port       => 8081,
      puppet_service_name => 'puppetmaster-unicorn.service',
      require             => Exec ['check_presence']
    }

    # zack/r10k
    class { '::r10k':
      configfile                => '/etc/puppet/r10k.yaml',
      configfile_symlink        => '/etc/r10k.yaml',
      manage_configfile_symlink => true,
      manage_modulepath         => false,
      sources                   => {
        'control' => {
          'remote'  => $control_repo,
          'basedir' => "${::settings::confdir}/environments",
          'prefix'  => false
        }
      }
    }
    # Ensure puppetdb user is in the puppet group to allow access to certs
    user { 'puppetdb' :
      groups => puppet
    }

    # Manage hiera file
    file { $hiera_path :
      ensure => present,
      path   => $hiera_path,
      owner  => 'puppet',
      group  => 'puppet',
      mode   => '0644',
      source => 'puppet:///modules/profiles/hiera.yaml'
    }

    # Ensure secrets script is installed on the master
    file { '/usr/local/bin/secrets':
      ensure => present,
      path   => '/usr/local/bin/secrets',
      owner  => 'root',
      group  => 'root',
      mode   => '0755',
      source => 'puppet:///modules/profiles/secrets.sh'
    }

    # Clean up redundant folders
    file { '/etc/puppet/templates':
      ensure => absent,
      force  => true
    }

    file { '/etc/puppet/modules':
      ensure => absent,
      force  => true
    }

    # Load SELinuux policy for NginX
    selinux::module { 'puppetmaster':
      ensure      => 'present',
      syncversion => false,
      source      => 'puppet:///modules/profiles/puppetmaster.te'
    }

    # Configure puppet agent runs
    cron { 'puppet-agent':
      command => "/usr/bin/puppet agent ${arguments}",
      user    => root,
      minute  => [0,30],
      hour    => $run_hours,
      weekday => $run_days,
    }
}
