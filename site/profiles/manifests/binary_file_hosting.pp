class profiles::binary_file_hosting (

  $root_dir    = '/opt/file_hosting/',
  $file_dir    = '/opt/file_hosting/files',
  $listen_port = 8085,
  $remote_files_to_download = hiera_hash('remote_files_to_download',false),
  ) {

  file { $root_dir:
    ensure  => directory,
    recurse => true,
  }

  file { $file_dir:
    ensure  => directory,
    recurse => true,
  }


#if $remote_files_to_download {

## Hiera
# remote_files_to_download:
#   opendj:
#     remote_location: 'https://github.com/OpenRock/OpenDJ/releases/download/3.0.0/OpenDJ-3.0.0.zip'
#     file_name: 'opendj3.zip'


define remote_file($remote_location=undef, $mode='0644'){
  exec{"retrieve_${title}":
    command => "/usr/bin/wget -q ${remote_location} -O ${file_dir}${title}",
    creates => "${file_dir}${title}",
  }

  file{$title:
    mode    => $mode,
    require => Exec["retrieve_${title}"],
  }
}

#create_resources('profiles::binary_file_hosting_get_files', $remote_files_to_download)

# remote_file{"/${file_name}":
#   remote_location => $remote_location,
#   mode            => '0755',
# }

remote_file{"/OpenDJ-3.0.0.zip":
  remote_location => 'https://github.com/OpenRock/OpenDJ/releases/download/3.0.0/OpenDJ-3.0.0.zip',
  mode            => '0755',
}

#}
  nginx::resource::vhost { 'binary_file_hosting':
    ensure      => present,
    listen_port => $listen_port,
    www_root    => $root_dir,
    server_name => ['binary_file_hosting'],
    autoindex   => 'on',
    require     => Class['Nginx']
  }

  selinux::module { 'nginx_unreservedport':
    ensure => 'present',
    source => 'puppet:///modules/profiles/nginx_unreservedport.te'
  }

  Class['::nginx::config'] -> Nginx::Resource::Vhost <| |>

# }

# class profiles::binary_file_hosting_get_files (
#   $remote_location = undef,
#   $file_name = undef,
#   ){

# define remote_file($remote_location=undef, $mode='0644'){
#   exec{"retrieve_${title}":
#     command => "/usr/bin/wget -q ${remote_location} -O ${file_dir}${title}",
#     creates => "${file_dir}${title}",
#   }

#   file{$title:
#     mode    => $mode,
#     require => Exec["retrieve_${title}"],
#   }


# # remote_file{"/${file_name}":
# #   remote_location => $remote_location,
# #   mode            => '0755',
# # }
# }
}
