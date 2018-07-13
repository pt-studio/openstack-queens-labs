#!/bin/bash
set -e

###############################################################################
## Init environment source
TOP_DIR=$(cd $(dirname "$0") && pwd)
source $TOP_DIR/lib/functions.sh
source $TOP_DIR/admin-openrc

###############################################################################
echocolor "Create provider network"
openstack network create --share \
    --provider-physical-network provider \
    --provider-network-type flat provider

echocolor "Create subnet for provider network"
openstack subnet create --network provider \
    --allocation-pool start=192.168.81.220,end=192.168.81.245 \
    --dns-nameserver 8.8.8.8 --gateway 192.168.81.1 \
    --subnet-range 192.168.81.0/24 provider

echocolor "Create selfservice network"
openstack network create selfservice

echocolor "Create subnet for private network"
openstack subnet create --network selfservice \
    --dns-nameserver 8.8.4.4 --gateway 192.168.10.1 \
    --subnet-range 192.168.10.0/24 selfservice

echocolor "Create router for private network [selfservice <=> provider]"
openstack router create router
neutron net-update provider --router:external
neutron router-interface-add router selfservice
neutron router-gateway-set router provider