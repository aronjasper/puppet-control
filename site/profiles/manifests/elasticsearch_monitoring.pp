# Class profiles::elasticsearch_monitoring
#
# This class will set up nagios checks for elasticserch installations
#
# Parameters:

class profiles::elasticsearch_monitoring(

  $time_period     = hiera('nagios_time_period', '24x7'),
  $backups_enabled = hiera('es::enable_backup', hiera('elasticsearch::enable_backup', false))

  ){

  # Install elasticserch nagios plugins and dependancies
  $nagios_plugins = ['check_elasticsearch_cluster', 'check_elasticsearch_backups']

  define nagios_plugins(){
    file { $name :
        ensure  => 'present',
        path    => "/usr/lib64/nagios/plugins/${name}",
        owner   => 'root',
        group   => 'root',
        mode    => '0755',
        source  => "puppet:///modules/profiles/nagios_plugins/elasticsearch/${name}",
        require => Package['nrpe']
    }
  }

  nagios_plugins{$nagios_plugins:}

  # Add nrpe commands
  $nrpe_commands = ['command[check_elasticsearch_cluster]=/usr/lib64/nagios/plugins/check_elasticsearch_cluster',
  'command[check_elasticsearch_backups]=/usr/lib64/nagios/plugins/check_elasticsearch_backups']

  define nrpe_commands(){
    file_line { $name :
      path   => '/etc/nagios/nrpe.cfg',
      line   => $name,
      after  => '# Additional commands added via puppet',
      notify => Service['nrpe']
    }
  }

  nrpe_commands{$nrpe_commands:}

  # Export nagios service check resources

  # Elasticsearch process check
  @@nagios_service { "${::hostname}-elasticsearch" :
    ensure                => present,
    check_command         => 'check_nrpe!check_service_procs\\!1:2\\!1:1\\!org.elasticsearch.bootstrap.Elasticsearch',
    mode                  => '0644',
    owner                 => root,
    use                   => 'generic-service',
    host_name             => $::hostname,
    check_period          => $time_period,
    contact_groups        => 'admins',
    notification_interval => 0,
    notifications_enabled => 1,
    notification_period   => $time_period,
    service_description   => 'Elasticsearch'
  }

  # Elasticsearch cluster status check
  @@nagios_service { "${::hostname}-elasticserch_cluster_status" :
    ensure                => present,
    check_command         => 'check_nrpe!check_elasticsearch_cluster',
    mode                  => '0644',
    owner                 => root,
    use                   => 'generic-service',
    host_name             => $::hostname,
    check_period          => $time_period,
    contact_groups        => 'admins',
    notification_interval => 0,
    notifications_enabled => 1,
    notification_period   => $time_period,
    service_description   => 'Elasticsearch cluster status'
  }

  # Elasticsearch backup status check
  if $backups_enabled {
    @@nagios_service { "${::hostname}-elasticserch_backup_status" :
      ensure                => present,
      check_command         => 'check_nrpe!check_elasticsearch_backups',
      mode                  => '0644',
      owner                 => root,
      use                   => 'generic-service',
      host_name             => $::hostname,
      check_period          => $time_period,
      contact_groups        => 'admins',
      notification_interval => 0,
      notifications_enabled => 1,
      notification_period   => $time_period,
      service_description   => 'Elasticsearch backup status'
    }
  }
}
