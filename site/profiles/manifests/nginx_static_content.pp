class profiles::nginx_static_content (
  $root_dir    = '/srv/www/',
  $file_dir    = '/srv/www/llc-files',
  $listen_port = '8085',
) {

  include ::nginx

  file { $root_dir:
    ensure  => directory,
    owner   => 'root',
    group   => 'nginx',
    mode    => '0755',
    recurse => true,
    require => Package['nginx'],
  }

  file { $file_dir:
    ensure  => directory,
    owner   => 'root',
    group   => 'nginx',
    mode    => '0755',
    recurse => true,
    require => Package['nginx'],  
  }

  nginx::resource::vhost { 'static_content':
    ensure      => present,
    listen_port => $listen_port,
    www_root    => $root_dir,
    server_name => ['static_content'],
    autoindex   => 'on',
    require     => File[$file_dir]
  }

  selinux::module { 'nginx_unreservedport':
    ensure => 'present',
    source => 'puppet:///modules/profiles/nginx_unreservedport.te'
  }

  selinux::module { 'nginx_files_hosting':
    ensure => 'present',
    source => 'puppet:///modules/profiles/nginx_files_hosting.te'
  }
}
