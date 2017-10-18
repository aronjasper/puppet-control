# Class profiles::openresty_monitoring
#
# This class will set up nagios checks for openresty installations
#
class profiles::openresty_monitoring(){
  class { 'profiles::generic_monitoring':
    monitor_service => 'nginx',
    monitor_port    => hiera('llc_openresty_listen_port'),
  }
}
