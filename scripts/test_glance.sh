#!/bin/bash

set -e

. admin-openrc

echo "Registering Cirros IMAGE for GLANCE"

wget -c http://download.cirros-cloud.net/0.4.0/cirros-0.4.0-x86_64-disk.img

openstack image create "cirros" \
    --id 16c4bc2a-1143-4b46-b9ed-87768cc82223 \
    --file cirros-0.4.0-x86_64-disk.img \
    --disk-format qcow2 \
    --container-format bare \
    --public

#rm -f cirros-*-x86_64-disk.img
