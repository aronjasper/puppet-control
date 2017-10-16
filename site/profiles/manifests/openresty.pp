# Class profiles::openresty
#
# This class will manage openresty installations
#
# Parameters:
#  ['monitoring'] - Boolean to determine if the openresty_monitoring profile should be included. Defaults to true.
#
# Requires:
# - openresty
#
class profiles::openresty(

  $monitoring = true

  ){

  if $monitoring {
    include profiles::openresty_monitoring
  }

  include openresty
}
