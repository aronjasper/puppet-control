# Class profiles::filebeat_prospector
#
# This class will manage creating configuration for filebeat prospectors
#
# Requires:
# - filebeat
#

class profiles::filebeat_prospector(
  $prospectors=hiera_hash('prospectors'),

  ){
  define prospector (
    $disable_config_test   = true,
    $config_dir            = '/etc/filebeat/filebeat.d',
    $config_file_mode      = '0644',
    $ensure                = present,
    $paths                 = [],
    $exclude_files         = [],
    $encoding              = 'plain',
    $input_type            = 'log',
    $fields                = {},
    $fields_under_root     = false,
    $ignore_older          = undef,
    $close_older           = undef,
    $doc_type              = 'log',
    $scan_frequency        = '10s',
    $harvester_buffer_size = 16384,
    $tail_files            = false,
    $backoff               = '1s',
    $max_backoff           = '10s',
    $backoff_factor        = 2,
    $close_inactive        = '5m',
    $close_renamed         = false,
    $close_removed         = true,
    $close_eof             = false,
    $clean_inactive        = 0,
    $clean_removed         = true,
    $close_timeout         = 0,
    $force_close_files     = false,
    $include_lines         = [],
    $exclude_lines         = [],
    $max_bytes             = '10485760',
    $multiline             = {},
    $json                  = {},
    $tags                  = [],
    $symlinks              = false,
    $pipeline              = undef,
    ){

    validate_hash($fields, $multiline, $json)
    validate_array($paths, $exclude_files, $include_lines, $exclude_lines, $tags)
    validate_bool($tail_files, $close_renamed, $close_removed, $close_eof, $clean_removed, $symlinks)

    $prospector_template = 'prospector.yml.erb'

    if !$disable_config_test {
      file { "filebeat-${name}":
        ensure       => $ensure,
        path         => "${config_dir}/${name}.yml",
        owner        => 'root',
        group        => 'root',
        mode         => $config_file_mode,
        content      => template("${module_name}/${prospector_template}"),
        validate_cmd => '/usr/share/filebeat/bin/filebeat -N -configtest -c %',
        notify       => Service['filebeat'],
      }
    } else {
      file { "filebeat-${name}":
        ensure  => $ensure,
        path    => "${config_dir}/${name}.yml",
        owner   => 'root',
        group   => 'root',
        mode    => $config_file_mode,
        content => template("${module_name}/${prospector_template}"),
        notify  => Service['filebeat'],
      }
    }
  }
  if !empty($prospectors) {
    create_resources('profiles::filebeat_prospector::prospector', $prospectors)
  }
}
