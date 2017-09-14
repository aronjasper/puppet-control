class { 'ha':
  virtual_ip   => '192.168.99.10',
  interface    => 'eth0',
  lb_instances => {
    'default'            => {
      'port'        => 5000,
      'healthcheck' => '/',
      'backends'    => [ 'localhost:8080', 'localhost:8081']
    },
    'sticky-test'        => {
      'port'        => 5001,
      'sticky'      => true,
      'healthcheck' => '/health',
      'backends'    => [ 'localhost:8080', 'localhost:8081']
    },
    'tcp-test'           => {
      'port'     => 5002,
      'mode'     => 'tcp',
      'backends' => [ 'localhost:8080', 'localhost:8081']
    },
    'auth-test'          => {
      'port'       => 5003,
      'auth_group' => 'admin',
      'backends'   => [ 'localhost:8080', 'localhost:8081']
    },
    'failover-test'      => {
      'port'     => 5004,
      'backends' => [ 'localhost:8080', 'localhost:8081'],
      'failover' => [ 'localhost:8082', 'localhost:8083'],
    },
    'redis-test'         => {
      'port'     => 5005,
      'mode'     => 'redis',
      'backends' => [ 'localhost:8080' ]
    },
    'redis-cluster-test' => {
      'port'     => 5006,
      'mode'     => 'redis',
      'backends' => [ 'localhost:8080', 'localhost:8081' ]
    }
  },
  auth_users   => {
    'admin' => {
      'test' => 'password'
    }
  }
}
