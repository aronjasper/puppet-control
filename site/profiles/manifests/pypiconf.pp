class profiles::pypiconf(
  $piphost = undef,
  $trustedhost = undef,
  ){

  class {'pypiconfig':
    pip_host     => $piphost,
    trusted_host => $trustedhost,
  }

}
