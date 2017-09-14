# Class profiles::logging_packetbeat
#
# Requires:
# - packetbeat
#

class profiles::logging_packetbeat(
  $log_receiver             = hiera('logstash_cluster_hosts',[]),
  $log_fields               = hiera('filebeat_log_fields',[]),
  $version                  = '5.3.1-1',
  $http_logging_ports       = undef,
  $http_logging_enabled     = undef,
  $postgres_logging_ports   = undef,
  $postgres_logging_enabled = undef,
  $amqp_logging_ports       = undef,
  $amqp_logging_enabled     = undef,
  $manage_repo              = true,
  $redis_logging_enabled    = undef,
  $redis_logging_ports      = undef,
  $dns_logging_enabled      = undef,
  $dns_logging_ports        = undef,
){

  class { 'packetbeat':
    package_vers             => $version,
    log_receiver             => $log_receiver,
    log_fields               => $log_fields,
    http_logging_ports       => $http_logging_ports,
    http_logging_enabled     => $http_logging_enabled,
    postgres_logging_ports   => $postgres_logging_ports,
    postgres_logging_enabled => $postgres_logging_enabled,
    amqp_logging_ports       => $amqp_logging_ports,
    amqp_logging_enabled     => $amqp_logging_enabled,
    redis_logging_enabled    => $redis_logging_enabled,
    redis_logging_ports      => $redis_logging_ports,
    dns_logging_enabled      => $dns_logging_enabled,
    dns_logging_ports        => $dns_logging_ports,
    manage_repo              => $manage_repo,
  }

}
