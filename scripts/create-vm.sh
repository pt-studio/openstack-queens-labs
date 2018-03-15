#!/bin/bash 

set -e

###############################################################################
## Init enviroiment source
dir_path=$(dirname $0)
source $dir_path/config.cfg
source $dir_path/lib/functions.sh

###############################################################################
echocolor "Tao flavor"
openstack flavor create --id 0 --vcpus 1 --ram 64 --disk 1 m1.nano
openstack flavor create --id 1 --vcpus 1 --ram 512 --disk 1 m1.tiny
openstack flavor create --id 2 --vcpus 2 --ram 2048 --disk 20 m1.small
openstack flavor create --id 3 --vcpus 2 --ram 4096 --disk 40 m1.medium

echocolor "Mo rule ping"
openstack security group rule create --proto icmp default --debug
openstack security group rule create --proto tcp --dst-port 22 default

echocolor "Tao provider network"
openstack network create --share \
    --provider-physical-network provider \
    --provider-network-type flat provider

echocolor "Tao subnet cho provider network"
openstack subnet create --network provider \
    --allocation-pool start=192.168.25.50,end=192.168.25.80 \
    --dns-nameserver 8.8.8.8 --gateway 192.168.25.1 \
    --subnet-range 192.168.25.0/24 provider

echocolor "Tao VM gan vao provider network"

PROVIDER_NET_ID=`openstack network list | egrep -w provider | awk '{print $2}'`

openstack server create --flavor m1.nano --image cirros \
    --nic net-id=$PROVIDER_NET_ID --security-group default \
    provider-VM1

###############################################################################
echocolor "Tao private network (selfservice network)"
openstack network create selfservice

echocolor "Tao subnet cho private network"
openstack subnet create --network selfservice \
    --dns-nameserver 8.8.4.4 --gateway 192.168.10.1 \
    --subnet-range 192.168.10.0/24 selfservice

echocolor "Tao va gan inteface cho ROUTER"
openstack router create router
neutron net-update provider --router:external
neutron router-interface-add router selfservice
neutron router-gateway-set router provider

echocolor "Tao may ao gan vao private network (selfservice network)"
PRIVATE_NET_ID=`openstack network list | egrep -w selfservice | awk '{print $2}'`
openstack server create --flavor m1.nano --image cirros \
    --nic net-id=$PRIVATE_NET_ID --security-group default \
    selfservice-VM1

echocolor "Floatig IP"
FLOATING_IP=`openstack floating ip create provider | egrep -w floating_ip_address | awk '{print $4}'`
openstack server add floating ip selfservice-VM1 $FLOATING_IP
