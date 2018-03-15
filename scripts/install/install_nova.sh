#!/bin/bash
## Install NOVA

###############################################################################
## Init enviroiment source
dir_path=$(dirname $0)
source $dir_path/../config.cfg
source $dir_path/../lib/functions.sh

source admin-openrc

##  Init config path
nova_ctl=/etc/nova/nova.conf
novacom_ctl=/etc/nova/nova-compute.conf

if [ "$1" == "controller" ]; then
    echocolor "Create DB for NOVA"
    cat << EOF | mysql -uroot -p$MYSQL_PASS
DROP DATABASE IF EXISTS nova_api;
DROP DATABASE IF EXISTS nova;
DROP DATABASE IF EXISTS nova_cell0;

CREATE DATABASE nova_api;
CREATE DATABASE nova;
CREATE DATABASE nova_cell0;

GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'localhost' IDENTIFIED BY '$NOVA_API_DBPASS';
GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'%' IDENTIFIED BY '$NOVA_API_DBPASS';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY '$NOVA_DBPASS';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY '$NOVA_DBPASS';
GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'localhost' IDENTIFIED BY '$NOVA_DBPASS';
GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'%' IDENTIFIED BY '$NOVA_DBPASS';

FLUSH PRIVILEGES;
EOF

fi

if [ "$1" == "controller" ]; then
    echocolor "Create the Compute service credentials"
    openstack user create nova --domain default --password $NOVA_PASS
    openstack role add --project service --user nova admin
    openstack service create --name nova --description "OpenStack Compute" compute

    echocolor "Create the Compute API service endpoints"
    openstack endpoint create --region RegionOne \
        compute public http://$CTL_MGNT_IP:8774/v2.1
    openstack endpoint create --region RegionOne \
        compute internal http://$CTL_MGNT_IP:8774/v2.1
    openstack endpoint create --region RegionOne \
        compute admin http://$CTL_MGNT_IP:8774/v2.1

    openstack user create --domain default --password $PLACEMENT_PASS placement
    openstack role add --project service --user placement admin
    openstack service create --name placement --description "Placement API" placement
    openstack endpoint create --region RegionOne placement public http://$CTL_MGNT_IP:8778
    openstack endpoint create --region RegionOne placement internal http://$CTL_MGNT_IP:8778
    openstack endpoint create --region RegionOne placement admin http://$CTL_MGNT_IP:8778

fi

echocolor "Install and configure components"
if [ "$1" == "controller" ]; then
    echocolor "Install NOVA in $CTL_MGNT_IP"
    apt-get -y install nova-api nova-conductor nova-consoleauth \
        nova-novncproxy nova-scheduler nova-placement-api

elif [ "$1" == "compute1" ] || [ "$1" == "compute2" ] ; then
    echocolor "Install NOVA in $1"
     apt-get -y install nova-compute

fi

test -f $nova_ctl.orig || cp $nova_ctl $nova_ctl.orig

echocolor "Modify nova.conf"
## [DEFAULT] section
# Work a round bug: https://bugs.launchpad.net/ubuntu/+source/nova/+bug/1506667
ops_del $nova_ctl DEFAULT logdir
ops_del $nova_ctl DEFAULT verbose

# ops_edit $nova_ctl DEFAULT log-dir /var/log/nova
# ops_edit $nova_ctl DEFAULT enabled_apis osapi_compute,metadata
# ops_edit $nova_ctl DEFAULT rpc_backend rabbit
ops_edit $nova_ctl DEFAULT auth_strategy keystone
# ops_edit $nova_ctl DEFAULT rootwrap_config /etc/nova/rootwrap.conf

echocolor "Configure database access"
if [ "$1" == "controller" ]; then
    ops_edit $nova_ctl api_database \
        connection mysql+pymysql://nova:$NOVA_API_DBPASS@$CTL_MGNT_IP/nova_api
    ops_edit $nova_ctl database \
        connection mysql+pymysql://nova:$NOVA_DBPASS@$CTL_MGNT_IP/nova

else
    # Determine whether your compute node supports hardware acceleration for virtual machines
    # If this command returns a value of zero, your compute node does not support hardware acceleration and you must configure libvirt to use QEMU instead of KVM.
    egrep -c '(vmx|svm)' /proc/cpuinfo | grep 0 && ops_edit $novacom_ctl libvirt virt_type qemu
fi

echocolor "Configure message queue access"
ops_edit $nova_ctl DEFAULT transport_url rabbit://openstack:$RABBIT_PASS@$CTL_MGNT_IP

echocolor "Configure identity service access"
ops_edit $nova_ctl keystone_authtoken auth_uri http://$CTL_MGNT_IP:5000
ops_edit $nova_ctl keystone_authtoken auth_url http://$CTL_MGNT_IP:5000
ops_edit $nova_ctl keystone_authtoken memcached_servers $CTL_MGNT_IP:11211
ops_edit $nova_ctl keystone_authtoken auth_type password
ops_edit $nova_ctl keystone_authtoken project_domain_name default
ops_edit $nova_ctl keystone_authtoken user_domain_name default
ops_edit $nova_ctl keystone_authtoken project_name service
ops_edit $nova_ctl keystone_authtoken username nova
ops_edit $nova_ctl keystone_authtoken password $NOVA_PASS

# configure the my_ip option to use the management interface IP address of the controller node
if [ "$1" == "controller" ]; then
    ops_edit $nova_ctl DEFAULT my_ip $CTL_MGNT_IP

elif [ "$1" == "compute1" ]; then
    ops_edit $nova_ctl DEFAULT my_ip $COM1_MGNT_IP

elif [ "$1" == "compute2" ]; then
    ops_edit $nova_ctl DEFAULT my_ip $COM2_MGNT_IP
fi

ops_edit $nova_ctl DEFAULT use_neutron true
ops_edit $nova_ctl DEFAULT \
    firewall_driver nova.virt.firewall.NoopFirewallDriver

echocolor "Configure the VNC proxy"
if [ "$1" == "controller" ]; then
    ops_edit $nova_ctl vnc vncserver_listen \$my_ip
    ops_edit $nova_ctl vnc vncserver_proxyclient_address \$my_ip

elif [ "$1" == "compute1" ] || [ "$1" == "compute2" ] ; then
    ops_edit $nova_ctl vnc enabled  true
    ops_edit $nova_ctl vnc vncserver_listen 0.0.0.0
    ops_edit $nova_ctl vnc vncserver_proxyclient_address \$my_ip
    ops_edit $nova_ctl vnc novncproxy_base_url http://$CTL_MGNT_IP:6080/vnc_auto.html
fi

## In the [glance] section, configure the location of the Image service API
ops_edit $nova_ctl glance api_servers http://$CTL_MGNT_IP:9292

## In the [oslo_concurrency] section, configure the lock path
ops_edit $nova_ctl oslo_concurrency lock_path /var/lib/nova/tmp

## In the [placement] section, configure the Placement API
ops_edit $nova_ctl placement os_region_name RegionOne
ops_edit $nova_ctl placement project_domain_name Default
ops_edit $nova_ctl placement project_name service
ops_edit $nova_ctl placement auth_type password
ops_edit $nova_ctl placement user_domain_name Default
ops_edit $nova_ctl placement auth_url http://$CTL_MGNT_IP:5000/v3
ops_edit $nova_ctl placement username placement
ops_edit $nova_ctl placement password $PLACEMENT_PASS

if [ "$1" == "controller" ]; then 
    echocolor "Remove Nova default db "
    rm -f /var/lib/nova/nova.sqlite

    echocolor "Syncing Nova DB"
    su -s /bin/sh -c "nova-manage api_db sync" nova
    su -s /bin/sh -c "nova-manage cell_v2 map_cell0" nova
    su -s /bin/sh -c "nova-manage cell_v2 create_cell --name=cell1 --verbose" nova
    su -s /bin/sh -c "nova-manage db sync" nova

    echocolor "Testing NOVA service"
    # service apache2 start
    # openstack compute service list
    nova-manage cell_v2 list_cells

    service nova-api restart
    service nova-consoleauth restart
    service nova-scheduler restart
    service nova-conductor restart
    service nova-novncproxy restart

    openstack extension list --network

elif [ "$1" == "compute1" ] || [ "$1" == "compute2" ]; then
    echocolor "Restarting NOVA on $1"
    service nova-compute restart

    # Run the following commands on the controller node.
    # echocolor "Add the compute node to the cell database"
    # su -s /bin/sh -c "nova-manage cell_v2 discover_hosts --verbose" nova

fi