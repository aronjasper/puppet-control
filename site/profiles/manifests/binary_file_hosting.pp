class profiles::binary_file_hosting (

  $root_dir    = '/srv/file_hosting/',
  $file_dir    = '/srv/file_hosting/files',
  $listen_port = 8085,
  ) {
  class { 'nginx':
  }

  file { $root_dir:
    ensure  => directory,
    recurse => true,
  }

  file { $file_dir:
    ensure  => directory,
    recurse => true,
  }

  nginx::resource::vhost { 'binary_file_hosting':
    ensure      => present,
    listen_port => $listen_port,
    www_root    => $root_dir,
    server_name => ['binary_file_hosting'],
    autoindex   => 'on',
  }

  selinux::module { 'nginx_unreservedport':
    ensure => 'present',
    source => 'puppet:///modules/profiles/nginx_unreservedport.te'
  }

  Class['::nginx::config'] -> Nginx::Resource::Vhost <| |>

}
