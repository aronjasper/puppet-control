# Class profiles::puppet::master_monitoring
#
# This class will set up nagios checks for puppet master installations
#
class profiles::puppet::master_monitoring(){
  class { 'profiles::generic_monitoring':
    monitor_service           => 'puppet',
    monitor_port              => '8140',
    max_process_warning_count => '30',
  }
}
