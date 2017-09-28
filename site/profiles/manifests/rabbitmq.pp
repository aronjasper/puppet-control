# Class profiles::rabbitmq
#
# This class will manage rabbitmq installations
#
# Parameters:
#  ['port']    - Port which RabbitMQ should listen on. Defaults = 5672
#  ['version'] - Version of RabbitMQ to install. Default = 3.4.4
#
# Requires:
# - puppetlabs/rabbitmq
# - garethr/erlang
#
# Sample Usage:
#   class { 'profiles::rabbitmq':
#     version => '3.4.4'
#   }
#
class profiles::rabbitmq(

  $port                      = 5672,
  $version                   = '3.4.4',
  $delete_guest_user         = true,
  $default_user              = 'guest',
  $default_pass              = 'guest',
  $cluster                   = false,
  $cluster_nodes             = [],
  $erlang_cookie             = 'super_secret_key',
  $erlang_epel_enable        = true,
  $admin_enable              = false,
  $monitoring                = true,
  $repos_ensure              = true,
  $rabbitmq_users            = hiera_hash('rabbitmq_users', false),
  $rabbitmq_user_permissions = hiera_hash('rabbitmq_user_permissions', false),
  $rabbitmq_vhosts           = hiera_hash('rabbitmq_vhosts', false),
  $rabbitmq_policy           = hiera_hash('rabbitmq_policy', false),
  $time_period               = hiera('nagios_time_period', '24x7'),
  $package_source            = undef,
  $rabbitmq_key              = undef,
  $package_gpg_key           = undef,
){

  if $monitoring {
    include profiles::rabbitmq_monitoring
  }
  # Load SELinuux policy for RabbitMQ
  selinux::module { 'rabbit':
    ensure => 'present',
    source => 'puppet:///modules/profiles/rabbit.te'
  }

  class { 'erlang': epel_enable => $erlang_epel_enable }
  include ::erlang

  $real_source = $package_source ? {
    undef   => "https://www.rabbitmq.com/releases/rabbitmq-server/v${version}/rabbitmq-server-${version}-1.noarch.rpm",
    default => $package_source
  }

  # Install rabbit direct from rabbit (if not epel version)
  if $version != '3.3.5' {
    package { "rabbitmq-server-${version}-1.noarch" :
      ensure   => 'installed',
      provider => 'rpm',
      source   => $real_source,
      require  => Class[erlang],
    }
    notify { "rabbit-server package version ${version} installed direct from rabbit":}
  } else {
    notify { "rabbit-server package version ${version} will be installed from epel":}
  }

  if $rabbitmq_key {
    file{ $package_gpg_key:
      ensure  => file,
      content => $rabbitmq_key,
    }
  }

  case $cluster {
    true : {
      class { '::rabbitmq':
        key_content              => $rabbitmq_key,
        package_gpg_key          => $package_gpg_key,
        version                  => "${version}-1",
        repos_ensure             => $repos_ensure,
        port                     => $port,
        default_user             => $default_user,
        default_pass             => $default_pass,
        delete_guest_user        => $delete_guest_user,
        cluster_nodes            => $cluster_nodes,
        cluster_node_type        => 'disc',
        erlang_cookie            => $erlang_cookie,
        wipe_db_on_cookie_change => true,
        config_cluster           => true,
        admin_enable             => $admin_enable,
        require                  => Class[erlang]

      }

    }

    default : {
      class { '::rabbitmq':
        key_content       => $rabbitmq_key,
        package_gpg_key   => $package_gpg_key,
        version           => "${version}-1",
        repos_ensure      => $repos_ensure,
        port              => $port,
        default_user      => $default_user,
        default_pass      => $default_pass,
        delete_guest_user => $delete_guest_user,
        admin_enable      => $admin_enable,
        require           => Class[erlang]
      }
    }
  }

  include stdlib

  if $rabbitmq_users {
    create_resources('rabbitmq_user', $rabbitmq_users)
  }
  if $rabbitmq_user_permissions {
    create_resources('rabbitmq_user_permissions', $rabbitmq_user_permissions)
  }
  if $rabbitmq_vhosts {
    create_resources('rabbitmq_vhost', $rabbitmq_vhosts)
  }
  if $rabbitmq_policy {
    create_resources('rabbitmq_policy', $rabbitmq_policy)
  }
}
