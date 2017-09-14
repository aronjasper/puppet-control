#

class es (
  $interface     = 'eth0',
  $cluster_name  = 'elasticsearch',
  $manage_java   = true,
  $minimum_nodes = 1,
  $shards        = 5,
  $replicas      = 2,
  $enable_backup = false,
  $backup_dir    = '/backups',
  $backup_hour   = '02',
  $remote_fs     = false,
  $cluster_servers = []
){

  include stdlib
  validate_bool($manage_java)

  if ($interface == 'eth0') {
    $listen = $::ipaddress_eth0
  } elsif ($interface == 'eth1') {
    $listen = $::ipaddress_eth1
  } else {
    $listen = $::ipaddress
  }
  if ($::memorysize_mb >= 1024) {
    $heap_size = $::memorysizeinbytes/2
  } else {
    $heap_size = 268435456
  }
  $repo_version  = '1.7'
  $version       = '1.7.3'
  $data_dir      = "/var/lib/elasticsearch/${cluster_name}/data"
  $log_dir       = "/var/lib/elasticsearch/${cluster_name}/logs"

  class { 'elasticsearch_old' :
    ensure       => present,
    manage_repo  => true,
    package_pin  => true,
    java_install => $manage_java,
    repo_version => $repo_version,
    version      => $version
  }

  elasticsearch_old::plugin { 'royrusso/elasticsearch-HQ' :
    instances => $cluster_name
  }

  elasticsearch_old::instance { $cluster_name :
    datadir       => $data_dir,
    init_defaults => {
      'ES_HEAP_SIZE' => $heap_size
    },
    config        => {
      'cluster.name'  => $cluster_name,
      'path.repo'     => "[${backup_dir}]",
      'path.logs'     => $log_dir,
      'node'          => {
        'name'   => "${::hostname}-${cluster_name}",
        'master' => true,
        'data'   => true
      },
      'index'         => {
        'number_of_shards'   => $shards,
        'number_of_replicas' => $replicas,
      },
      'gateway'       => {
        'type'                => 'local',
        'recover_after_nodes' => 1,
        'recover_after_time'  => '2m',
        'expected_nodes'      => $minimum_nodes
      },
      'network'       => {
        'bind_host'    => '0.0.0.0',
        'publish_host' => $listen
      },
      'discovery.zen' => {
        'minimum_master_nodes' => 1,
        'ping'                 => {
          'multicast.enabled' => false,
          'unicast.hosts'     => $cluster_servers
        }
      }
    }
  }

  if $enable_backup {
    # Create Elasticsearch backup directory
    file { $backup_dir :
      ensure  => directory,
      owner   => elasticsearch,
      group   => elasticsearch,
      require => Package ['elasticsearch']
    }

    # Mout remote file system if specified
    if $remote_fs {
      package { 'nfs-utils' :
        ensure => present
      }

      mount { $backup_dir :
        ensure  => 'mounted',
        device  => $remote_fs,
        fstype  => 'nfs',
        options => 'defaults',
        atboot  => true,
        require => [
          Package [ 'nfs-utils' ],
          File [ $backup_dir ]
        ]
        }
      }

    # Install jq - required for ESbackup script
    package { 'jq' :
      ensure => installed
    }

    # Ensure ESBackup script is installed
    file { '/usr/bin/elasticsearch_snapshot':
      ensure => present,
      path   => '/usr/local/bin/elasticsearch_snapshot',
      owner  => 'root',
      group  => 'root',
      mode   => '0755',
      source => 'puppet:///modules/profiles/elasticsearch_snapshot.sh'
    }

    # Set backup cron job
    cron { 'elasticsearch_snapshot':
      ensure  => present,
      command => '/usr/local/bin/elasticsearch_snapshot localhost:9200',
      hour    => $backup_hour,
      minute  => fqdn_rand(60), # Randomise the minute value for the job
      user    => root
    }
  } else {
    # Remove backup cron job
    cron { 'elasticsearch_snapshot':
      ensure => absent
    }
  }
}
