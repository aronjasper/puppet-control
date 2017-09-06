class profiles::pulp_repos(

  $purge_unmanaged_yum_repos = false,
  $rpmrepos = {},
  $repository_uri = undef,
  ){

  file { '/etc/yum.repos.d/pulp.repo':
    ensure  => 'file',
    content => template('pulp/pulp.repo.erb'),
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
  }

  if $purge_unmanaged_yum_repos {
    file { '/etc/yum.repos.d/':
      ensure  => 'directory',
      recurse => true,
      purge   => true,
    }
    exec { 'Clean The Yum cache':
    command => 'yum clean all'
    }
  }
  else {
    exec { 'Clean Yum cache':
    command => 'yum clean all'
    }
  }
}
