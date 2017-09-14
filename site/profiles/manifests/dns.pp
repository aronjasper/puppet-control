# Class profiles::dns
#
# This class will manage DNS records for servers and supports multiple interfaces
#
# Requires:
# - puppetlabs/stdlib
# - landregistry/powerdns
#
# Sample Usage:
#   class { 'profiles::dns':
#     interfaces => {
#       eth0 => {
#         prepend => '',
#         append  => '-mgmt',
#         zone    => 'host.dev.ctp.local'
#       },
#       eth1 => {
#         prepend => '',
#         append  => '',
#         zone    => 'host.dev.ctp.local'
#       }
#     }
#   }
#
class profiles::dns (

  $interfaces = hiera_hash('interfaces',undef)

){

  include ::stdlib

  if ($interfaces != undef and is_hash($interfaces)) {
    if ($::ipaddress_eth0 and has_key($interfaces, 'eth0') and has_key($interfaces['eth0'], 'zone')) {
      $eth0 = $interfaces['eth0']
      $eth0_hostname = "${eth0['prepend']}${::hostname}${eth0['append']}"
      powerdns::record { "${eth0_hostname}.${eth0['zone']}" :
        ensure  => present,
        type    => 'A',
        ttl     => '3600',
        zone    => $eth0['zone'],
        content => [ $::ipaddress_eth0 ]
      }
    }

    if ($::ipaddress_eth1 and has_key($interfaces, 'eth1') and has_key($interfaces['eth1'], 'zone')) {
      $eth1 = $interfaces['eth1']
      $eth1_hostname = "${eth1['prepend']}${::hostname}${eth1['append']}"
      powerdns::record { "${eth1_hostname}.${eth1['zone']}" :
        ensure  => present,
        type    => 'A',
        ttl     => '3600',
        zone    => $eth1 ['zone'],
        content => [ $::ipaddress_eth1 ]
      }
    }
  }

}
