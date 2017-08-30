class profiles::pulp(
  $rpmrepos = {},
  $username = undef,
  $password = undef,
  ){

  class { 'pulp::runstages':}
  class { '::pulp':
    broker_url          => $pulp::broker_url,
    messaging_url       => $pulp::messaging_url,
    messaging_transport => $pulp::messaging_transport,
    }
  class { '::pulp::consumer':
    host                => $pulp::consumer::host,
    messaging_host      => $pulp::consumer::messaging_host,
    messaging_transport => $pulp::consumer::messaging_transport,
    messaging_port      => $pulp::consumer::messaging_port,
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
    password => $pulp::admin::password,
    stage    => 'pulp-login',
  }
  class { '::pulp::admin_update':
    username => $pulp::admin::username,
    password => $pulp::admin::password,
    stage    => 'pulp-user-update',
  }
  class { '::pulp::reposetup':
    rpmrepos => $rpmrepos,
    stage    => 'last',
    }

}
