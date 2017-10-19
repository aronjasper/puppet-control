#domain master controller

class profiles::eap_dc(){

  include ::stdlib

  # Assume that if we have multiple interfaces that eth1 is the data
  if ($::ipaddress_eth1) {
    $mgmt_addr = $::ipaddress_eth0
    $data_addr = $::ipaddress_eth1
  } else {
    $mgmt_addr = $::ipaddress_eth0
    $data_addr = $::ipaddress_eth0
  }

  $profiles = {
    'frontend' => 'lr-frontend-full-ha',
    'backend'  => 'lr-backend-full-ha'
  }

  class { '::wildfly':
    distribution => 'jboss-eap',
    user         => 'jboss-eap',
    group        => 'jboss-eap',
    dirname      => '/opt/jboss-eap',
    java_home    => '/usr/lib/jvm/jre',
    console_log  => '/var/log/jboss-eap/console.log',
    mode         => 'domain',
    host_config  => 'host-master.xml',
    jboss_opts   => '-Djava.net.preferIPv4Stack=true',
    properties   => {
      'jboss.bind.address'            => $data_addr,
      'jboss.bind.address.management' => $data_addr,
      'jboss.bind.address.private'    => $data_addr
    }
  }



  $app_users = hiera_hash('wildfly::app_users', {})
  create_resources('wildfly::config::app_user', $app_users)

  $mgmt_users = hiera_hash('wildfly::mgmt_users', {})
  create_resources('wildfly::config::mgmt_user', $mgmt_users)

  $mod_cluster_config=hiera_hash('wildfly::mod_cluster_config',{})
  create_resources('wildfly::resource', $mod_cluster_config)

  $undertow_config=hiera_hash('wildfly::undertow_config', {})
  create_resources('wildfly::resource',$undertow_config)

  $default_undertow= hiera_hash('wildfly::default_undertow', {})
  create_resources('wildfly::resource',$default_undertow)

  $naming = hiera_hash('wildfly::naming', {})
  create_resources('wildfly::resource',$naming)

  $system_properties = hiera_hash('wildfly::system-properties', {})
  create_resources('wildfly::resource', $system_properties)

  #$deployment = hiera_hash('wildfly::deployment', {})
  #create_resources('wildfly::deployment', $deployment)


  ##############################################################################
  ############################## KERNEL SETTINGS ###############################
  ##############################################################################

  # These parameters are required on all systems in order to ensure that JGroups
  # has appropriate sized buffers to work with. This should eventually be split
  # into it's own class.

  include ::sysctl::base # https://github.com/thias/puppet-sysctl

  # Multicast receive buffer @ 20MiB
  sysctl { 'net.core.rmem_max' : value => 20971520 }

  # Multicast write buffer @ 1MiB
  sysctl { 'net.core.wmem_max' : value => 1048576 }

  ##############################################################################
  ############################## SOCKET BINDINGS ###############################
  ##############################################################################

  # Note: Later I want to move this stuff out in to a seperate high-level module.
  # Not all of these ports are likely used. Once custom profiles are used, it's
  # worth reviewing which ports we are using so we can remove the unused ones.

  # Set up custom socket group
  $socket_group_name     = 'landregistry-sockets'
  $socket_group_resource = "/socket-binding-group=${socket_group_name}"

  wildfly::resource { $socket_group_resource :
    content => { 'default-interface' => 'public' },
    require => Class[wildfly]
  }

  # Define default custom sockets.
  $default_custom_sockets = {
    'ajp'                      => 10000,
    'http'                     => 10001,
    'https'                    => 10002,
    'iiop'                     => 10003,
    'iiop-ssl'                 => 10004,
    'jgroups-mping'            => 10005,
    'jgroups-mping-multicast'  => 10006,
    'jgroups-tcp'              => 10007,
    'jgroups-udp'              => 10008,
    'jgroups-udp-multicast'    => 10009,
    'modcluster'               => 10009,
    'modcluster-multicast'     => 10010,
    'txn-recovery-environment' => 10011,
    'txn-status-manager'       => 10012
  }

  $custom_sockets = hiera_hash('wildfly::customisations::socket-bindings', $default_custom_sockets)

  wildfly::resource { "${socket_group_resource}/socket-binding=ajp" :
    content => { 'port' => $custom_sockets['ajp'] },
    require => Wildfly::Resource[$socket_group_resource]
  }

  wildfly::resource { "${socket_group_resource}/socket-binding=http" :
    content => { 'port' => $custom_sockets['http'] },
    require => Wildfly::Resource[$socket_group_resource]
  }

  wildfly::resource { "${socket_group_resource}/socket-binding=https" :
    content => { 'port' => $custom_sockets['https'] },
    require => Wildfly::Resource[$socket_group_resource]
  }

  wildfly::resource { "${socket_group_resource}/socket-binding=iiop" :
    content => {
      'port'      => $custom_sockets['iiop'],
      'interface' => 'unsecure'
    },
    require => Wildfly::Resource[$socket_group_resource]
  }

  wildfly::resource { "${socket_group_resource}/socket-binding=iiop-ssl" :
    content => { 'port' => $custom_sockets['iiop-ssl'] },
    require => Wildfly::Resource[$socket_group_resource]
  }

  wildfly::resource { "${socket_group_resource}/socket-binding=jgroups-mping" :
    content => {
      'port'              => 0,
      'interface'         => 'private',
      'multicast-address' => { 'EXPRESSION_VALUE' => '${jboss.default.multicast.address:230.0.0.4}' },
      'multicast-port'    => $custom_sockets['jgroups-mping-multicast']
    },
    require => Wildfly::Resource[$socket_group_resource]
  }

  wildfly::resource { "${socket_group_resource}/socket-binding=jgroups-tcp" :
    content => {
      'port'      => $custom_sockets['jgroups-tcp'],
      'interface' => 'private'
    },
    require => Wildfly::Resource[$socket_group_resource]
  }

  wildfly::resource { "${socket_group_resource}/socket-binding=jgroups-udp" :
    content => {
      'port'           => $custom_sockets['jgroups-udp'],
      'interface'      => 'private',
      'multicast-port' => $custom_sockets['jgroups-udp-multicast']
    },
    require => Wildfly::Resource[$socket_group_resource]
  }

  wildfly::resource { "${socket_group_resource}/socket-binding=modcluster" :
    content => {
      'port'              => 0,
      'multicast-address' => { 'EXPRESSION_VALUE' => '${jboss.modcluster.multicast.address:224.0.1.105}' },
      'multicast-port'    => $custom_sockets['modcluster-multicast']
    },
    require => Wildfly::Resource[$socket_group_resource]
  }

  wildfly::resource { "${socket_group_resource}/socket-binding=txn-recovery-environment" :
    content => { 'port' => $custom_sockets['txn-recovery-environment'] },
    require => Wildfly::Resource[$socket_group_resource]
  }

  wildfly::resource { "${socket_group_resource}/socket-binding=txn-status-manager" :
    content => { 'port' => $custom_sockets['txn-status-manager'] },
    require => Wildfly::Resource[$socket_group_resource]
  }

  wildfly::resource { "${socket_group_resource}/remote-destination-outbound-socket-binding=mail-smtp" :
    content => {
      'host' => 'localhost',
      'port' => '25'
    },
    require => Wildfly::Resource[$socket_group_resource]
  }

  # Although we use the same socket group for all servers, the outbound
  # definitions are only actually required by frontend profiles.

  $remote_ejb_hosts = hiera('wildfly::customisations::remote_ejb_hosts', ['remote-ejb-1.host', 'remote-ejb-2.host'])

  wildfly::resource { "${socket_group_resource}/remote-destination-outbound-socket-binding=remote-ejb-1" :
    content => {
      'host' => $remote_ejb_hosts[0],
      'port' => $custom_sockets['http']
    },
    require => Wildfly::Resource[$socket_group_resource]
  }

  wildfly::resource { "${socket_group_resource}/remote-destination-outbound-socket-binding=remote-ejb-2" :
    content => {
      'host' => $remote_ejb_hosts[1],
      'port' => $custom_sockets['http']
    },
    require => Wildfly::Resource[$socket_group_resource]
  }


  ##############################################################################
  ############################## PROFILE CREATION ##############################
  ##############################################################################

  wildfly::cli { "create-${profiles['frontend']}" :
    command => "/profile=full-ha:clone(to-profile=${profiles['frontend']})",
    unless  => "(result == ${profiles['frontend']}) of /profile=${profiles['frontend']}:read-attribute(name=name)",
    require => Service[wildfly]
  }

  wildfly::cli { "create-${profiles['backend']}" :
    command => "/profile=full-ha:clone(to-profile=${profiles['backend']})",
    unless  => "(result == ${profiles['backend']}) of /profile=${profiles['backend']}:read-attribute(name=name)",
    require => Service[wildfly]
  }


  ##############################################################################
  ############################### SERVER GROUPS ################################
  ##############################################################################

  wildfly::resource { '/server-group=frontend-main' :
    content => {
      'profile'              => $profiles['frontend'],
      'socket-binding-group' => $socket_group_name
    },
    require => [Class['Wildfly'], Wildfly::Resource[$socket_group_resource], Wildfly::Cli["create-${profiles['frontend']}"]]
  }

  wildfly::domain::server_group { 'backend-main' :
    config  => {
      'profile'              => $profiles['backend'],
      'socket-binding-group' => $socket_group_name
    },
    require => [Class['Wildfly'], Wildfly::Resource[$socket_group_resource], Wildfly::Cli["create-${profiles['backend']}"]]
  }


  ##############################################################################
  ####################### RESOURCE ADAPTER INSTALLATION ########################
  ##############################################################################

  $mq_profile                   = $profiles['backend']
  $mq_resource_adapter          = "/profile=${mq_profile}/subsystem=resource-adapters/resource-adapter=wmq.jmsra.rar"
  $mq_resource_adapter_artifact = hiera('wildfly::wmq_source', false)

  wildfly::resource { $mq_resource_adapter :
    content => {
      'archive'             => 'wmq.jmsra.rar',
      'transaction-support' => 'XATransaction',
      'statistics-enabled'  => true
    },
    require => [Class['wildfly'], Wildfly::Cli["create-${mq_profile}"]]
  }

  wildfly::resource { "${mq_resource_adapter}/config-properties=connectionConcurrency" :
    content => { 'value' => 10 },
    require => Wildfly::Resource[$mq_resource_adapter]
  }

  wildfly::resource { "${mq_resource_adapter}/config-properties=logWriterEnabled" :
    content => { 'value' => true },
    require => Wildfly::Resource[$mq_resource_adapter]
  }

  wildfly::resource { "${mq_resource_adapter}/config-properties=traceEnabled" :
    content => { 'value' => false },
    require => Wildfly::Resource[$mq_resource_adapter]
  }

  wildfly::resource { "/profile=${mq_profile}/subsystem=ejb3" :
    content => { 'default-resource-adapter-name' => 'wmq.jmsra.rar' },
    require => Wildfly::Resource[$mq_resource_adapter]
  }

  if $mq_resource_adapter_artifact {
    # Deploy the IBM MQ resource adapter to backend server group
    wildfly::deployment { 'wmq.jmsra.rar':
      server_group => 'backend-main',
      source       => $mq_resource_adapter_artifact,
      require      => [Wildfly::Resource[$mq_resource_adapter], Wildfly::Domain::Server_group['backend-main']]
    }
  }


  ##############################################################################
  ############################ DRIVER INSTALLATION #############################
  ##############################################################################

  # Note: Since this also needs to be carried out on the slaves, it makes sense for
  # this to be the first thing split out into a seperate manifest when this is
  # converted to it's own module.

  $repository_source = hiera('wildfly::repository_source', false)

  # If the repository source has been defined, assume we would like Puppet to
  # manage the database drivers rather than an external solution.
  if $repository_source {

    $modules = [
      "${wildfly::dirname}/modules/com",
      "${wildfly::dirname}/modules/com/ibm",
      "${wildfly::dirname}/modules/com/ibm/main",
      "${wildfly::dirname}/modules/com/oracle",
      "${wildfly::dirname}/modules/com/oracle/main"
    ]

    file { $modules:
      ensure  => 'directory',
      owner   => $wildfly::user,
      group   => $wildfly::group,
      require => Class['::wildfly']
    }

    file { "${wildfly::dirname}/modules/com/ibm/main/module.xml":
      ensure  => present,
      owner   => $wildfly::user,
      group   => $wildfly::group,
      source  => 'puppet:///modules/profiles/jboss-eap/ibm/module.xml',
      recurse => true,
      require => File[$modules]
    }

    exec { 'download ibm driver license':
      command  => "wget ${repository_source}/db2jcc_license_cisuz.jar -P ${wildfly::dirname}/modules/com/ibm/main",
      path     => ['/bin', '/usr/bin', '/sbin'],
      loglevel => 'notice',
      user     => $wildfly::user,
      group    => $wildfly::group,
      creates  => "${wildfly::dirname}/modules/com/ibm/main/db2jcc_license_cisuz.jar",
      require  => File[$modules],
    }

    exec { 'download ibm driver':
      command  => "wget ${repository_source}/db2jcc4.jar -P ${wildfly::dirname}/modules/com/ibm/main",
      path     => ['/bin', '/usr/bin', '/sbin'],
      loglevel => 'notice',
      user     => $wildfly::user,
      group    => $wildfly::group,
      creates  => "${wildfly::dirname}/modules/com/ibm/main/db2jcc4.jar",
      require  => File[$modules],
    }

    file { "${wildfly::dirname}/modules/com/oracle/main/module.xml":
      ensure  => present,
      owner   => $wildfly::user,
      group   => $wildfly::group,
      source  => 'puppet:///modules/profiles/jboss-eap/oracle/module.xml',
      recurse => true,
      require => File[$modules]
    }

    exec { 'download oracle driver':
      command  => "wget ${repository_source}/ojdbc7.jar -P ${wildfly::dirname}/modules/com/oracle/main",
      path     => ['/bin', '/usr/bin', '/sbin'],
      loglevel => 'notice',
      user     => $wildfly::user,
      group    => $wildfly::group,
      creates  => "${wildfly::dirname}/modules/com/oracle/main/ojdbc7.jar",
      require  => File[$modules],
    }
  }

  $db_profile = $profiles['backend']

  wildfly::datasources::driver { 'ibmdb2' :
    driver_name                     => 'ibm',
    driver_module_name              => 'com.ibm',
    driver_xa_datasource_class_name => 'com.ibm.db2.jcc.DB2XADataSource',
    target_profile                  => $db_profile,
    require                         => Wildfly::Cli["create-${db_profile}"]
  }

  wildfly::datasources::driver { 'oracle' :
    driver_name                     => 'oracle',
    driver_module_name              => 'com.oracle',
    driver_xa_datasource_class_name => 'oracle.jdbc.xa.client.OracleXADataSource',
    target_profile                  => $db_profile,
    require                         => Wildfly::Cli["create-${db_profile}"]
  }


  ##############################################################################
  ######################### DATASOURCES CONFIGURATION ##########################
  ##############################################################################

  # Datasource objects are relatively static so we have chosen to mostly harcode
  # their entries into this manifest directly, only exposing
  # environment-specific parameters.
  #
  # Later it might become necessary to have certain other parameters such as
  # pool sizes configurable on a per-environment basis.

  $db2_config = hiera_hash('wildfly::customisations::db2config', false)

  if $db2_config {

    wildfly::datasources::xa_datasource { 'DB2XADS' :
      target_profile => $db_profile,
      config         => {
        'enabled'                             => true,
        'statistics-enabled'                  => true,
        'validate-on-match'                   => false,
        'track-statements'                    => true,
        'pool-prefill'                        => false,
        'jndi-name'                           => 'java:/DB2XADS',
        'driver-name'                         => 'ibmdb2',
        'user-name'                           => $db2_config['username'],
        'password'                            => $db2_config['password'],
        'recovery-username'                   => $db2_config['username'],
        'recovery-password'                   => $db2_config['password'],
        'transaction-isolation'               => 'TRANSACTION_READ_COMMITTED',
        'check-valid-connection-sql'          => 'SELECT 1 FROM sysibm.sysdummy1',
        'valid-connection-checker-class-name' => 'org.jboss.jca.adapters.jdbc.extensions.db2.DB2ValidConnectionChecker',
        'stale-connection-checker-class-name' => 'org.jboss.jca.adapters.jdbc.extensions.db2.DB2StaleConnectionChecker',
        'exception-sorter-class-name'         => 'org.jboss.jca.adapters.jdbc.extensions.db2.DB2ExceptionSorter',
        'background-validation-millis'        => 59000,
        'min-pool-size'                       => 1,
        'max-pool-size'                       => 50,
        'xa-datasource-properties'            => {
          'User'                => { value => $db2_config['username'] },
          'Password'            => { value => $db2_config['password'] },
          'ServerName'          => { value => $db2_config['hostname'] },
          'PortNumber'          => { value => $db2_config['port'] },
          'DriverType'          => { value => 4 },
          'DatabaseName'        => { value => $db2_config['database'] },
          'currentPackageSet'   => { value => 'SYST' },
          'currentSchema'       => { value => 'SYST' },
          'securityMechanism'   => { value => 3 },
          'maxStatements'       => { value => 500 },
          'currentFunctionPath' => { value => 'SYST' }
        }
      },
      require        => Wildfly::Datasources::Driver['ibmdb2']
    }

  }

  ##############################################################################
  ############################## MQ CONFIGURATION ##############################
  ##############################################################################

  $mq_config  = hiera_hash('wildfly::customisations::mqconfig', false)

  if $mq_config {

    $mq_connection_definition = "${mq_resource_adapter}/connection-definitions=wmqCF"
    wildfly::resource { $mq_connection_definition :
      content => {
        'enabled'                      => true,
        'use-java-context'             => true,
        'jndi-name'                    => 'java:/jms/wmqCF',
        'class-name'                   => 'com.ibm.mq.connector.outbound.ManagedQueueConnectionFactoryImpl',
        'flush-strategy'               => 'FailingConnectionOnly',
        'min-pool-size'                => 10,
        'max-pool-size'                => 100,
        'pool-prefill'                 => false,
        'pool-use-strict-min'          => false,
        'no-recovery'                  => true,
        'allocation-retry'             => 3,
        'allocation-retry-wait-millis' => 5000,
      },
      require => Wildfly::Resource[$mq_resource_adapter]
    }

    wildfly::resource { "${mq_connection_definition}/config-properties=transportType" :
      content => { 'value' => 'CLIENT' },
      require => Wildfly::Resource[$mq_connection_definition]
    }

    wildfly::resource { "${mq_connection_definition}/config-properties=username" :
      content => { 'value' => $mq_config['username'] },
      require => Wildfly::Resource[$mq_connection_definition]
    }

    wildfly::resource { "${mq_connection_definition}/config-properties=hostName" :
      content => { 'value' => $mq_config['hostname'] },
      require => Wildfly::Resource[$mq_connection_definition]
    }

    wildfly::resource { "${mq_connection_definition}/config-properties=port" :
      content => { 'value' => $mq_config['port'] },
      require => Wildfly::Resource[$mq_connection_definition]
    }

    wildfly::resource { "${mq_connection_definition}/config-properties=queueManager" :
      content => { 'value' => $mq_config['queuemanager'] },
      require => Wildfly::Resource[$mq_connection_definition]
    }

    # According to IBM's documentation the above parameters are required to exist
    # in the server properties. These are duplicated and may not be neccessary.
    # Something to check at a later date.

    wildfly::resource { '/system-property=MQ.transportType' :
      content => { 'value' => 'CLIENT' },
      require => Wildfly::Resource[$mq_connection_definition]
    }

    wildfly::resource { '/system-property=MQ.username' :
      content => { 'value' => $mq_config['username'] },
      require => Wildfly::Resource[$mq_connection_definition]
    }

    wildfly::resource { '/system-property=MQ.hostName' :
      content => { 'value' => $mq_config['hostname'] },
      require => Wildfly::Resource[$mq_connection_definition]
    }

    wildfly::resource { '/system-property=MQ.port' :
      content => { 'value' => $mq_config['port'] },
      require => Wildfly::Resource[$mq_connection_definition]
    }

    wildfly::resource { '/system-property=MQ.queuemanager' :
      content => { 'value' => $mq_config['queueManager'] },
      require => Wildfly::Resource[$mq_connection_definition]
    }

    wildfly::resource { '/system-property=MQ.channel' :
      content => { 'value' => $mq_config['channel'] },
      require => Wildfly::Resource[$mq_connection_definition]
    }

    # There are different queue objects for each queue required and each of these
    # requires individual configuration.
    #
    # This could be further simplified in a custom resource group in future.

    wildfly::resource { "${mq_resource_adapter}/admin-objects=wmqECEVEQueue" :
      content => {
        'enabled'          => true,
        'use-java-context' => true,
        'class-name'       => 'com.ibm.mq.connector.outbound.MQQueueProxy',
        'jndi-name'        => 'java:/jms/ECEVEQueue'
      },
      require => Wildfly::Resource[$mq_resource_adapter]
    }

    wildfly::resource { "${mq_resource_adapter}/admin-objects=wmqECEVEQueue/config-properties=baseQueueName" :
      content => { 'value' => 'base.queue'},
      require => Wildfly::Resource["${mq_resource_adapter}/admin-objects=wmqECEVEQueue"]
    }

  }


  ##############################################################################
  ############################# EJB CONFIGURATION ##############################
  ##############################################################################

  $ejb_profile = $profiles['frontend']
  $ejb_remoting_resource = "/profile=${ejb_profile}/subsystem=remoting"

  wildfly::resource { "${ejb_remoting_resource}/remote-outbound-connection=remote-ejb-connection-1" :
    content => {
      'outbound-socket-binding-ref' => 'remote-ejb-1',
      'protocol'                    => 'http-remoting',
      'security-realm'              => 'ApplicationRealm',
      'username'                    => 'ejbuser'
    },
    require => [Wildfly::Resource["${socket_group_resource}/remote-destination-outbound-socket-binding=remote-ejb-1"], Wildfly::Cli["create-${ejb_profile}"]]
  }

  wildfly::resource { "${ejb_remoting_resource}/remote-outbound-connection=remote-ejb-connection-2" :
    content => {
      'outbound-socket-binding-ref' => 'remote-ejb-2',
      'protocol'                    => 'http-remoting',
      'security-realm'              => 'ApplicationRealm',
      'username'                    => 'ejbuser'
    },
    require => [Wildfly::Resource["${socket_group_resource}/remote-destination-outbound-socket-binding=remote-ejb-2"], Wildfly::Cli["create-${ejb_profile}"]]
  }

  wildfly::resource { ["${ejb_remoting_resource}/remote-outbound-connection=remote-ejb-connection-1/property=SASL_DISALLOWED_MECHANISMS", "${ejb_remoting_resource}/remote-outbound-connection=remote-ejb-connection-2/property=SASL_DISALLOWED_MECHANISMS"] :
    content => { 'value' => 'JBOSS-LOCAL-USER' },
    require => Wildfly::Resource["${ejb_remoting_resource}/remote-outbound-connection=remote-ejb-connection-1", "${ejb_remoting_resource}/remote-outbound-connection=remote-ejb-connection-2"]
  }

  wildfly::resource { ["${ejb_remoting_resource}/remote-outbound-connection=remote-ejb-connection-1/property=SASL_POLICY_NOANONYMOUS", "${ejb_remoting_resource}/remote-outbound-connection=remote-ejb-connection-2/property=SASL_POLICY_NOANONYMOUS"] :
    content => { 'value' => false },
    require => Wildfly::Resource["${ejb_remoting_resource}/remote-outbound-connection=remote-ejb-connection-1", "${ejb_remoting_resource}/remote-outbound-connection=remote-ejb-connection-2"]
  }

}
