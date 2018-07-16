#!/bin/bash
set -e

###############################################################################
## Init environment source
TOP_DIR=$(cd $(dirname "$0") && pwd)
source $TOP_DIR/lib/functions.sh
source $TOP_DIR/admin-openrc

###############################################################################
echocolor "Create flavor"
openstack flavor create --id 0 --vcpus 1 --ram 512 --disk 2 t2.nano || true
openstack flavor create --id 1 --vcpus 1 --ram 1024 --disk 4 t2.micro || true
openstack flavor create --id 2 --vcpus 1 --ram 2048 --disk 8 t2.small || true
openstack flavor create --id 3 --vcpus 2 --ram 4096 --disk 8 t2.medium || true
openstack flavor create --id 4 --vcpus 2 --ram 8196 --disk 8 t2.large || true
openstack flavor create --id 5 --vcpus 4 --ram 16384 --disk 8 t2.xlarge || true
openstack flavor create --id 6 --vcpus 8 --ram 32768 --disk 8 t2.2xlarge || true

openstack flavor create --id 7 --vcpus 2 --ram 8196 --disk 8 m4.large || true
openstack flavor create --id 8 --vcpus 4 --ram 16384 --disk 8 m4.xlarge || true

echocolor "Spawn VM on provider network"

PROVIDER_NET_ID=`openstack network list | egrep -w provider | awk '{print $2}'`
SECURITY_GROUP_ID=`openstack security group list --project ${OS_PROJECT_NAME} | grep Default | awk '{print $2}'`

openstack server create \
    --flavor t2.nano \
    --image cirros \
    --nic net-id=$PROVIDER_NET_ID \
    --security-group=$SECURITY_GROUP_ID \
    provider-VM1
