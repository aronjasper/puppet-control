# Global defaults for all nodes

notify{"Puppet Role: ${::puppet_role}": loglevel => debug,}
notify{"Network Location: ${::network_location}": loglevel => debug,}
notify{"Application Environment: ${::application_environment}": loglevel => debug,}

# Include classes specified in Hiera
hiera_include('classes')

# Include automagical DNS
include ::profiles::dns

# Create 'lr-admin' group on all hosts
group { 'lr-admin' :
  ensure => present,
  gid    => 2000
}

# Create 'lr-readonly' group on all hosts
group { 'lr-readonly' : ensure => present }

# Configure password sudo + not tty for deployment
sudo::conf { 'deployment' :
  priority => 10,
  content  => 'Defaults: %deployment !requiretty
%lr-admin  ALL=(ALL)  NOPASSWD: ALL',
}

# Configure passwordless sudo for 'lr-admin' group
sudo::conf { 'lr-admin' :
  priority => 20,
  content  => '%lr-admin  ALL=(ALL)  NOPASSWD: ALL',
}

# Create accounts from Hiera data
create_resources( 'account', hiera_hash('accounts', {require => Group['lr-admin']}) )

# Disable root login with password
user { root :
  ensure   => present,
  password => '!'
}

# Default executable path
Exec {
  path => '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
}

# Default file permissions to root:root
File {
  owner => 'root',
  group => 'root',
}

# Explicitly set 'allow virtual packages to false' in order to surpres error
# message on CentOS.
if versioncmp($::puppetversion,'3.6.1') >= 0 {

  $allow_virtual_packages = hiera('allow_virtual_packages',false)

  Package {
    allow_virtual => $allow_virtual_packages,
  }

}

# Add entry for host in ansible host file
@@file_line { "ansible_host_${::fqdn}":
  line => $::fqdn,
  tag  => 'ansible_hosts'
}

# Set SELinux module files to have no fiel name prefix
Selinux::Module {
  prefix => ''
}
