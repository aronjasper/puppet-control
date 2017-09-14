# Class profiles::nginx
# This class will configure Nginx
#
# Parameters:
#
# Requires:
# - jfryman/nginx
#
# Sample Usage:
#   class { 'profiles::nginx': }
#
class profiles::nginx_selinux (

) {

  # Load SELinuux policy for NginX
  selinux::module { 'nginx_proxy':
    ensure => 'present',
    source => 'puppet:///modules/profiles/nginx_proxy.te'
  }
  # Load SELinuux policy for NginX
  selinux::module { 'nginx_unreservedport_name_connect':
    ensure => 'present',
    source => 'puppet:///modules/profiles/nginx_unreservedport_name_connect.te'
  }
  # Load SELinuux policy for NginX
  selinux::module { 'nginx_name_connect':
    ensure => 'present',
    source => 'puppet:///modules/profiles/nginx_name_connect.te'
  }
  # Load SELinuux policy for NginX - Ports 5004 and 5005
  selinux::module { 'nginx_rtp_media_port_t':
    ensure => 'present',
    source => 'puppet:///modules/profiles/nginx_rtp_media_port_t.te'
  }

}
