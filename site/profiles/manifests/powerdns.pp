# Class profiles::powerdns
#
# This class will manage PowerDNS installations which use PostgreSQL
#
# Requires:
# - puppetlabs/stdlib
# - landregistry/powerdns
#
class profiles::powerdns (

  $config = hiera_hash('powerdns',undef)

){

  include ::stdlib

  ensure_resource('class', 'powerdns::server::authoritive', $config)

}
