class profiles::localshop(
  $db_name = undef,
  $user = undef,
  $password = undef,
  ){
  $requirements = [ 'gcc', 'python-psycopg2', 'python2-pip', 'python-devel', 'expect' ]

  package { $requirements:
    ensure => present
  } ->
  package { "localshop":
    ensure   => present,
    provider => "pip"
  } ->
  file { '/lib/python2.7/site-packages/localshop/settings.py':
    ensure  => present,
    content => template('puppet:///modules/profiles/settings.py.erb'),
    owner   => 'localshop',
  } ->
  file { '/home/.localshop':
    ensure => directory,
    mode   => '0755',
    owner  => 'localshop',
  } ->
  file { '/home/.localshop/localshop.cache':
    ensure => directory,
    owner  => 'localshop',
  } ->
  file { '/home/.localshop/localshop.conf.py':
    ensure => present,
    source => 'puppet:///modules/profiles/localshop.conf.py',
    owner  => 'localshop',
  } ->
  file { '/opt/localshopexpect.sh':
    ensure => present,
    source => 'puppet:///modules/profiles/localshopexpect.sh',
    owner  => 'localshop',
    mode   => '0755',
  } ->
  file { '/etc/systemd/system/localshop.service':
    ensure => present,
    source => 'puppet:///modules/profiles/localshop.service',
    owner  => 'localshop',
  } ->
  file { '/etc/systemd/system/localshopcelery.service':
    ensure => present,
    source => 'puppet:///modules/profiles/localshopcelery.service',
    owner  => 'localshop',
  } ->
  exec { 'run localshop init':
    command   => '/opt/localshopexpect.sh',
    logoutput => true,
    user      => "localshop",
    creates   => '/home/.localshop/localshop.db',
    require   => Class['postgresql']
  } ->
  service { 'localshop':
    ensure => 'running',
    enable => true,
  } ->
  service { 'localshopcelery':
    ensure => 'running',
    enable => true,
  }
}
