#
class profiles::application (

  $applications  = hiera_hash('applications',false),
  $time_period   = hiera('nagios_time_period', '24x7')

  ){

  include ::wsgi
  include ::stdlib

  # Define process check for bespoke applications
  define service_check(

    $bind = undef,
    $app_type = 'wsgi',
    $notification_period = undef,
    $check_period = undef,

    ){
    if ($app_type in [ 'wsgi', 'jar', 'python' ]) {
      @@nagios_service { "${::hostname}-lr-${name}" :
        ensure                => present,
        check_command         => "check_nrpe!check_service_procs\\!2:20\\!1:25\\!${name}",
        mode                  => '0644',
        owner                 => root,
        use                   => 'generic-service',
        host_name             => $::hostname,
        check_period          => $time_period,
        contact_groups        => 'admins',
        notification_interval => 0,
        notifications_enabled => 1,
        notification_period   => $time_period,
        service_description   => "LR service ${name}"
      }
    }
  }

  # Define tcp_check for bespoke applications
  define tcp_check(

    $bind = undef,
    $app_type = 'wsgi',
    $notification_period = undef,
    $check_period = undef,

    ){
    if ($app_type in [ 'wsgi', 'jar']) {
      @@nagios_service { "${::hostname}-lr-${name}-tcp_check" :
        ensure                => present,
        check_command         => "check_nrpe!check_service_tcp\\!'127.0.0.1'\\!'${bind}'",
        mode                  => '0644',
        owner                 => root,
        use                   => 'generic-service',
        host_name             => $::hostname,
        check_period          => $check_period,
        contact_groups        => 'admins',
        notification_interval => 0,
        notifications_enabled => 1,
        notification_period   => $notification_period,
        service_description   => "LR tcp ${name}"
      }
    }
  }

  if $applications {
    # Dirty hack to address hard coded logging location in manage.py
    file { '/var/log/applications/' :
      ensure => directory,
      owner  => 'root',
      group  => 'root',
      mode   => '0755'
    }

    # Create application resources for each application specified for server
    create_resources('wsgi::application', $applications,
      {require => File['/var/log/applications/']})

    # Filter hash to only return 'bind' and 'app_type' keys and values
    $check_hash = hash_filter($applications, ['bind','app_type'])

    # Set defualts for check resources
    $defaults = { notification_period => $time_period,
                  check_period        => $time_period}

    # Create process check for each application specified for server
    create_resources(service_check, $check_hash, $defaults)

    # Create tcp check for each application specified for server
    create_resources(tcp_check, $check_hash, $defaults)
  }
}
