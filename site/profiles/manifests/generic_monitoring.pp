# Class profiles::generic_monitoring
#
# This class will monitor a service and port as defined in the parameters provided.
#
# Parameters:
#   monitor_service            - the name of the process to check for, passed to the nagios
#                                check_service_procs command
#   monitor_port               - the port(s) to check for, passed to the nagios check_service_tcp
#                                command. Supports a single value or an array.
#   monitor_ntp                - if true, a check for a ntp will be created.
#
#   min_process_warning_count  - generate a warning alert if the number of processes
#                                falls below this number
#   max_process_warning_count  - generate a warning alert if the number of processes
#                                rises above this number
#   min_process_critical_count - generate an error alert if the number of processes
#                                falls below this number
#   max_process_critical_count - generate a warning alert if the number of processes
#                                rises above this number
#   time_period                - used for the nagios check and notification periods
#

class profiles::generic_monitoring(

  $monitor_service            = false,
  $monitor_port               = false,
  $monitor_ntp                = false,
  $min_process_warning_count  = 1,
  $max_process_warning_count  = 10,
  $min_process_critical_count = 1,
  $max_process_critical_count = 25,
  $time_period                = '24x7'

  ){

  if $monitor_service {
    @@nagios_service { "${::hostname}-lr-${monitor_service}" :
      ensure                => present,
      check_command         => "check_nrpe!check_service_procs\\!${min_process_warning_count}:${max_process_warning_count}\
\\!${min_process_critical_count}:${max_process_critical_count}\\!${monitor_service}",
      mode                  => '0644',
      owner                 => root,
      use                   => 'generic-service',
      host_name             => $::hostname,
      check_period          => $time_period,
      contact_groups        => 'admins',
      notification_interval => 0,
      notifications_enabled => 1,
      notification_period   => $time_period,
      service_description   => "LR service ${monitor_service}"
    }
  }

  # Define resource to allow multiple port checks to be added. Port passed in as 'title' variable.
  define create_port_check {
    @@nagios_service { "${::hostname}-lr-${name}-tcp_check" :
      ensure                => present,
      check_command         => "check_nrpe!check_service_tcp\\!'127.0.0.1'\\!'${title}'",
      mode                  => '0644',
      owner                 => root,
      use                   => 'generic-service',
      host_name             => $::hostname,
      check_period          => $time_period,
      contact_groups        => 'admins',
      notification_interval => 0,
      notifications_enabled => 1,
      notification_period   => $time_period,
      service_description   => "LR tcp port ${title}"
    }
  }

  if $monitor_port {
    create_port_check { $monitor_port: }
  }

  if $monitor_ntp {
    @@nagios_service { "${::hostname}-lr-${name}-ntp_check" :
      ensure                => present,
      check_command         => "check_nrpe!check_service_ntp\\!'127.0.0.1'",
      mode                  => '0644',
      owner                 => root,
      use                   => 'generic-service',
      host_name             => $::hostname,
      check_period          => $time_period,
      contact_groups        => 'admins',
      notification_interval => 0,
      notifications_enabled => 1,
      notification_period   => $time_period,
      service_description   => 'LR ntp check'
    }
  }
}
