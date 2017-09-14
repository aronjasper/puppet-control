# Class profiles::postgresqlHA_standby
#
# This class will manage PostgreSQL standby node installations
#
# Requires:
# - puppetlabs/stdlib


class profiles::postgresqlha_standby (
    $version       = '9.4',
    $dbroot        = '/var/lib/pgsql/',
    $ssh_keys      = hiera_hash('postgresqlha_keys',false),
    $postgres_conf = hiera_hash('postgres_conf',undef)
  ){

  include ::stdlib

  $shortversion = regsubst($version, '\.', '')
  $custom_hosts = template('profiles/postgres_hostfile_generation.erb')

  if $postgres_conf {
    if has_key($postgres_conf, 'wal_keep_segments') {
      $wal_keep_segments = "-w ${postgres_conf[wal_keep_segments]}"
    } else {
      $wal_keep_segments = ''
    }
  }

  selinux::module { 'keepalivedlr':
    ensure => 'present',
    source => 'puppet:///modules/profiles/keepalivedlr.te'
  }

  file { '/etc/hosts' :
    ensure  => file,
    content => $custom_hosts,
    owner   => 'root',
    mode    => '0644',
  }

  user { 'postgres' :
    ensure     => present,
    comment    => 'PostgreSQL Database Server',
    system     => true,
    home       => $dbroot,
    managehome => true,
    shell      => '/bin/bash',
  }

  file { $dbroot :
    ensure  => 'directory',
    owner   => 'postgres',
    group   => 'postgres',
    mode    => '0750',
    require => User[postgres]
  } ->

  file { "${dbroot}/.pgsql_profile" :
    ensure  => 'file',
    content => "export PATH=\$PATH:/usr/pgsql-${version}/bin/",
    owner   => 'postgres',
    group   => 'postgres',
    mode    => '0750',
    require => File[$dbroot]
  }

  if $::postgres_ha_setup_done != 0 {
    $vip_hostname = template('profiles/postgres_vip_hostname.erb')
    $pg_conf = "${dbroot}/${version}/data/postgresql.conf"
    $this_hostname = $::hostname

    include ::stdlib

    $pkglist = [
      'keepalived',
      'rsync'
    ]

    file { '/etc/puppetlabs/facter/facts.d/postgres_ha_setup_done.sh' :
      ensure => file,
      source => 'puppet:///modules/profiles/postgres_ha_setup_done.sh',
      owner  => 'root',
      mode   => '0755'
    } ->

    exec { "get_postgres_${shortversion}" :
      command => "yum localinstall http://yum.postgresql.org/${version}/redhat/rhel-6-x86_64/pgdg-centos${shortversion}-${version}-3.noarch.rpm -y",
      user    => 'root',
      before  => Package["postgresql${shortversion}-server"]
    } ->

    package { "postgresql${shortversion}-server" :
      ensure => present
    } ->

    package { "repmgr${shortversion}" :
      ensure => present
    }

    ensure_packages($pkglist)

    file { "/etc/repmgr/${version}/auto_failover.sh" :
      ensure  => file,
      owner   => 'postgres',
      source  => 'puppet:///modules/profiles/postgres_auto_failover.sh',
      require => Package["repmgr${shortversion}"],
      mode    => '0555'
    }

    file { 'PSQL History' :
      ensure  => 'file',
      path    => "${dbroot}/.psql_history",
      owner   => 'postgres',
      group   => 'postgres',
      mode    => '0750',
      require => File[$dbroot]
    }

    service {'sshd' :
      ensure => running,
      enable => true,
    }

    file { '/var/lib/pgsql/.ssh' :
      ensure => directory,
      owner  => 'postgres',
      mode   => '0700',
    } ->

    file { '/var/lib/pgsql/.ssh/config' :
      ensure  => file,
      content => 'StrictHostKeyChecking no',
      owner   => 'postgres',
      mode    => '0600',
    } ->

    file { '/var/lib/pgsql/.ssh/authorized_keys' :
      ensure  => file,
      content => $ssh_keys['public'],
      owner   => 'postgres',
      mode    => '0600',
    } ->

    file { '/var/lib/pgsql/.ssh/id_rsa' :
      ensure  => file,
      content => $ssh_keys['private'],
      owner   => 'postgres',
      mode    => '0600',
    } ->

    file { '/var/lib/pgsql/.ssh/id_rsa.pub' :
      ensure  => file,
      content => $ssh_keys['public'],
      owner   => 'postgres',
      mode    => '0644',
    }

    file { "/etc/repmgr/${version}/repmgr.conf" :
      ensure  => file,
      content => template('profiles/postgres_repmgr_config.erb'),
      require => Package["repmgr${shortversion}"],
    }

    file { '/etc/keepalived/keepalived.conf' :
      ensure  => file,
      content => template('profiles/postgres_keepalived_config.erb'),
    } ->

    file { '/etc/keepalived/health_check.sh' :
      ensure => file,
      source => 'puppet:///modules/profiles/keepalived_health_check.sh',
      owner  => 'postgres',
      mode   => '0544',
    }

    service {'keepalived' :
      ensure => running,
      enable => true,
    }

    file { '/usr/lib/systemd/system/repmgr.service' :
      ensure  => file,
      owner   => 'postgres',
      group   => 'postgres',
      mode    => '0664',
      content => template('profiles/repmgrd.service.erb')
    } ->

    file { '/var/lib/pgsql/.pgpass' :
      ensure  => file,
      content => template('profiles/pgpass.erb'),
      owner   => 'postgres',
      group   => 'postgres',
      mode    => '0600',
    } ->

    file { '/root/.pgpass' :
      ensure  => file,
      content => template('profiles/pgpass.erb'),
      mode    => '0600',
    } ->

    exec { 'set_system_keepalive' :
      command => 'sysctl -w net.ipv4.tcp_keepalive_time=60',
      user    => 'root',
    } ->

    exec { 'clone_database_master' :
      command => "/usr/pgsql-${version}/bin/repmgr -c -F -f /etc/repmgr/${version}/repmgr.conf ${::wal_keep_segments} -D /var/lib/pgsql/${version}/data/ -d repmgr -U repmgr --verbose standby clone ${vip_hostname}",
      user    => 'postgres',
      cwd     => "/etc/repmgr/${version}/",
      timeout => '0',
      unless  => 'psql -c "select pg_is_in_recovery();" | grep "^ t$"',
    } ->

    exec { 'reset_system_keepalive' :
      command => 'sysctl -w net.ipv4.tcp_keepalive_time=7200',
      user    => 'root',
    } ->

    service { "postgresql-${version}" :
      ensure => stopped,
      enable => false
    } ->

    exec { 'standby_start_postgres' :
      command => "/usr/pgsql-${version}/bin/pg_ctl -D /var/lib/pgsql/${version}/data/ start",
      user    => 'postgres',
      require => Package["postgresql${shortversion}-server"],
    } ->
    # added sleep before next command as on ESX repmanager tries to start before the postgres database is up.
    exec { 'standby_register_repmgrd' :
      command => "sleep 30 ; /usr/pgsql-${version}/bin/repmgr -f /etc/repmgr/${version}/repmgr.conf standby register --force",
      user    => 'postgres',
      require => File['/var/lib/pgsql/.pgpass'],
      unless  => "/usr/pgsql-${version}/bin/repmgr -f /etc/repmgr/${version}/repmgr.conf cluster show | grep \"standby | host=${::hostname}\"",
    } ->

    service { 'repmgr' :
      ensure  => running,
      enable  => true,
      require => File['/usr/lib/systemd/system/repmgr.service'],
    } ->

    file { '/usr/lib/systemd/system/postgresql.service' :
      ensure => link,
      target => "/usr/lib/systemd/system/postgresql-${version}.service",
      force  => true,
    } ->

    file { '/var/lib/pgsql/postgres_ha_setup_done' :
      ensure  => file,
      owner   => 'postgres',
      group   => 'postgres',
      require => Service['repmgr'],
    }

  }

}
