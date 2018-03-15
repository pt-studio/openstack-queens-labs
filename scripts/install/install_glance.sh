#!/bin/bash
## Install GLANCE | Image service

###############################################################################
dir_path=$(dirname $0)
source $dir_path/../config.cfg
source $dir_path/../lib/functions.sh
source admin-openrc

##  Init config path
glancereg_ctl=/etc/glance/glance-registry.conf
glanceapi_ctl=/etc/glance/glance-api.conf

test -f $glancereg_ctl.orig || cp $glancereg_ctl $glancereg_ctl.orig
test -f $glanceapi_ctl.orig || cp $glanceapi_ctl $glanceapi_ctl.orig

###############################################################################
print_header "Create the database for GLANCE"

cat << EOF | mysql -uroot -p$MYSQL_PASS
DROP DATABASE IF EXISTS glance;
CREATE DATABASE glance;

GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY '$GLANCE_DBPASS';
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY '$GLANCE_DBPASS';

FLUSH PRIVILEGES;
EOF

print_header "Create user, endpoint for GLANCE"

openstack user create glance --domain default --password $GLANCE_PASS
openstack role add --project service --user glance admin
openstack service create --name glance --description \
    "OpenStack Image service" image

openstack endpoint create --region RegionOne \
    image public http://$CTL_MGNT_IP:9292
openstack endpoint create --region RegionOne \
    image internal http://$CTL_MGNT_IP:9292
openstack endpoint create --region RegionOne \
    image admin http://$CTL_MGNT_IP:9292

print_install "Install GLANCE"
apt-get -y install glance

print_header "Configuring GLANCE API"

# Configuring glance config file /etc/glance/glance-api.conf
## [database] section
ops_edit $glanceapi_ctl database \
    connection mysql+pymysql://glance:$GLANCE_DBPASS@$CTL_MGNT_IP/glance
#ops_del $glanceapi_ctl database sqlite_db

## [keystone_authtoken] section
ops_edit $glanceapi_ctl keystone_authtoken \
    auth_uri http://$CTL_MGNT_IP:5000
ops_edit $glanceapi_ctl keystone_authtoken \
    auth_url http://$CTL_MGNT_IP:5000
ops_edit $glanceapi_ctl keystone_authtoken \
    memcached_servers $CTL_MGNT_IP:11211
ops_edit $glanceapi_ctl keystone_authtoken auth_type password
ops_edit $glanceapi_ctl keystone_authtoken project_domain_name default
ops_edit $glanceapi_ctl keystone_authtoken user_domain_name default
ops_edit $glanceapi_ctl keystone_authtoken project_name service
ops_edit $glanceapi_ctl keystone_authtoken username glance
ops_edit $glanceapi_ctl keystone_authtoken password $GLANCE_PASS

## [paste_deploy] section
ops_edit $glanceapi_ctl paste_deploy flavor keystone

## [glance_store] section
ops_edit $glanceapi_ctl glance_store stores file,http
ops_edit $glanceapi_ctl glance_store default_store file
ops_edit $glanceapi_ctl glance_store \
    filesystem_store_datadir /var/lib/glance/images/

#
print_header "Configuring GLANCE REGISTRY"

## [DEFAULT] section
#ops_edit $glancereg_ctl DEFAULT verbose true

## [database] section
ops_edit $glancereg_ctl database \
    connection mysql+pymysql://glance:$GLANCE_DBPASS@$CTL_MGNT_IP/glance
#ops_del $glancereg_ctl database sqlite_db

## [keystone_authtoken] section
ops_edit $glancereg_ctl keystone_authtoken \
    auth_uri http://$CTL_MGNT_IP:5000
ops_edit $glancereg_ctl keystone_authtoken \
    auth_url http://$CTL_MGNT_IP:5000
ops_edit $glancereg_ctl keystone_authtoken \
    memcached_servers $CTL_MGNT_IP:11211
ops_edit $glancereg_ctl keystone_authtoken auth_type password
ops_edit $glancereg_ctl keystone_authtoken project_domain_name default
ops_edit $glancereg_ctl keystone_authtoken user_domain_name default
ops_edit $glancereg_ctl keystone_authtoken project_name service
ops_edit $glancereg_ctl keystone_authtoken username glance
ops_edit $glancereg_ctl keystone_authtoken password $GLANCE_PASS

## [paste_deploy] section
ops_edit $glancereg_ctl paste_deploy flavor keystone

echocolor "Populate the Image service database"
su -s /bin/sh -c "glance-manage db_sync" glance

echocolor "Restart the Image services"
service glance-registry restart
service glance-api restart

echocolor "Remove glance.sqlite "
#rm -f /var/lib/glance/glance.sqlite

echocolor "Registering Cirros IMAGE for GLANCE"

http_proxy=http://10.10.10.10:8080 wget http://download.cirros-cloud.net/0.4.0/cirros-0.4.0-x86_64-disk.img

openstack image create "cirros" \
    --id 1 \
    --file cirros-0.4.0-x86_64-disk.img \
    --disk-format qcow2 --container-format bare \
    --public

rm -f cirros-*-x86_64-disk.img

print_header "Verify operation"
openstack image list
