# Class profiles::rabbitmq_monitoring
#
# This class will set up nagios checks for rabbit installations
#
# Parameters:

class profiles::rabbitmq_monitoring(


  $cluster_nodes   = hiera('profiles::rabbitmq::cluster_nodes', []),
  $rabbitmq_users  = hiera_hash('rabbitmq_users', false),
  $rabbitmq_vhosts = hiera_hash('rabbitmq_vhosts', false),
  $time_period     = hiera('nagios_time_period', '24x7')

  ){
  # Install rabbit nagios plugins and dependancies
  $nagios_plugins = ['check_rabbitmq_aliveness','check_rabbitmq_cluster',
                    'check_rabbitmq_queue']
  $dependancies = ['perl-Monitoring-Plugin.noarch',
                    'perl-LWP-UserAgent-Determined.noarch','perl-JSON.noarch']
  ensure_packages($dependancies)

  define nagios_plugins(){
    file { $name :
        ensure  => 'present',
        path    => "/usr/lib64/nagios/plugins/${name}",
        owner   => 'root',
        group   => 'root',
        mode    => '0755',
        source  => "puppet:///modules/profiles/nagios_plugins/rabbitmq/${name}",
        require => Package['nrpe']
    }
  }

  nagios_plugins{$nagios_plugins:}

  # Add nrpe commands
  $nrpe_commands = ['command[check_rabbitmq_aliveness]=/usr/lib64/nagios/plugins/check_rabbitmq_aliveness -H localhost --vhost $ARG1$ -u $ARG2$ -p $ARG3$',
  'command[check_rabbitmq_cluster]=/usr/lib64/nagios/plugins/check_rabbitmq_cluster -H localhost -c $ARG1$ -u $ARG2$ -p $ARG3$',
  'command[check_rabbitmq_queue]=/usr/lib64/nagios/plugins/check_rabbitmq_queue -H localhost --vhost $ARG1$ -u $ARG2$ -p $ARG3$',
  'command[check_rabbitmq_individual_queue]=/usr/lib64/nagios/plugins/check_rabbitmq_queue -H localhost --vhost $ARG1$ -u $ARG2$ -p $ARG3$ --queue $ARG4$ -c $ARG5$']

  define nrpe_commands(){
    file_line { $name :
      path   => '/etc/nagios/nrpe.cfg',
      line   => $name,
      after  => '# Additional commands added via puppet',
      notify => Service['nrpe']
    }
  }

  nrpe_commands{$nrpe_commands:}

  file {'rabbit fact script':
    ensure => 'present',
    path   => '/etc/puppetlabs/facter/facts.d/rabbit_queue_facts.sh',
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
    source => 'puppet:///modules/profiles/rabbit_queue_facts.sh',
  }

  # Get rabbit admin creds for checks
  # Assumes that rabbitadmin user is the first in the hash - yeah, yeah I know....
  if $rabbitmq_users {
    $creds = hash_filter($rabbitmq_users, ['password'])
    #notify {"creds = ${creds}":}
    $unames = keys($rabbitmq_users)
    $admin_uname = $unames[0]
    #notify {"admin uname = ${admin_uname}":}
    $admin_pword = $rabbitmq_users[($admin_uname)]['password']
    #notify {"admin pword = ${admin_pword}":}
  }

  # Export nagios service check resources

  # Define aliveness check
  define rabbitmq_aliveness(

    $notification_period = undef,
    $check_period = undef,
    $user_name = undef,
    $passwd = undef,

    ){
    @@nagios_service { "${::hostname}-rabbitmq_aliveness-${name}" :
      ensure                => present,
      check_command         => "check_nrpe!check_rabbitmq_aliveness\\!'${name}'\\!'${user_name}'\\!'${passwd}'",
      mode                  => '0644',
      owner                 => root,
      use                   => 'generic-service',
      host_name             => $::hostname,
      check_period          => $check_period,
      contact_groups        => 'admins',
      notification_interval => 0,
      notifications_enabled => 1,
      notification_period   => $notification_period,
      service_description   => "Rabbitmq aliveness ${name}"
    }
  }

  # Create aliveness check for each defined rabbit vhost
  if $rabbitmq_vhosts {
    $vhost = keys($rabbitmq_vhosts)
    rabbitmq_aliveness{$vhost:
      notification_period => $time_period,
      check_period        => $time_period,
      user_name           => $admin_uname,
      passwd              => $admin_pword
    }
  }
  # Create aliveness check for default rabbit vhost
  rabbitmq_aliveness{'/':
    notification_period => $time_period,
    check_period        => $time_period,
    user_name           => $admin_uname,
    passwd              => $admin_pword
  }

    # Determine how many hosts in the cluster and set critical level
    $no_of_nodes = count($cluster_nodes)
    if $no_of_nodes > 0 {
      $cluster_crit = ($no_of_nodes - 1)
    } else {
      $cluster_crit = 0
    }

    # Export cluster check resource
    @@nagios_service { "${::hostname}-rabbitmq_cluster" :
      ensure                => present,
      check_command         => "check_nrpe!check_rabbitmq_cluster\\!'${cluster_crit}'\\!'${admin_uname}'\\!'${admin_pword}'",
      mode                  => '0644',
      owner                 => root,
      use                   => 'generic-service',
      host_name             => $::hostname,
      check_period          => $check_period,
      contact_groups        => 'admins',
      notification_interval => 0,
      notifications_enabled => 1,
      notification_period   => $notification_period,
      service_description   => 'Rabbitmq cluster status'
    }

  # Define type to create check for individual queues
  # NB There can be no queues with duplicate names
  define individual_queue_check (

    $notification_period,
    $check_period,
    $user_name,
    $passwd,
    $vhost,

    ) {

    # Standard threshold is 10 (higer for error queues)
    # Assumes that only error queses will contain the string 'error' in their names
    if 'error' in $name {
      $threshold=100000
    } else {
      $threshold=10
    }

    # Export individual check resource
    @@nagios_service { "${::hostname}-rabbitmq_queue-${name}" :
      ensure                => present,
      check_command         => "check_nrpe!check_rabbitmq_individual_queue\\!'${vhost}'\\!'${user_name}'\\!'${passwd}'\\!'${name}'\\!'${threshold}'",
      mode                  => '0644',
      owner                 => root,
      use                   => 'generic-service',
      host_name             => $::hostname,
      check_period          => $check_period,
      contact_groups        => 'admins',
      notification_interval => 0,
      notifications_enabled => 1,
      notification_period   => $notification_period,
      service_description   => "Rabbitmq queue status ${name}"
    }
  }

  # Define resource to call individual check resource for each queue on a vhost
  define queue_check_for_vhost (

    $notification_period = undef,
    $check_period = undef,
    $user_name = undef,
    $passwd = undef,
    $queues = undef,

    ) {

    individual_queue_check { $queues :
      notification_period => $notification_period,
      check_period        => $check_period,
      user_name           => $user_name,
      passwd              => $passwd,
      vhost               => $name
    }

  }

  # Create queue check for each defined rabbit vhost
  if $rabbitmq_vhosts {
    queue_check_for_vhost { $vhost:
      notification_period => $time_period,
      check_period        => $time_period,
      user_name           => $admin_uname,
      passwd              => $admin_pword,
      queues              => split(inline_template("<%= scope.lookupvar('::vhost_${vhost}') -%>"), ' ')
    }
  }

  # Create queue check for default rabbit vhost
  queue_check_for_vhost { '/':
    notification_period => $time_period,
    check_period        => $time_period,
    user_name           => $admin_uname,
    passwd              => $admin_pword,
    queues              => split($::vhost_default_vhost, ' ')
  }
}
