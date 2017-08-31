class profiles::clamav_localdef (
  ) {
  $clamdir = '/opt/clam'

  class { 'nginx':
  }

  class { 'cpan':
  }

  file { $clamdir:
    ensure => 'directory',
  }

  nginx::resource::vhost { 'clamavd':
    ensure      => present,
    listen_port => 8080,
    www_root    => $clamdir,
    server_name => ['_'],
    autoindex   => 'on',
  }

  # Load SELinux policy for NginX - Allowing freshclam to read files
  selinux::module { 'nginx_freshclam':
    ensure => 'present',
    source => 'puppet:///modules/profiles/nginx_freshclam.te'
  }

  Class['::nginx::config'] -> Nginx::Resource::Vhost <| |>

  cpan { 'Net::DNS':
    ensure    => present,
  }

}
