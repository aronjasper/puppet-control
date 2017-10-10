# Class profiles::elasticsearch_server
#
#
#
# Sample Usage:
#   class { 'profiles::elasticsearch_server': }
#
class profiles::elasticsearch_server(
  $cluster_name = undef,
) {
    include elastic
    include lvm
    Class['lvm'] -> Elasticsearch::Service[$cluster_name]
}
