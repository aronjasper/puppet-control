# Class: profiles::puppet::agent
#
# This class installs and configures a Puppet Agent
#
# Parameters:
#  ['environment'] - FQDN of Puppet Master server
#  ['environment'] - Region of this puppet node. Defaults to 'production'
#  ['arguments']   - Puppet Agent arguments
#  ['run_hours']   - Cron-style hour setting for when to apply Puppet runs
#  ['run_days']    - Cron-style day setting for when to apply Puppet runs
#
# Sample Usage:
#  class { 'profiles::puppet::agent':
#    environment => 'development',
#    run_hours   => '*'
#    run_days    => '*'
#  }
#
class profiles::puppet::agent (

  $master_fqdn = 'puppet',
  $arguments   = '--no-daemonize --onetime --logdest syslog > /dev/null 2>&1',
  $run_hours   = '08-16',
  $run_days    = '1-5'
){

  # Set puppet environment from fact (set as production if fact does not exist)
    if $::puppet_environment != undef {
      notify { "Puppet environment ${::puppet_environment} set by fact":}
      $environment = $::puppet_environment
    } else {
      notify { 'Puppet environment not set by fact defaulting to production':}
      $environment = 'production'
    }

  # stephenrjohnson/puppet
  class { '::puppet::agent':
    puppet_server       => $master_fqdn,
    environment         => $environment,

    # Scheduling
    puppet_run_style    => 'external',
    puppet_run_interval => 30,
    splay               => true,
    ordering            => 'title-hash',
    report              => false
  }

  # Only carry out Puppet runs inside of a specific time window
  cron { 'puppet-agent':
    command => "/usr/bin/puppet agent ${arguments}",
    user    => root,
    minute  => [0,30],
    hour    => $run_hours,
    weekday => $run_days,
  }

}
