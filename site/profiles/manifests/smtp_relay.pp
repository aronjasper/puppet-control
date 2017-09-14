# Class profiles::smtp_relay
#
# This is a simple class to configure an smtp relay defined in hiera.
#
# Parameters:
#  ['smtp_relay'] - FQDN/IP + port number of the target smtp relay
#                   e.g. my_relay.example.com:25
# Sample Usage:
#
#   include profiles::smtp_relay

class profiles::smtp_relay (

  $smtp_relay = hiera('smtp_relay',false),

  ){

  if $smtp_relay {
    file_line { 'smtp relay config':
      ensure => present,
      line   => "relayhost = ${smtp_relay}",
      path   => '/etc/postfix/main.cf',
    }
  }
}
