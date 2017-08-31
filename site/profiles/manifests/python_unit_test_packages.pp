# == Class: python unit test packages
#
# Installs tools required for running python unit tests
#
class profiles::python_unit_test_packages () {

  package {

  'setuptools':
    ensure   => present,
    provider => 'pip3';

  'pytest-cov':
    ensure   => present,
    provider => 'pip3';

  }

}
