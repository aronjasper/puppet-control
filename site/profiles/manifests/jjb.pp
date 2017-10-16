class profiles::jjb (
  $username = 'jjb',
  $password = undef,
  $url      = 'http://127.0.0.1:8080'
) {

  package { 'jenkins-job-builder':
    ensure   => present,
    provider => pip3,
    require  => Package[python34-pip]
  }

  file { '/var/lib/jenkins/jjb':
    ensure  => directory,
    owner   => 'jenkins',
    group   => 'jenkins',
    mode    => '0700',
    require => Package[jenkins]
  } ->
  file { '/var/lib/jenkins/jjb/jjb.ini':
    ensure  => present,
    content => template('profiles/jjb.ini.erb'),
    owner   => 'jenkins',
    group   => 'jenkins',
    mode    => '0600'
  }

}
