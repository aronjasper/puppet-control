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
class profiles::datapub_nginx_selinux (

) {

  # Load SELinuux policy for NginX for datapub_nginx_selinux
  selinux::module { 'nginx_datapub':
    ensure => 'present',
    source => 'puppet:///modules/profiles/nginx_datapub.te'
  }

}
