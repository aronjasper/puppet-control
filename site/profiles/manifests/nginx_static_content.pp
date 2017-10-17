# Class profile::nginx_static_content
#
# Sets up Nginx service for hosting static content.
#
# == Dependencies
# - maestrodev/wget
# - jfryman/nginx
#
# === Parameters
# [*listen_port*]
# Port that Nginx will be listening on.
# Default: '8085'
#
# [*server_name*]
# Server name for the site.
# Default: 'static_content'
#
# [*root_dir*]
# Root directory for files subdirectories.
# Default: '/srv/www'
#
# [*file_dirs*]
# List of subdirectories for storing files.
# Default: ['/srv/www/files']
#
# [*owner*]
# User permissions for the files.
# Default: 'root'
#
# [*group*]
# Group permissions for the files.
# Default: 'nginx'
#
# [*download_files*]
# Hash of files to download. Uses maestrodev/wget module (https://github.com/maestrodev/puppet-wget).
# Default: {}
#

class profiles::nginx_static_content (
  $listen_port    = '8085',
  $server_name    = ['static_content'],
  $root_dir       = '/srv/www/',
  $file_dirs      = ['/srv/www/files'],
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

  file { $file_dirs:
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
    server_name => $server_name,
    autoindex   => 'on',
    require     => File[$file_dirs]
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
    require => File[$file_dirs],
    notify  => Exec['update_files_ownership']
  }

  create_resources('wget::fetch', $download_files, $download_files_defaults)

  exec { 'update_files_ownership':
    command     => "/bin/chown -R ${owner}:${group} ${root_dir}; /bin/chmod -R 0755 ${root_dir}",
    refreshonly => true
  }
}
