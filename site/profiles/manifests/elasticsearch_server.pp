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
    contain elastic
    contain lvm
    Class['lvm'] -> Elasticsearch::Service[$cluster_name]
}
