# Class profiles::nagios_client
#
# This class will export server specific nagios resources for collection by a
# nagios server. Additional service resources can be looked up from heira.
#
# Parameters:
# ['interface'] - The interface on which nagios server connections will be accepted
# ['nagios_services'] - A hash of additional nagios services resources
#
# Requires:
# - landregistry/nagiosclient
#
# Sample Usage:
#
#   include profiles::nagios_client
#
# Hiera Lookups:
#
#  Example of  a node specific nagios service resources in heira:
#
#    profiles::nagios_client::nagios_services:
#      check_sshd_server3:
#        ensure: present
#        check_command: 'check_nrpe!check_sshd'
#        mode: '0644'
#        owner: root
#        use: generic-service
#        host_name: server3
#        notification_period: 24x7
#        service_description: sshd server3
#
#   Each node specific nagios service requires a coresponding nrpe command these
#   are also configured in heira.
#
#     nrpe_commands:
#       - 'command[check_sshd]=/usr/lib64/nagios/plugins/check_procs -c 1: -w 3: -C sshd'

class profiles::nagios_client(

  $interface         = eth1,
  $nagios_services   = hiera_hash('nagios_services', false),
  $time_period       = hiera('nagios_time_period', '24x7'),
  $contacts          = hiera_hash('nagios_contacts', false)

  ){

  $hostgroups = ["network_location_${::network_location}",$::application_environment,"puppet_${::puppet_environment}","service_${::service}"]

  # Check that host groups are configured on server (nagios server will fail to
  # start if a client adds itself to a host group that does not exist)
  define validate_hostgroups(

    $server_hostgroups = hiera_hash('nagios_hostgroups',{ network_location_zone1 => {},
                                                          development            => {},
                                                          puppet_local           => {},
                                                          service_test           => {}
                                                        }),
    ){
    if ! has_key($server_hostgroups, $name){
      fail ("hostgroup ${name} is not configured on the nagios server")
    }
  }

  validate_hostgroups { $hostgroups:}

  # create additional nrpe commands from hiera
  class { 'nagiosclient':
    nrpe_commands => hiera_array('nrpe_commands', undef)
  }

  # Export nagios host configuration
  @@nagios_host { $::hostname :
    ensure                => present,
    alias                 => $::hostname,
    address               => inline_template("<%= scope.lookupvar('::ipaddress_${interface}') -%>"),
    mode                  => '0644',
    owner                 => root,
    use                   => 'linux-server',
    max_check_attempts    => '5',
    check_period          => $time_period,
    notification_interval => '0',
    notification_period   => $time_period,
    contact_groups        =>"${::service},${::application_environment}",
    hostgroups            => join($hostgroups,',')
  }

  # Export nagios service configuration
  @@nagios_service { "check_ping_${::hostname}":
    ensure                => present,
    check_command         => 'check_ping!100.0,20%!500.0,60%',
    mode                  => '0644',
    owner                 => root,
    use                   => 'generic-service',
    host_name             => $::hostname,
    check_period          => $time_period,
    notification_period   => $time_period,
    notification_interval => '0',
    service_description   => 'Ping',
    contact_groups        => 'admins'
  }

  @@nagios_service { "check_load_${::hostname}":
    ensure                => present,
    check_command         => 'check_nrpe!check_load\!5.0,4.0,3.0\!10.0,6.0,4.0',
    mode                  => '0644',
    owner                 => root,
    use                   => 'generic-service',
    host_name             => $::hostname,
    check_period          => $time_period,
    notification_period   => $time_period,
    notification_interval => '0',
    service_description   => 'Current Load',
    contact_groups        => 'admins'
  }

  @@nagios_service { "check_current_users_${::hostname}":
    ensure                => present,
    check_command         => 'check_nrpe!check_users\!20\!50',
    mode                  => '0644',
    owner                 => root,
    use                   => 'generic-service',
    host_name             => $::hostname,
    check_period          => $time_period,
    notification_period   => $time_period,
    notification_interval => '0',
    service_description   => 'Current Users',
    contact_groups        => 'admins'
  }

  @@nagios_service { "check_root_partition_${::hostname}":
    ensure                => present,
    check_command         => 'check_nrpe!check_disk\!20%\!10%\!/',
    mode                  => '0644',
    owner                 => root,
    use                   => 'generic-service',
    host_name             => $::hostname,
    check_period          => $time_period,
    notification_period   => $time_period,
    notification_interval => '0',
    service_description   => 'Root Partition',
    contact_groups        => 'admins'
  }

  @@nagios_service { "check_ssh_${::hostname}":
    ensure                => present,
    check_command         => 'check_ssh',
    mode                  => '0644',
    owner                 => root,
    use                   => 'generic-service',
    host_name             => $::hostname,
    check_period          => $time_period,
    notification_period   => $time_period,
    notification_interval => '0',
    service_description   => 'SSH',
    contact_groups        => 'admins'
  }

  # Only add swap check if this is not an aws machine
  if ($::hosting_platform != dev_aws) and ($::hosting_platform != internal_aws)
      and ($::hosting_platform != nfr_aws) {
    @@nagios_service { "check_swap_${::hostname}":
      ensure                => present,
      check_command         => 'check_nrpe!check_swap\!20\!10',
      mode                  => '0644',
      owner                 => root,
      use                   => 'generic-service',
      host_name             => $::hostname,
      check_period          => $time_period,
      notification_period   => $time_period,
      notification_interval => '0',
      service_description   => 'Swap Usage',
      contact_groups        => 'admins'
    }
  }

  @@nagios_service { "check_procs_${::hostname}":
    ensure                => present,
    check_command         => 'check_nrpe!check_procs\!250\!400\!RSZDT',
    mode                  => '0644',
    owner                 => root,
    use                   => 'generic-service',
    host_name             => $::hostname,
    check_period          => $time_period,
    notification_period   => $time_period,
    notification_interval => '0',
    service_description   => 'Processes',
    contact_groups        => 'admins'
  }

  @@nagios_service { "check_mem_${::hostname}":
    ensure                => present,
    check_command         => 'check_nrpe!check_mem\!20\!10',
    mode                  => '0644',
    owner                 => root,
    use                   => 'generic-service',
    host_name             => $::hostname,
    check_period          => $time_period,
    notification_period   => $time_period,
    notification_interval => '0',
    service_description   => 'Ram Usage',
    contact_groups        => 'admins'
  }

  # create additional nagios services from hiera
  if $nagios_services {
    create_resources('@@nagios_service', $nagios_services)
  }
}
