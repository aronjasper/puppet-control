# Class profiles::jenkins
# This class will manage Jenkins installations.
# Currently supports stand-alone only.
#
# Parameters:
#  ['jenkins_plugins'] - Accepts a hash of Jenkins Plugins
#
# Requires:
# - rtyler/jenkins
# - puppetlabs/firewall
#
# Sample Usage:
#   class { 'profiles::jenkins': }
#
# Hiera:
#   profiles::jenkins::plugins:
#     git:
#       version: latest
#
class profiles::jenkins (

  $plugins                 = hiera_hash('jenkins_plugins', false),
  $jobs                    = undef,
  $repo                    = undef,
  $deploy_from_jenkins_rsa = undef,
  $version                 = '1.651-1.1',
  $phantomjs_version       = '1.9.8',
  $jenkins_url             = [ $::hostname ],
  $jenkins_ssl             = false,
  $ssl_protocols           = 'TLSv1 SSLv3',
  $ssl_ciphers             = 'RC4:HIGH:!aNULL:MD5:@STRENGTH',
  $ssl_crt                 = '',
  $ssl_key                 = '',
  $ci_test_tools           = false,
  $g10k_version            = '0.3.12',
  ){

  # HTTPS redirect / proxy
  if $jenkins_ssl == true {

    include ::profiles::nginx

    file { '/etc/ssl/keys/' :
      ensure => directory,
      owner  => root,
      group  => root,
      mode   => '0700'
    }

    file { '/etc/ssl/certs/ssl.crt' :
      ensure  => present,
      content => $ssl_crt,
      owner   => root,
      group   => root,
      mode    => '0644'
    }

    file { '/etc/ssl/keys/ssl.key' :
      ensure  => present,
      content => $ssl_key,
      owner   => root,
      group   => root,
      mode    => '0400',
      require => File['/etc/ssl/keys/']
    }

    # Load SELinuux policy for NginX
      selinux::module { 'nginx_jenkins':
      ensure => 'present',
      source => 'puppet:///modules/profiles/nginx_jenkins.te'
    }

    # Load SELinuux policy for NginX
    selinux::module { 'nginx_unreservedport':
      ensure => 'present',
      source => 'puppet:///modules/profiles/nginx_unreservedport.te'
    }

    nginx::resource::vhost { 'https_redirect':
      server_name      => [ $jenkins_url ],
      listen_port      => 80,
      www_root         => '/usr/share/nginx/html',
      vhost_cfg_append => {
        'return' => '301 https://$server_name$request_uri'}
    }

    nginx::resource::vhost { 'jenkins_proxy':
      server_name    => [ $jenkins_url ],
      listen_port    => 443,
      # proxy_set_header => ['X-Forward-For $proxy_add_x_forwarded_for',
      # 'X-Real-IP $remote_addr', 'Client-IP $remote_addr', 'Host $http_host'],
      proxy_redirect => 'off',
      proxy          => 'http://127.0.0.1:8080',
      ssl            => true,
      ssl_cert       => '/etc/ssl/certs/ssl.crt',
      ssl_key        => '/etc/ssl/keys/ssl.key',
      ssl_protocols  => $ssl_protocols,
      ssl_ciphers    => $ssl_ciphers,
      require        => File['/etc/ssl/certs/ssl.crt',
      '/etc/ssl/keys/ssl.key'],
    }
  }

  # rtyler/jenkins
  class { '::jenkins':
    plugin_hash        => $plugins,
    port               => 8080,
    configure_firewall => false,
    job_hash           => $jobs,
    version            => $version,
    repo               => hiera('jenkins_manage_repo', true),
  }

  file { '/var/lib/jenkins/.ssh':
    ensure => directory,
    owner  => 'jenkins',
    group  => 'jenkins',
    mode   => '0700'
  }

  file { '/var/lib/jenkins/.ssh/id_rsa':
    ensure  => 'present',
    content => $deploy_from_jenkins_rsa,
    owner   => 'jenkins',
    group   => 'jenkins',
    mode    => '0400',
    require => File['/var/lib/jenkins/.ssh']
  }

  # ensure artifact script is installed
  file { '/usr/bin/artifact':
    ensure => present,
    path   => '/usr/local/bin/artifact',
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
    source => 'puppet:///modules/profiles/artifact.sh'
  }

  # ensure artifact script is installed
  file { '/usr/bin/artifact2':
    ensure => present,
    path   => '/usr/local/bin/artifact2',
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
    source => 'puppet:///modules/profiles/artifact2.sh'
  }

  file { '/usr/bin/deploy':
    ensure => present,
    path   => '/usr/local/bin/deploy',
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
    source => 'puppet:///modules/profiles/deploy.sh'
  }

  file { '/usr/bin/deploy2':
    ensure => present,
    path   => '/usr/local/bin/deploy2',
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
    source => 'puppet:///modules/profiles/deploy2.sh'
  }

  # ensure app-deploy script is installed
  file { '/usr/bin/app-deploy':
    ensure => present,
    path   => '/usr/local/bin/app-deploy',
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
    source => 'puppet:///modules/profiles/app-deploy.sh'
  }

  # ensure app-deploy script is installed
  file { '/usr/bin/app-deploy-api':
    ensure => present,
    path   => '/usr/local/bin/app-deploy-api',
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
    source => 'puppet:///modules/profiles/app-deploy-api.sh'
  }

  # ensure app-deploy script is installed
  file { '/usr/bin/app-deploy-login-api':
    ensure => present,
    path   => '/usr/local/bin/app-deploy-login-api',
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
    source => 'puppet:///modules/profiles/app-deploy-login-api.sh'
  }

  # ensure r10k is installed
  package { 'r10k':
    ensure   => 'installed',
    provider => 'gem',
  }

  archive {"g10k-${g10k_version}":
    ensure           => present,
    url              => "https://github.com/xorpaul/g10k/releases/download/v${g10k_version}/g10k-linux-amd64.zip",
    target           => "/opt/g10k/g10k-${g10k_version}",
    root_dir         => '.',
    checksum         => false,
    follow_redirects => true,
    extension        => 'zip',
    src_target       => '/opt',
    before           => File["/opt/g10k/g10k-${g10k_version}/g10k"],
  }

  file {"/opt/g10k/g10k-${g10k_version}/g10k":
    ensure => present,
    mode   => '0755',
  }

  file {'/usr/local/bin/g10k':
    ensure  => 'link',
    target  => "/opt/g10k/g10k-${g10k_version}/g10k",
    require => File["/opt/g10k/g10k-${g10k_version}/g10k"]
  }


  if $ci_test_tools == true {

    package { 'bundler':
      ensure   => 'installed',
      provider => 'gem',
    }

    class { '::phantomjs':
      package_version => $phantomjs_version,
      package_update  => false,
      install_dir     => '/usr/local/bin',
      source_dir      => '/opt',
      timeout         => 300
    }

    ensure_packages(['libcurl-devel', 'patch', 'libxml2-devel',
      'libxslt-devel', 'gcc', 'ruby-devel', 'zlib-devel', 'postgresql-devel',
      'openssl-devel', 'readline-devel', 'libffi-devel', 'gcc-c++',
      'libjpeg-turbo-devel', 'zlib-devel', 'bzip2-devel'])

  }

}
