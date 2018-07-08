#!/bin/bash
set -e

###############################################################################
## Init environment source
TOP_DIR=$(cd $(dirname "$0") && pwd)
source $TOP_DIR/lib/functions.sh
source $TOP_DIR/admin-openrc

###############################################################################
echocolor "Spawn VM on provider network"

PROVIDER_NET_ID=`openstack network list | egrep -w provider | awk '{print $2}'`
SECURITY_GROUP_ID='389926eb-19ef-41e2-97c4-ddd18e3bafa6	'

openstack server create \
    --flavor t2.nano \
    --image cirros \
    --nic net-id=$PROVIDER_NET_ID \
    --security-group=$SECURITY_GROUP_ID \
    provider-VM1
