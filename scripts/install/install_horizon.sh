#!/bin/bash
## Install HOZIRON

###############################################################################
## Init enviroiment source
dir_path=$(dirname $0)
source $dir_path/../config.cfg
source $dir_path/../lib/functions.sh

source admin-openrc

## PATH
filehtml=/var/www/html/index.html
localcnf=/etc/openstack-dashboard/local_settings.py

echocolor "Installing Dashboard package"
apt-get -y install openstack-dashboard

echocolor "Creating redirect page"
test -f $filehtml.orig || cp $filehtml $filehtml.orig

rm $filehtml
touch $filehtml
cat << EOF >> $filehtml
<html>
<head>
<META HTTP-EQUIV="Refresh" Content="0.5; URL=http://$CTL_EXT_IP/horizon">
</head>
<body>
<center> <h1>Redirecting to OpenStack Dashboard</h1> </center>
</body>
</html>
EOF

test -f $localcnf.orig || cp $localcnf $localcnf.orig
test -f $filehtml.orig && cp -f $localcnf.orig $localcnf

# Configure the dashboard to use OpenStack services on the controller node
# OPENSTACK_HOST = "controller"
sed -i "s/127.0.0.1/$CTL_MGNT_IP/g" $localcnf
# In the Dashboard configuration section, allow your hosts to access Dashboard
# ALLOWED_HOSTS = ['one.example.com', 'two.example.com']
# ALLOWED_HOSTS = ['*']

# Configure the memcached session storage service
cat $localcnf | grep SESSION_ENGINE || cat << EOF >> $localcnf
SESSION_ENGINE = 'django.contrib.sessions.backends.cache'
EOF

# Enable the Identity API version 3
# OPENSTACK_KEYSTONE_URL = "http://%s:5000/v3" % OPENSTACK_HOST
sed -i "s/http:\/\/\%s:5000\/v2.0/http:\/\/\%s:5000\/v3/g" $localcnf

# Enable support for domains
sed -i "s/OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT = .*/OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT = True/g" $localcnf

# Configure API versions
# cat << EOF >> $localcnf
# OPENSTACK_API_VERSIONS = {
# #    "data-processing": 1.1,
#     "identity": 3,
#     "volume": 2,
#     "compute": 2,
# }
# EOF

# Configure Default as the default domain for users that you create via the dashboard
sed -i "s/OPENSTACK_KEYSTONE_DEFAULT_DOMAIN = .*/OPENSTACK_KEYSTONE_DEFAULT_DOMAIN = 'Default'/g" $localcnf

# Configure user as the default role for users that you create via the dashboard
sed -i "s/OPENSTACK_KEYSTONE_DEFAULT_ROLE = .*/OPENSTACK_KEYSTONE_DEFAULT_ROLE = 'user'/g" $localcnf

# Optionally, configure the time zone
sed -i "s/TIME_ZONE = .*/TIME_ZONE = 'Asia\/Ho_Chi_Minh'/g" $localcnf
sed -i "s/DEFAULT_THEME = 'ubuntu'/DEFAULT_THEME = 'default'/g" $localcnf

# # Allowing insert password in dashboard ( only apply in image )
sed -i "s/'can_set_password': False/'can_set_password': True/g" $localcnf
sed -i "s/_member_/user/g" $localcnf

sed -i "s/#OPENSTACK_KEYSTONE_DEFAULT_DOMAIN = 'default'/\
OPENSTACK_KEYSTONE_DEFAULT_DOMAIN = 'default'/g" \
    $localcnf

service apache2 reload

echocolor "Finish setting up Horizon"
echocolor "LOGIN INFORMATION IN HORIZON"
echocolor "URL: http://$CTL_EXT_IP/horizon"
echocolor "User: admin or demo"
echocolor "Password: $ADMIN_PASS"
