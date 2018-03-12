#!/bin/bash
## Install Keystone | Identity service

###############################################################################
## Khai bao cac chuong trinh ho tro
dir_path=$(dirname $0)
source $dir_path/../config.cfg
source $dir_path/../lib/functions.sh

echocolor "Create Database for Keystone"

cat << EOF | mysql -uroot -p$MYSQL_PASS
DROP DATABASE IF EXISTS keystone;
CREATE DATABASE keystone default character set utf8;
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY '$KEYSTONE_DBPASS' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY '$KEYSTONE_DBPASS' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF

echocolor "Install keystone"

apt-get install -y keystone apache2 libapache2-mod-wsgi

echocolor "Configure keystone"

path_keystone=/etc/keystone/keystone.conf
test -f $path_keystone.orig || cp $path_keystone $path_keystone.orig

# In the [database] section, configure database access
ops_edit $path_keystone database connection mysql+pymysql://keystone:$KEYSTONE_DBPASS@$CTL_MGNT_IP/keystone
# In the [token] section, configure the Fernet token provider
ops_edit $path_keystone token provider fernet
# Populate the Identity service database
su -s /bin/sh -c "keystone-manage db_sync" keystone
# Initialize Fernet key repositories
keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
keystone-manage credential_setup --keystone-user keystone --keystone-group keystone

echocolor "Bootstrap the Identity service"
nc -nz $CTL_MGNT_IP 5000
keystone-manage bootstrap --bootstrap-password $ADMIN_PASS \
  --bootstrap-admin-url http://$CTL_MGNT_IP:5000/v3/ \
  --bootstrap-internal-url http://$CTL_MGNT_IP:5000/v3/ \
  --bootstrap-public-url http://$CTL_MGNT_IP:5000/v3/ \
  --bootstrap-region-id RegionOne
  
echocolor "Configure the Apache HTTP server"
cat /etc/apache2/apache2.conf | grep ServerName || echo "ServerName $CTL_MGNT_IP" >>  /etc/apache2/apache2.conf
sed -i 's/ServerName .*/ServerName '$CTL_MGNT_IP'/g' /etc/apache2/apache2.conf
cat /etc/apache2/apache2.conf | grep ServerName

systemctl restart apache2
rm -f /var/lib/keystone/keystone.db

echocolor "Create a domain, projects, users, and roles"

export OS_USERNAME=admin
export OS_PASSWORD=$ADMIN_PASS
export OS_PROJECT_NAME=admin
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_DOMAIN_NAME=Default
export OS_AUTH_URL=http://$CTL_MGNT_IP:5000/v3
export OS_IDENTITY_API_VERSION=3

#openstack domain create --description "An Example Domain" example

# Create the service project
openstack project create --domain default \
  --description "Service Project" service

# Create the demo project
openstack project create --domain default \
  --description "Demo Project" demo

# Create the demo user
openstack user create --domain default --password $ADMIN_PASS demo
# Create the user role
openstack role create user
# Add the user role to the demo project and user
openstack role add --project demo --user demo user

unset OS_AUTH_URL OS_PASSWORD

#openstack --os-auth-url http://$CTL_MGNT_IP:5000/v3 \
#  --os-project-domain-name Default --os-user-domain-name Default \
#  --os-project-name admin --os-username admin token issue

#openstack --os-auth-url http://$CTL_MGNT_IP:5000/v3 \
#  --os-project-domain-name Default --os-user-domain-name Default \
#  --os-project-name demo --os-username demo token issue

# Create environment file
cat << EOF > admin-openrc
export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=$ADMIN_PASS
export OS_AUTH_URL=http://$CTL_MGNT_IP:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
EOF

echocolor "Verifying keystone"
echocolor "Execute environment script"
chmod +x admin-openrc

cat admin-openrc >> /etc/profile
cp admin-openrc /root/admin-openrc
source admin-openrc
openstack token issue


cat << EOF > demo-openrc
export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_NAME=demo
export OS_USERNAME=demo
export OS_PASSWORD=$DEMO_PASS
export OS_AUTH_URL=http://$CTL_MGNT_IP:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
EOF
chmod +x demo-openrc
cp demo-openrc /root/demo-openrc

openstack token issue

