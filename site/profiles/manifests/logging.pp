# Class profiles::logging
#
# This class will manage application server installations
#
# Requires:
# - filebeat
#

class profiles::logging(
  $log_receiver = hiera('logstash_cluster_hosts',[]),
  $log_fields   = hiera('filebeat_log_fields',[]),
  $version      = '5.3.1-1',
){
  class { 'filebeat':
    package_vers => $version,
    log_receiver => $log_receiver,
    log_fields   => $log_fields,
  }

}
