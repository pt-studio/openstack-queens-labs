#!/bin/bash

###############################################################################
## Init environment source
TOP_DIR=$(cd $(dirname "$0") && pwd)
source $TOP_DIR/lib/functions.sh
source $TOP_DIR/admin-openrc

###############################################################################
echocolor "Create flavor"
openstack flavor create --id 0 --vcpus 1 --ram 512 --disk 1 t2.nano
openstack flavor create --id 1 --vcpus 1 --ram 1024 --disk 1 t2.micro
openstack flavor create --id 2 --vcpus 1 --ram 2048 --disk 1 t2.small
openstack flavor create --id 3 --vcpus 2 --ram 4096 --disk 1 t2.medium
openstack flavor create --id 4 --vcpus 2 --ram 8196 --disk 1 t2.large
openstack flavor create --id 5 --vcpus 4 --ram 16384 --disk 1 t2.xlarge
openstack flavor create --id 6 --vcpus 8 --ram 32768 --disk 1 t2.2xlarge

openstack flavor create --id 7 --vcpus 2 --ram 8196 --disk 1 m4.large
openstack flavor create --id 8 --vcpus 4 --ram 16384 --disk 1 m4.xlarge

echocolor "Create provider network"
openstack network create --share \
    --provider-physical-network provider \
    --provider-network-type flat provider

echocolor "Create subnet for provider network"
openstack subnet create --network provider \
    --allocation-pool start=20.20.20.220,end=20.20.20.245 \
    --dns-nameserver 8.8.8.8 --gateway 20.20.20.1 \
    --subnet-range 20.20.20.0/24 provider

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