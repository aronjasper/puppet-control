# == Class: python RPM build tools
#
# Installs tools required for packaging python apps into RPMS
#
class profiles::python_rpm_build_tools () {

  package {

  'virtualenv':
    ensure   => present,
    provider => 'pip3';

  'virtualenv-tools':
    ensure   => present,
    provider => 'pip3',
    source   => 'git+https://github.com/Yelp/virtualenv-tools.git';

  'fpm':
    ensure   => present,
    provider => 'gem',
  }

}
