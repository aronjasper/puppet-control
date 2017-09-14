# Class profiles::redis
#
# This class will manage rabbitmq installations
#
# Parameters:

#  ['port']                   - Port which redis listens on
#  ['bind']                   - The bind of redis
#  ['password']               - Password used for authentication between master and slave
#  ['min_slaves_to_write']    - How many nodes the master has to write to. If less nodes available the write will be refused
#  ['min_slaves_max_lag']     - Maxinium time the master will wait when writing to a slave
#  ['cluster_name']           - Name of the cluster all nodes are part of
#  ['master_hostname']        - The hostname of the master, this is to determin if it is a slave or master
#  ['master_ip']              - If it is a slave, this is the IP of the master that you need to connect to
#  ['failover_timeout']       - Amount of time to wait before failover starts
#  ['down_after']             - Amount of time before a host is down
#  ['parallel_sync']          - Amount of parallel syncs between master and slaves
#  ['quorum']                 - The amount of hosts which need to agree on a new master
#  ['sentinel_log_file']      - The log file for redis sentinel (it defaults to same as redis which is confusing)
#
# Requires:
# - puppet-redis


class profiles::redis(
  $bind                = '0.0.0.0',
  $port                = 6379,
  $password            = undef,
  $min_slaves_to_write = 1,
  $min_slaves_max_lag  = 10,
  $cluster_name        = undef,
  $master_hostname     = undef,
  $master_ip           = undef,
  $failover_timeout    = 30000,
  $down_after          = 5000,
  $parallel_sync       = 1,
  $quorum              = 2,
  $sentinel_log_file   = '/var/log/redis/redis-sentinel.log'
){

  if $master_hostname == undef {

    class { '::redis':
      bind        => $bind,
      port        => $port,
      requirepass => $password,
    }

  } else {

    if $::hostname == $master_hostname {
      $slaveof = undef
    } else {
      $slaveof = "${master_ip} ${port}"
    }

    class { '::redis':
      bind                => $bind,
      port                => $port,
      requirepass         => $password,
      masterauth          => $password,
      min_slaves_to_write => $min_slaves_to_write,
      min_slaves_max_lag  => $min_slaves_max_lag,
      slaveof             => $slaveof
    }

    class { '::redis::sentinel':
      sentinel_bind    => $bind,
      redis_port       => $port,
      auth_pass        => $password,
      master_name      => $cluster_name,
      redis_host       => $master_ip,
      failover_timeout => $failover_timeout,
      down_after       => $down_after,
      parallel_sync    => $parallel_sync,
      quorum           => $quorum,
      log_file         => $sentinel_log_file,
    }
  }

}
