# Class profiles::nfs
# This class will manage nfs mounts.
#
#
# Parameters:
#
#  ['mount_point']    - NFS location for the mount point
#  ['options']        - NFS mounting options, defaults
#  ['device']         - NFS Server and mount point
#
# Example:
#
# profiles::nfs::mount_point: '/hmlr'
# profiles::nfs::device: '192.168.42.40:/export/hmlr'
# profiles::nfs::options: 'nfsvers=4,defaults'
#
# Requires:
#
# Sample Usage:
#   class { 'profiles::nfs': }
#

class profiles::nfs (

  $mount_point      = 'undef',
  $options          = 'defaults',
  $device           = 'undef'
){

  # creates a directory for mount only if it does not exist

  exec { "create_directory":
  command => "mkdir $mount_point",
  unless => "test -d $mount_point",
  path    => "/usr/local/bin/:/bin/",
  before => Mount[$mount_point]

  }


  # Install the NFS Utils if not already installed

    package { 'nfs-utils' :
      ensure => present
    }

  # Attempt to mount the NFS share

    mount { $mount_point :
      ensure  => 'mounted',
      device  => $device,
      fstype  => 'nfs',
      options => $options,
      atboot  => true,
      require => Package [ 'nfs-utils' ]
    }



}
