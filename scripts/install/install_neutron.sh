#!/bin/bash
## Install NEUTRON

###############################################################################

## Init enviroiment source
dir_path=$(dirname $0)
source $dir_path/../config.cfg
source $dir_path/../lib/functions.sh

source admin-openrc

##  Init config path
neutron_ctl=/etc/neutron/neutron.conf
neutron_com=/etc/neutron/neutron.conf
netmetadata=/etc/neutron/metadata_agent.ini
ml2_clt=/etc/neutron/plugins/ml2/ml2_conf.ini
lbfile=/etc/neutron/plugins/ml2/linuxbridge_agent.ini
netdhcp=/etc/neutron/dhcp_agent.ini
netl3agent=/etc/neutron/l3_agent.ini

if [ "$1" == "controller" ]; then

	# echocolor "Configuring net forward for all VMs"
	# sleep 5
	# echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
	# echo "net.ipv4.conf.all.rp_filter=0" >> /etc/sysctl.conf
	# echo "net.ipv4.conf.default.rp_filter=0" >> /etc/sysctl.conf
	# sysctl -p

	echocolor "Create DB for NEUTRON on $1 "
	sleep 5
	cat << EOF | mysql -uroot -p$MYSQL_PASS
CREATE DATABASE neutron;
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY '$NEUTRON_DBPASS';
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY '$NEUTRON_DBPASS';
FLUSH PRIVILEGES;
EOF

	echocolor "Create  user, endpoint for NEUTRON"
	sleep 5

	openstack user create neutron --domain default --password $NEUTRON_PASS
	openstack role add --project service --user neutron admin

	openstack service create --name neutron \
	    --description "OpenStack Networking" network

	openstack endpoint create --region RegionOne \
	    network public http://$CTL_MGNT_IP:9696

	openstack endpoint create --region RegionOne \
	    network internal http://$CTL_MGNT_IP:9696

	openstack endpoint create --region RegionOne \
	    network admin http://$CTL_MGNT_IP:9696

	# SERVICE_TENANT_ID=`keystone tenant-get service | awk '$2~/^id/{print $4}'`

	echocolor "Install NEUTRON node - Using Linux Bridge on $1"
	sleep 5
	apt-get -y install neutron-server neutron-plugin-ml2 \
	neutron-linuxbridge-agent neutron-l3-agent neutron-dhcp-agent \
	neutron-metadata-agent


	######## Backup configuration NEUTRON.CONF ##################"
	echocolor "Config NEUTRON"
	sleep 5

	#
	test -f $neutron_ctl.orig || cp $neutron_ctl $neutron_ctl.orig

	## [DEFAULT] section

	ops_edit $neutron_ctl DEFAULT service_plugins router
	ops_edit $neutron_ctl DEFAULT allow_overlapping_ips True
	ops_edit $neutron_ctl DEFAULT auth_strategy keystone
	ops_edit $neutron_ctl DEFAULT rpc_backend rabbit
	ops_edit $neutron_ctl DEFAULT notify_nova_on_port_status_changes True
	ops_edit $neutron_ctl DEFAULT notify_nova_on_port_data_changes True
	ops_edit $neutron_ctl DEFAULT core_plugin ml2
	# ops_edit $neutron_ctl DEFAULT nova_url http://$CTL_MGNT_IP:8774/v2
	# ops_edit $neutron_ctl DEFAULT verbose True
	ops_edit $neutron_ctl DEFAULT transport_url  rabbit://openstack:$RABBIT_PASS@$CTL_MGNT_IP

	## [database] section
	ops_edit $neutron_ctl database \
	connection mysql+pymysql://neutron:$NEUTRON_DBPASS@$CTL_MGNT_IP/neutron


	## [keystone_authtoken] section
	ops_edit $neutron_ctl keystone_authtoken auth_uri http://$CTL_MGNT_IP:5000
	ops_edit $neutron_ctl keystone_authtoken auth_url http://$CTL_MGNT_IP:35357
	ops_edit $neutron_ctl keystone_authtoken memcached_servers $CTL_MGNT_IP:11211
	ops_edit $neutron_ctl keystone_authtoken auth_type password
	ops_edit $neutron_ctl keystone_authtoken project_domain_name default
	ops_edit $neutron_ctl keystone_authtoken user_domain_name default
	ops_edit $neutron_ctl keystone_authtoken project_name service
	ops_edit $neutron_ctl keystone_authtoken username neutron
	ops_edit $neutron_ctl keystone_authtoken password $NEUTRON_PASS


	## [oslo_messaging_rabbit] section
	# ops_edit $neutron_ctl oslo_messaging_rabbit rabbit_host $CTL_MGNT_IP
	# ops_edit $neutron_ctl oslo_messaging_rabbit rabbit_userid openstack
	# ops_edit $neutron_ctl oslo_messaging_rabbit rabbit_password $RABBIT_PASS

	## [nova] section
	ops_edit $neutron_ctl nova auth_url http://$CTL_MGNT_IP:35357
	ops_edit $neutron_ctl nova auth_type password
	ops_edit $neutron_ctl nova project_domain_name default
	ops_edit $neutron_ctl nova user_domain_name default
	ops_edit $neutron_ctl nova region_name RegionOne
	ops_edit $neutron_ctl nova project_name service
	ops_edit $neutron_ctl nova username nova
	ops_edit $neutron_ctl nova password $NOVA_PASS

	######## Backup configuration of ML2 ##################"
	echocolor "Configuring ML2"
	sleep 7

	test -f $ml2_clt.orig || cp $ml2_clt $ml2_clt.orig

	## [ml2] section
	ops_edit $ml2_clt ml2 type_drivers flat,vlan,vxlan
	ops_edit $ml2_clt ml2 tenant_network_types vxlan
	ops_edit $ml2_clt ml2 mechanism_drivers linuxbridge,l2population
	ops_edit $ml2_clt ml2 extension_drivers port_security


	## [ml2_type_flat] section
	ops_edit $ml2_clt ml2_type_flat flat_networks provider

	## [ml2_type_gre] section
	# ops_edit $ml2_clt ml2_type_gre tunnel_id_ranges 100:200

	## [ml2_type_vxlan] section
	ops_edit $ml2_clt ml2_type_vxlan vni_ranges 201:300

	## [securitygroup] section
	ops_edit $ml2_clt securitygroup enable_ipset True

	echocolor "Configuring linuxbridge_agent"
	sleep 5
	test -f $lbfile.orig || cp $lbfile $lbfile.orig

	# [linux_bridge] section
	ops_edit $lbfile linux_bridge physical_interface_mappings provider:$EXT_INTERFACE

	# [vxlan] section
	ops_edit $lbfile vxlan enable_vxlan True
	ops_edit $lbfile vxlan local_ip $CTL_DATA_IP
	ops_edit $lbfile vxlan l2_population True

	# [securitygroup] section
	ops_edit $lbfile securitygroup enable_security_group True
	ops_edit $lbfile securitygroup firewall_driver \
	    neutron.agent.linux.iptables_firewall.IptablesFirewallDriver


	echocolor "Configuring L3 AGENT"
	sleep 7
	test -f $netl3agent.orig || cp $netl3agent $netl3agent.orig

	## [DEFAULT] section
	ops_edit $netl3agent DEFAULT interface_driver \
	    neutron.agent.linux.interface.BridgeInterfaceDriver
	ops_edit $netl3agent DEFAULT external_network_bridge
	# ops_edit $netl3agent DEFAULT router_delete_namespaces True
	# ops_edit $netl3agent DEFAULT verbose True


	echocolor "Configuring DHCP AGENT"
	sleep 7
	#
	test -f $netdhcp.orig || cp $netdhcp $netdhcp.orig

	## [DEFAULT] section
	ops_edit $netdhcp DEFAULT interface_driver \
	    neutron.agent.linux.interface.BridgeInterfaceDriver
	ops_edit $netdhcp DEFAULT dhcp_driver neutron.agent.linux.dhcp.Dnsmasq
	ops_edit $netdhcp DEFAULT enable_isolated_metadata True
	ops_edit $netdhcp DEFAULT dnsmasq_config_file /etc/neutron/dnsmasq-neutron.conf


	echocolor "Config MTU"
	sleep 3
	echo "dhcp-option-force=26,1454" > /etc/neutron/dnsmasq-neutron.conf
	# killall dnsmasq

	echocolor "Configuring METADATA AGENT"
	sleep 7
	

	test -f $netmetadata.orig || cp $netmetadata $netmetadata.orig

	## [DEFAULT]
	ops_edit $netmetadata DEFAULT nova_metadata_ip $CTL_MGNT_IP
	ops_edit $netmetadata DEFAULT metadata_proxy_shared_secret $METADATA_SECRET


	su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf \
	    --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron

	echocolor "Restarting NOVA service"
	sleep 7
	service nova-api restart
	service nova-scheduler restart
	service nova-conductor restart

	echocolor "Restarting NEUTRON service "
	sleep 7
	service neutron-server restart
	service neutron-linuxbridge-agent restart
	service neutron-dhcp-agent restart
	service neutron-metadata-agent restart
	service neutron-l3-agent restart

	rm -f /var/lib/neutron/neutron.sqlite

	echocolor "Check service Neutron"
	sleep 30
	neutron agent-list
	echocolor "Finished install NEUTRON on CONTROLLER"

elif [ "$1" == "compute1" ]; then
	echocolor "Restarting NEUTRON on $1"
	sleep 3
	apt -y install neutron-linuxbridge-agent
	test -f $neutron_com.orig || cp $neutron_com $neutron_com.orig

	ops_edit $neutron_com DEFAULT transport_url  rabbit://openstack:$RABBIT_PASS@$CTL_MGNT_IP
	ops_edit $neutron_com DEFAULT auth_strategy keystone	
	ops_edit $neutron_com DEFAULT notify_nova_on_port_status_changes True
	ops_edit $neutron_com DEFAULT notify_nova_on_port_data_changes True
	ops_edit $neutron_com DEFAULT core_plugin ml2

	## [database] section
	ops_edit $neutron_ctl database \
	connection mysql+pymysql://neutron:$NEUTRON_DBPASS@$CTL_MGNT_IP/neutron

	## [keystone_authtoken] section
	ops_edit $neutron_com  keystone_authtoken auth_uri http://$CTL_MGNT_IP:5000
	ops_edit $neutron_com  keystone_authtoken auth_url http://$CTL_MGNT_IP:35357
	ops_edit $neutron_com  keystone_authtoken memcached_servers $CTL_MGNT_IP:11211
	ops_edit $neutron_com  keystone_authtoken auth_type password
	ops_edit $neutron_com  keystone_authtoken project_domain_name default
	ops_edit $neutron_com  keystone_authtoken user_domain_name default
	ops_edit $neutron_com  keystone_authtoken project_name service
	ops_edit $neutron_com  keystone_authtoken username neutron
	ops_edit $neutron_com  keystone_authtoken password $NEUTRON_PASS

	echocolor "Configuring linuxbridge_agent"
	sleep 5
	test -f $lbfile.orig || cp $lbfile $lbfile.orig

	# [linux_bridge] section
	ops_edit $lbfile linux_bridge physical_interface_mappings provider:$EXT_INTERFACE

	# [vxlan] section
	ops_edit $lbfile vxlan enable_vxlan True
	ops_edit $lbfile vxlan local_ip $COM1_DATA_IP
	ops_edit $lbfile vxlan l2_population True

	# [securitygroup] section
	ops_edit $lbfile securitygroup enable_security_group True
	ops_edit $lbfile securitygroup firewall_driver \
	    neutron.agent.linux.iptables_firewall.IptablesFirewallDriver

	echocolor "Restarting NEUTRON service "
	sleep 7
	service neutron-linuxbridge-agent restart

elif [ "$1" == "compute2" ]; then
	echocolor "Restarting NEUTRON on $1"
	sleep 3
	apt -y install neutron-linuxbridge-agent
	test -f $neutron_com.orig || cp $neutron_com $neutron_com.orig

	ops_edit $neutron_com DEFAULT transport_url  rabbit://openstack:$RABBIT_PASS@$CTL_MGNT_IP
	ops_edit $neutron_com DEFAULT auth_strategy keystone	
	ops_edit $neutron_com DEFAULT notify_nova_on_port_status_changes True
	ops_edit $neutron_com DEFAULT notify_nova_on_port_data_changes True
	ops_edit $neutron_com DEFAULT core_plugin ml2

	## [database] section
	ops_edit $neutron_ctl database \
	connection mysql+pymysql://neutron:$NEUTRON_DBPASS@$CTL_MGNT_IP/neutron

	## [keystone_authtoken] section
	ops_edit $neutron_com  keystone_authtoken auth_uri http://$CTL_MGNT_IP:5000
	ops_edit $neutron_com  keystone_authtoken auth_url http://$CTL_MGNT_IP:35357
	ops_edit $neutron_com  keystone_authtoken memcached_servers $CTL_MGNT_IP:11211
	ops_edit $neutron_com  keystone_authtoken auth_type password
	ops_edit $neutron_com  keystone_authtoken project_domain_name default
	ops_edit $neutron_com  keystone_authtoken user_domain_name default
	ops_edit $neutron_com  keystone_authtoken project_name service
	ops_edit $neutron_com  keystone_authtoken username neutron
	ops_edit $neutron_com  keystone_authtoken password $NEUTRON_PASS

	echocolor "Configuring linuxbridge_agent"
	sleep 5
	test -f $lbfile.orig || cp $lbfile $lbfile.orig

	# [linux_bridge] section
	ops_edit $lbfile linux_bridge physical_interface_mappings provider:$EXT_INTERFACE

	# [vxlan] section
	ops_edit $lbfile vxlan enable_vxlan True
	ops_edit $lbfile vxlan local_ip $COM2_DATA_IP
	ops_edit $lbfile vxlan l2_population True

	# [securitygroup] section
	ops_edit $lbfile securitygroup enable_security_group True
	ops_edit $lbfile securitygroup firewall_driver \
	    neutron.agent.linux.iptables_firewall.IptablesFirewallDriver

	echocolor "Restarting NEUTRON service "
	sleep 7
	service neutron-linuxbridge-agent restart	

else
	echocolor "Khong phai node controller"
fi

echocolor "Da cau hinh xong"


