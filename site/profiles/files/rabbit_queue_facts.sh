#!/bin/bash

# returns a fact for each vhost present on the host which is a space seperated
# list of the queues on that vhost.

# Check user is root
[ $(id -u) != 0 ] && echo "ERROR - You must run this script as root!" && exit 1

# Get the names of all vhosts on the system
VHOSTS=$(rabbitmqctl list_vhosts | sed 1d)

# For each Vhost print the list of queues ( - the alievness-test queues and any leading spaces)
for V in $VHOSTS; do
  QUEUES=$(rabbitmqctl list_queues -p $V | cut -f 1 | sed 1d | tr '\n' ' ' | sed 's/\<aliveness-test\>//g' | sed -e 's/^[[:space:]]*//')
  if [[ $V == '/' ]]; then
    echo "vhost_default_vhost=${QUEUES}"
  else
    echo "vhost_${V}=${QUEUES}"
  fi
done
