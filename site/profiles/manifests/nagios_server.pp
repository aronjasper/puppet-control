# Class profiles::nagios_server
#
# This class will manage nagios resources created from heira lookups and
# collected resources esported from nagios client nodes.
#
# Parameters:
#  ['nagios_hosts'] - Hash of additional nagios host resrources.
#  ['nagios_hostgroups'] - Hash of additional nagios hostgroup resrources.
#  ['nagios_services'] - Hash of additional nagios service resrources.
#  ['nagios_commands'] - Hash of additional nagios command resrources.
#  ['nagios_contacts'] - Hash of nagios contact resrources.
#  ['nagios_contactgroups'] - Hash of nagios contactgroup resrources.
#  ['monitor_localhost'] - Whether the server should monitro itself as localhost
#                          Defaults to false - should be set to true for testing
#                          when no master is present.
#
# Requires:
# - landregistry/nagios
#
# Sample Usage:
#
#   include profiles::nagios_server
#
# Hiera Lookups:
#
#  Turn on monitoring of localhost to facillitate masterless testing:
#    profiles::nagios_server::monitor_localhost: true
#
#  Example of nagios resources in heira:
#
#    nagios_hosts:
#      test_host:
#        ensure: present
#        alias: test_host
#        address: 192.168.42.51
#        mode: '0644'
#        owner: root
#        use: linux-server
#        max_check_attempts: 5
#        check_period: 24x7
#        notification_interval: 0
#        notification_period: 24x7
#
#    nagios_services:
#      check_ping_test_host:
#        ensure: present
#        check_command: check_ping!100.0,20%!500.0,60%
#        mode: '0644'
#        owner: root
#        use: generic-service
#        host_name: test_host
#        notification_period: 24x7
#        notification_interval: 0
#        service_description: Ping
#
#    nagios_hostgroups:
#      network_location_zone1:
#        ensure: present
#        alias: hostgroup-network_location_zone1
#      development:
#        ensure: present
#        alias: hostgroup-development
#      puppet_local:
#        ensure: present
#        alias: hostgroup-puppet_local
#      service_test:
#        ensure: present
#        alias: hostgroup-service_test

class profiles::nagios_server(

  $nagios_hosts         = hiera_hash('nagios_hosts',false),
  $nagios_hostgroups    = hiera_hash('nagios_hostgroups',{ network_location_zone1 =>
                                                              {ensure => present,
                                                              alias  => 'hostgroup-network_location_zone1'},
                                                            development =>
                                                              {ensure => present,
                                                              alias  => 'hostgroup-development'},
                                                            puppet_local =>
                                                              {ensure => present,
                                                              alias  => 'hostgroup-puppet_local'},
                                                            service_test =>
                                                              {ensure => present,
                                                              alias  => 'hostgroup-service_test'}}),
  $nagios_services      = hiera_hash('nagios_services',false),
  $nagios_commands      = hiera_hash('nagios_commands',false),
  $nagios_contacts      = hiera_hash('nagios_contacts',false),
  $nagios_contactgroups = hiera_hash('nagios_contactgroups',{test => {alias => contactgroup-test},
                                                            development => {alias => contactgroup-development}}),
  $monitor_localhost    = false,

  ){

  include nagios
  include profiles::smtp_relay

  # Create time period for aws_dev servers to prevent alertiing when servers
  # with the 'managed' tag are shutdown. Adjusted for BST (Server time is UTC)
  nagios_timeperiod { 'dev_aws':
    ensure    => present,
    alias     => 'Time during which managed aws_dev servers should be up',
    monday    => '06:10-18:50',
    tuesday   => '06:10-18:50',
    wednesday => '06:10-18:50',
    thursday  => '06:10-18:50',
    friday    => '06:10-18:50'
  }

  # Collect nagios resources from puppetdb
  Nagios_host <<||>> {
    require => Package['nagios'],
    notify  => Service['nagios']
  }

  Nagios_hostgroup <<||>> {
    require => Package['nagios'],
    notify  => Service['nagios']
  }

  Nagios_service <<||>> {
    require => Package['nagios'],
    notify  => Service['nagios']
  }

  Nagios_command <<||>> {
    require => Package['nagios'],
    notify  => Service['nagios']
  }

  # Import nagios resources from heira
  $resource_defaults        = {notify  => Service['nagios']}
  $contact_resource_defauts = {host_notifications_enabled   => '1',
                              service_notifications_enabled => '1',
                              service_notification_period   => '24x7',
                              host_notification_period      => '24x7',
                              service_notification_options  => 'u,c',
                              host_notification_options     => 'd,u',
                              service_notification_commands => 'notify-service-by-email',
                              host_notification_commands    => 'notify-host-by-email',
                              can_submit_commands           => '1',
                              notify                        => Service['nagios']}

  if $nagios_hosts {
    create_resources('nagios_host', $nagios_hosts, $resource_defaults)
  }

  if $nagios_hostgroups {
    create_resources('nagios_hostgroup', $nagios_hostgroups, $resource_defaults)
  }

  if $nagios_services {
    create_resources('nagios_service', $nagios_services, $resource_defaults)
  }

  if $nagios_commands {
    create_resources('nagios_command', $nagios_commands, $resource_defaults)
  }

  if $nagios_contacts {
    create_resources('nagios_contact', $nagios_contacts, $contact_resource_defauts)
  }

  if $nagios_contactgroups {
    create_resources('nagios_contactgroup', $nagios_contactgroups, $resource_defaults)
  }

  # Configure nagios not to monitor localhosts
  if $monitor_localhost == false {
    file_line { 'nagios_localhost':
      ensure  => present,
      path    => '/etc/nagios/nagios.cfg',
      line    => '#cfg_file=/etc/nagios/objects/localhost.cfg',
      match   => 'cfg_file=/etc/nagios/objects/localhost.cfg',
      notify  => Service['nagios'],
      require => Package['nagios']
    }
  }

  # Configure nagios not to send ip addresses in email alerts
  nagios_command { 'notify-host-by-email':
    command_line => '/usr/bin/printf "%b" "***** Nagios *****\n\nNotification Type: $NOTIFICATIONTYPE$\nHost: $HOSTNAME$\nState: $HOSTSTATE$\nInfo: $HOSTOUTPUT$\n\nDate/Time: $LONGDATETIME$\n" | /usr/bin/mail -s "** $NOTIFICATIONTYPE$ Host Alert: $HOSTNAME$ is $HOSTSTATE$ **" $CONTACTEMAIL$',
    target       => '/etc/nagios/objects/commands.cfg',
    notify       => Service['nagios'],
    require      => Package['nagios']
  }

  nagios_command { 'notify-service-by-email':
    command_line => '/usr/bin/printf "%b" "***** Nagios *****\n\nNotification Type: $NOTIFICATIONTYPE$\n\nService: $SERVICEDESC$\nHost: $HOSTALIAS$\nState: $SERVICESTATE$\n\nDate/Time: $LONGDATETIME$\n\nAdditional Info:\n\n$SERVICEOUTPUT$\n" | /usr/bin/mail -s "** $NOTIFICATIONTYPE$ Service Alert: $HOSTALIAS$/$SERVICEDESC$ is $SERVICESTATE$ **" $CONTACTEMAIL$',
    target       => '/etc/nagios/objects/commands.cfg',
    notify       => Service['nagios'],
    require      => Package['nagios']
  }
}
