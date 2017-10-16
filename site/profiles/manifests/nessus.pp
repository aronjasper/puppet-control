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
    provider => 'rpm',
    source   => $package_source,
    ensure   => $package_ensure,
    name     => $package_name,
  }
  include '::nessus'
}
