#!/bin/bash 

###############################################################################
## Init enviroiment source
dir_path=$(dirname $0)
source $dir_path/config.cfg
source $dir_path/lib/functions.sh

###############################################################################
echocolor "Tao flavor"
sleep 3
openstack flavor create --id 0 --vcpus 1 --ram 64 --disk 1 m1.nano

echocolor "Mo rule ping"
sleep 5
openstack security group rule create --proto icmp default
openstack security group rule create --proto tcp --dst-port 22 default

echocolor "Tao provider network"
sleep 3
openstack network create  --share \
	--provider-physical-network provider \
	--provider-network-type flat provider

echocolor "Tao subnet cho provider network"
sleep 3
openstack subnet create --network provider \
	--allocation-pool start=172.16.69.50,end=172.16.69.80 \
	--dns-nameserver 8.8.8.8 --gateway 172.16.69.1 \
	--subnet-range 172.16.69.0/24 provider

echocolor "Tao VM gan vao provider network"
sleep 5

PROVIDER_NET_ID=`openstack network list | egrep -w provider | awk '{print $2}'`

openstack server create --flavor m1.nano --image cirros \
	--nic net-id=$PROVIDER_NET_ID --security-group default \
	provider-VM1

###############################################################################
echocolor "Tao private network (selfservice network)"
sleep 3
openstack network create selfservice

echocolor "Tao subnnet cho private network"
sleep 3
 openstack subnet create --network selfservice \
 	--dns-nameserver 8.8.4.4 --gateway 192.168.10.1 \
 	--subnet-range 192.168.10.0/24 selfservice

echocolor "Tao va gan inteface cho ROUTER"
sleep 3
openstack router create router
neutron net-update provider --router:external
neutron router-interface-add router selfservice
neutron router-gateway-set router provider

echocolor "Tao may ao gan vao private network (selfservice network)"
sleep 5
PRIVATE_NET_ID=`openstack network list | egrep -w selfservice | awk '{print $2}'`
openstack server create --flavor m1.nano --image cirros \
  --nic net-id=$PRIVATE_NET_ID --security-group default \
  selfservice-VM1


echocolor "Floatig IP"
sleep 5
FLOATING_IP=`openstack floating ip create provider | egrep -w floating_ip_address | awk '{print $4}'`
openstack server add floating ip selfservice-VM1 $FLOATING_IP