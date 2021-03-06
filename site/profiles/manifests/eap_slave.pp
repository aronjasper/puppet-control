#host controller for slave
class profiles::eap_slave (
  $dc              = hiera('wildfly::domain_controller'),
  $secret_value    = hiera('wildfly::secret_value'),
  $ejbsecret_value = hiera('wildfly::ejbsecret_value'),
  # $remote_password = hiera('wildfly::remote_password'),
){

  include ::stdlib

  # Assume that if we have multiple interfaces that eth1 is the data
  if ($::ipaddress_eth1) {
    $mgmt_addr = $::ipaddress_eth0
    $data_addr = $::ipaddress_eth1
  } else {
    $mgmt_addr = $::ipaddress_eth0
    $data_addr = $::ipaddress_eth0
  }

  # Decode plaintext password from secret value
  $remote_password = base64('decode', $secret_value)

  class { '::wildfly':
    distribution => 'jboss-eap',
    user         => 'jboss-eap',
    group        => 'jboss-eap',
    dirname      => '/opt/jboss-eap',
    console_log  => '/var/log/jboss-eap/console.log',
    java_home    => '/usr',
    mode         => 'domain',
    host_config  => 'host-slave.xml',
    secret_value => $secret_value,
    jboss_opts   => '-Djava.net.preferIPv4Stack=true',
    properties   => {
      'jboss.bind.address'            => $data_addr,
      'jboss.bind.address.management' => $data_addr,
      'jboss.bind.address.private'    => $data_addr,
      'jboss.domain.master.address'   => $dc
    }
  }

  $app_users = hiera_hash('wildfly::app_users', {})
  create_resources('wildfly::config::app_user', $app_users)

  $mgmt_users = hiera_hash('wildfly::mgmt_users', {})
  create_resources('wildfly::config::mgmt_user', $mgmt_users)


  ##############################################################################
  ############################### SLAVE CLEANUP ################################
  ##############################################################################

  wildfly_cli { 'destroy-server-one':
    command  => "/host=${::hostname}/server-config=server-one:destroy",
    onlyif   => "(result == STARTED) of /host=${::hostname}/server-config=server-one:read-attribute(name=status)",
    username => $wildfly::remote_username,
    password => $remote_password,
    host     => $dc,
    port     => 9990,
    require  => Service['wildfly'],
  }->
  wildfly_cli { 'destroy-server-two':
    command  => "/host=${::hostname}/server-config=server-two:destroy",
    onlyif   => "(result == STARTED) of /host=${::hostname}/server-config=server-two:read-attribute(name=status)",
    username => $wildfly::remote_username,
    password => $remote_password,
    host     => $dc,
    port     => 9990,
    require  => Service['wildfly'],
  }->
  wildfly_resource { ["/host=${::hostname}/server-config=server-one","/host=${::hostname}/server-config=server-two"] :
    ensure   => absent,
    username => $wildfly::remote_username,
    password => $remote_password,
    host     => $dc,
    port     => 9990,
    require  => Service['wildfly']
  }

  wildfly_resource { "/host=${::hostname}/core-service=management/security-realm=ApplicationRealm/server-identity=secret" :
    ensure   => present,
    state    => {
      'value' => $ejbsecret_value
    },
    username => $wildfly::remote_username,
    password => $remote_password,
    host     => $dc,
    port     => 9990,
    require  => Service['wildfly']
  }

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
  ############################ DRIVER INSTALLATION #############################
  ##############################################################################

  # If the repository source has been defined, assume we would like Puppet to
  # manage the database drivers rather than an external solution.
  $repository_source = hiera('wildfly::repository_source')
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
    }->
    file { "${wildfly::dirname}/modules/com/ibm/main/module.xml":
      ensure  => present,
      owner   => $wildfly::user,
      group   => $wildfly::group,
      source  => 'puppet:///modules/profiles/jboss-eap/ibm/module.xml',
      recurse => true,
      require => File[$modules]
    }->
    exec { 'download ibm driver license':
      command  => "wget ${repository_source}/db2jcc_license_cisuz.jar -P ${wildfly::dirname}/modules/com/ibm/main",
      path     => ['/bin', '/usr/bin', '/sbin'],
      loglevel => 'notice',
      user     => $wildfly::user,
      group    => $wildfly::group,
      creates  => "${wildfly::dirname}/modules/com/ibm/main/db2jcc_license_cisuz.jar",
      require  => File[$modules],
    }->
    exec { 'download ibm driver':
      command  => "wget ${repository_source}/db2jcc4.jar -P ${wildfly::dirname}/modules/com/ibm/main",
      path     => ['/bin', '/usr/bin', '/sbin'],
      loglevel => 'notice',
      user     => $wildfly::user,
      group    => $wildfly::group,
      creates  => "${wildfly::dirname}/modules/com/ibm/main/db2jcc4.jar",
      require  => File[$modules],
    }->
    file { "${wildfly::dirname}/modules/com/oracle/main/module.xml":
      ensure  => present,
      owner   => $wildfly::user,
      group   => $wildfly::group,
      source  => 'puppet:///modules/profiles/jboss-eap/oracle/module.xml',
      recurse => true,
      require => File[$modules]
    }->
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
}
