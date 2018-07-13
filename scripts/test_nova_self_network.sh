#!/bin/bash
set -e

###############################################################################
## Init environment source
TOP_DIR=$(cd $(dirname "$0") && pwd)
source $TOP_DIR/lib/functions.sh
source $TOP_DIR/admin-openrc

###############################################################################
echocolor "Spawn VM on selfservice network"

PRIVATE_NET_ID=`openstack network list | egrep -w selfservice | awk '{print $2}'`
SECURITY_GROUP_ID='default'

openstack server create \
    --flavor t2.nano \
    --image cirros \
    --nic net-id=$PRIVATE_NET_ID \
    --security-group=$SECURITY_GROUP_ID \
    selfservice-VM1

echocolor "Assign floating IP address"
FLOATING_IP=`openstack floating ip create provider | egrep -w floating_ip_address | awk '{print $4}'`
openstack server add floating ip selfservice-VM1 $FLOATING_IP
