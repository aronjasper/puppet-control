class profiles::pypiserver(
  $listen_port = undef,
  ){

  class {'bandersnatch':
    document_root => '/srv/pypi',
    enable_cron   => false,
    }

  class { 'nginx':
  }

  nginx::resource::vhost { 'pypi-mirror':
    ensure      => present,
    listen_port => $listen_port,
    www_root    => '/srv/pypi/web',
    server_name => ['_'],
    autoindex   => 'on',
  }

  # Load SELinuux policy for NginX
  selinux::module { 'httpd_t':
    ensure => 'present',
    source => 'puppet:///modules/profiles/nginx_pypi.te'
  }

Class['::nginx::config'] -> Nginx::Resource::Vhost <| |>

}
