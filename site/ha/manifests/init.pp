#
# Hash example using HAProxy:
# class { 'ha':
#   virtual_ip   => '192.168.99.10',
#   interface    => 'eth1',
#   lb_instances => {
#     'default' => {
#       'port'        => 80,
#       'healthcheck' => '/',
#       'backends'    => [ 'localhost:8080', 'localhost:8081']
#     },
#     'test'          => {
#       'listen_port' => 9000,
#       'healthcheck' => '/health',
#       'backends'    => [ 'airbnb.com' ]
#     }
#   }
#  }
#
# Hiera example using HAProxy:
#
# ha::interface: eth1
# ha::virtual_ip: 192.168.99.10
# ha::lb_instances:
#   default:
#     port: 80
#     healthcheck: /
#     backends:
#       - localhost:8080
#       - localhost:8081
#   test:
#     port: 9000
#     healthcheck: /health
#     backends:
#       - airbnb.com
#
# Hiera example using nginx:
#
# ha::interface: eth1
# ha::virtual_ip: 192.168.99.10
# ha:: use_haproxy: false
# ha::track_script_name: 'chk_nginx'
# ha::track_script_cmd: 'pidof nginx'
#

class ha (
  $lb_instances = undef,
  $interface   = 'eth0',
  $virtual_ip  = undef,
  $sticky      = false,
  $auth_users  = undef,
  $use_haproxy = true,
  $track_script_name = 'haproxy',
  $track_script_cmd = 'pgrep haproxy',
) {

  include stdlib

  # If we're using haproxy then lb_instances hash must be supplied
  validate_string($interface)
  validate_string($virtual_ip)
  validate_bool($sticky)
  validate_bool($use_haproxy)
  validate_string($track_script_name)
  validate_string($track_script_cmd)
  if $use_haproxy { validate_hash($lb_instances) }
  if $auth_users { validate_hash($auth_users) }

  unless has_interface_with($interface) {
    fail("${interface} is not a valid network port")
  }
  unless is_ip_address($virtual_ip) {
    fail("${virtual_ip} is not a valid IP address")
  }

  # Install and configure keepalived
  $keepalived_cfg = '/etc/keepalived/keepalived.conf'
  $vip_priority   = fqdn_rand_string(2,'0123456789')

  ensure_packages('keepalived')

  file { $keepalived_cfg :
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => template('ha/keepalived.conf.erb'),
    require => Package['keepalived'],
    notify  => Service['keepalived']
  }

  service { 'keepalived':
    ensure    => running,
    enable    => true,
    require   => Package['keepalived'],
    subscribe => File[$keepalived_cfg]
  }

  # If we're using HA Proxy to do the load balancing (default behaviour) then this
  # section applies
  if ($use_haproxy) {

    ensure_packages('haproxy')
    $haproxy_cfg    = '/etc/haproxy/haproxy.cfg'

    file { $haproxy_cfg :
      ensure  => present,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => template('ha/haproxy.conf.erb'),
      require => Package['haproxy'],
      notify  => Service['haproxy']
    }

    service { 'haproxy':
      ensure    => running,
      enable    => true,
      require   => [ Package['haproxy'], Selboolean['haproxy_connect_any'] ],
      subscribe => File[$haproxy_cfg]
    }

    selboolean { 'haproxy_connect_any' :
      value      => 'on',
      persistent => true,
    }

  }

}
