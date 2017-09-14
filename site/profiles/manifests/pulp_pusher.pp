class profiles::pulp_pusher(){

  class { 'pulp::runstages':}
  class { '::pulp::consumer':
    host                => $pulp::consumer::host,
    messaging_host      => $pulp::consumer::messaging_host,
    messaging_transport => $pulp::consumer::messaging_transport,
  }

  class { '::pulp::admin':
  username => $pulp::admin::username,
  password => $pulp::admin::password,
  }
  class { '::pulp::admin_conf':
    username => $pulp::admin::username,
    password => $pulp::admin::password,
    stage    => 'pulp-admin-conf',
  }
  class { '::pulp::login':
    username => $pulp::admin::username,
    stage    => 'pulp-login',
  }
}
