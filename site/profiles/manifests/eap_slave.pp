#host controller for slave
class profiles::eap_slave (
  $dc = '127.0.0.1',
  $remote_password = hiera('wildfly::remote_password')
){

  # Assume that if we have multiple interfaces that eth1 is the data
  if ($::ipaddress_eth1) {
    $mgmt_addr = $::ipaddress_eth0
    $data_addr = $::ipaddress_eth1
  } else {
    $mgmt_addr = $::ipaddress_eth0
    $data_addr = $::ipaddress_eth0
  }

  class { '::wildfly':
    distribution => 'jboss-eap',
    user         => 'jboss-eap',
    group        => 'jboss-eap',
    dirname      => '/opt/jboss-eap',
    console_log  => '/var/log/jboss-eap/console.log',
    java_home    => '/usr',
    mode         => 'domain',
    host_config  => 'host-slave.xml',
    properties   => {
      'jboss.bind.address'            => $data_addr,
      'jboss.bind.address.management' => $data_addr,
      'jboss.domain.master.address'   => $dc
    }
  }
  $repository_source = hiera('wildfly::repository_source')
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
  exec { "download ibm driver license":
    command  => "wget ${repository_source}/db2jcc_license_cisuz.jar -P ${wildfly::dirname}/modules/com/ibm/main",
    path     => ['/bin', '/usr/bin', '/sbin'],
    loglevel => 'notice',
    user     => $wildfly::user,
    group    => $wildfly::group,
    creates  => "${wildfly::dirname}/modules/com/ibm/main/db2jcc_license_cisuz.jar",
    require  => File[$modules],
  }->
  exec { "download ibm driver":
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
  exec { "download oracle driver":
    command  => "wget ${repository_source}/ojdbc7.jar -P ${wildfly::dirname}/modules/com/oracle/main",
    path     => ['/bin', '/usr/bin', '/sbin'],
    loglevel => 'notice',
    user     => $wildfly::user,
    group    => $wildfly::group,
    creates  => "${wildfly::dirname}/modules/com/oracle/main/ojdbc7.jar",
    require  => File[$modules],
  }->
  wildfly_cli { ["/host=${::hostname}/server-config=server-one:stop","/host=${::hostname}/server-config=server-two:stop"]:
    username => $wildfly::remote_username,
    password => $remote_password,
    host     => $wildfly::properties['jboss.domain.master.address'],
    port     => '9990',
    require  => Service['wildfly'],
  }->
  wildfly_resource { ["/host=${::hostname}/server-config=server-one","/host=${::hostname}/server-config=server-two"]:
    ensure   => absent,
    username => $wildfly::remote_username,
    password => $remote_password,
    host     => $wildfly::properties['jboss.domain.master.address'],
    port     => '9990',
    require  => Service['wildfly'],
  }
}
