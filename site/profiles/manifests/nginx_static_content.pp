class profiles::nginx_static_content (
  $listen_port    = '8085',
  $server_name    = 'static_content',
  $root_dir       = '/srv/www/',
  $file_dir       = '/srv/www/files',
  $owner          = 'root',
  $group          = 'nginx',
  $download_files = {},
) {

  include ::nginx
  include ::wget

  file { $root_dir:
    ensure  => directory,
    owner   => $owner,
    group   => $group,
    mode    => '0755',
    recurse => true,
    require => Package['nginx'],
  }

  file { $file_dir:
    ensure  => directory,
    owner   => $owner,
    group   => $group,
    mode    => '0755',
    recurse => true,
    require => Package['nginx'],
  }

  nginx::resource::vhost { 'static_content':
    ensure      => present,
    listen_port => $listen_port,
    www_root    => $root_dir,
    server_name => [$server_name],
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

  $download_files_defaults = {
    mode    => '0755',
    require => File[$file_dir],
    notify  => Exec['update_files_ownership']
  }

  create_resources('wget::fetch', $download_files, $download_files_defaults)

  exec { 'update_files_ownership':
    command     => "/bin/chown -R $owner:$group $root_dir",
    refreshonly => true
  }
}
