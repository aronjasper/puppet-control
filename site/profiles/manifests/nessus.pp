# Class profiles::nessus
#
#
#
# Sample Usage:
#   class { 'profiles::nessus': }
#
class profiles::nessus(
  $package_source = undef,
  $package_name   = undef,
) {
  package { 'nessus_rpm':
    ensure   => $::package_ensure,
    provider => 'rpm',
    source   => $package_source,
    name     => $package_name,
  }
  include nessus
}
