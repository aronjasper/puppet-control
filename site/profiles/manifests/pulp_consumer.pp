class profiles::pulp_consumer(
  $user = undef,
  $pass = undef,
  $repobindings = undef,
  $source_pulp_packages_from_external_repo = undef,
  ){

  class { '::pulp::consumer':
    source_pulp_packages_from_external_repo => $pulp::consumer::source_pulp_packages_from_external_repo,
    host                                    => $pulp::consumer::host,
    messaging_host                          => $pulp::consumer::messaging_host,
    messaging_transport                     => $pulp::consumer::messaging_transport,
  }

  class { '::pulp::consumer::bind':
    repobindings => $repobindings,
    user         => $user,
    pass         => $pass,
  }


}
