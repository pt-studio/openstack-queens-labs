#!/bin/bash
###############################################################################
## Init environment source
dir_path=$(dirname $0)
source $dir_path/config.cfg
source $dir_path/lib/functions.sh

###############################################################################
## Khai bao duong dan
path_chrony=/etc/chrony/chrony.conf
path_db_openstack=/etc/mysql/conf.d/openstack.cnf
path_db_50server=/etc/mysql/mariadb.conf.d/50-server.cnf

#############################################
function install_crudini {
    echocolor "Installing CRUDINI"
    apt-get -y install crudini
}

#############################################
function install_python_client {
    echocolor "Install python client"
    apt-get -y install python-openstackclient
}

#############################################
function install_ntp {
    echocolor "Install and config NTP"
    apt-get -y install chrony
    test -f $path_chrony.orig || cp $path_chrony $path_chrony.orig

    if [ "$1" == "controller" ]; then
        sed -i 's/pool 2.debian.pool.ntp.org offline iburst/\
server 1.vn.pool.ntp.org iburst \
server 0.asia.pool.ntp.org iburst \
server 3.asia.pool.ntp.org iburst/g' $path_chrony

    elif [ "$1" == "compute1" ] || [ "$1" == "compute2" ]; then
        sed -i "s/pool 2.debian.pool.ntp.org offline iburst/\
server $HOST_CTL iburst/g" $path_chrony

    fi

    service chrony restart
    echocolor "Check NTP Server"
    chronyc sources
}

###############################################################################
function install_database ()
{
    echocolor "Install and Config MariaDB"
    echo "deb http://sgp1.mirrors.digitalocean.com/mariadb/repo/10.2/ubuntu/ xenial main" > /etc/apt/sources.list.d/mariadb.list
    http_proxy=http://10.10.10.10:8080/ apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8
    apt-get update

    echo "mariadb-server-10.2 mysql-server/root_password password $MYSQL_PASS" | debconf-set-selections
    echo "mariadb-server-10.2 mysql-server/root_password_again password $MYSQL_PASS" | debconf-set-selections

    apt-get -y install mariadb-server python-pymysql

    sed -r -i 's/127\.0\.0\.1/0\.0\.0\.0/' $path_db_50server
    sed -i 's/character-set-server  = utf8mb4/character-set-server = utf8/' \
        $path_db_50server
    sed -i 's/collation-server/#collation-server/' $path_db_50server

    systemctl enable mysql

    cat << EOF | mysql -uroot -p$MYSQL_PASS 
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '$MYSQL_PASS' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' IDENTIFIED BY '$MYSQL_PASS' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF
    
    ops_edit $path_db_openstack mysqld default-storage-engine innodb
    ops_edit $path_db_openstack mysqld innodb_file_per_table on
    ops_edit $path_db_openstack mysqld max_connections 4096
    ops_edit $path_db_openstack mysqld collation-server utf8_general_ci
    ops_edit $path_db_openstack client default-character-set utf8
    ops_edit $path_db_openstack mysqld bind-address 0.0.0.0
    ops_edit $path_db_openstack mysqld character-set-server utf8

    echocolor "Restarting MYSQL"
    nc -nz 127.0.0.1 3306
    systemctl restart mysql

}

###############################################################################
function install_rabbitmq {
    echocolor "Install and Config RabbitMQ"
    apt-get -y install rabbitmq-server

    nc -nz 127.0.0.1 5672

    rabbitmqctl add_user openstack $RABBIT_PASS
    rabbitmqctl set_permissions openstack ".*" ".*" ".*"

    service rabbitmq-server restart
}

###############################################################################
function install_memcache {
    echocolor "Install and Config Memcache"

    apt-get -y install memcached python-memcache
    sed -i "s/-l 127.0.0.1/-l $CTL_MGNT_IP/g" /etc/memcached.conf

    service memcached restart
    systemctl enable memcached.service

    echocolor "Done, you can run next script"
}

function install_etcd {
    groupadd --system etcd
    useradd --home-dir "/var/lib/etcd" \
        --system \
        --shell /bin/false \
        -g etcd \
        etcd

    mkdir -p /etc/etcd
    chown etcd:etcd /etc/etcd
    mkdir -p /var/lib/etcd
    chown etcd:etcd /var/lib/etcd

    ETCD_VER=v3.2.7
    rm -rf /tmp/etcd && mkdir -p /tmp/etcd
    curl -L https://github.com/coreos/etcd/releases/download/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz -o /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz
    tar xzvf /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz -C /tmp/etcd --strip-components=1
    cp /tmp/etcd/etcd /usr/bin/etcd
    cp /tmp/etcd/etcdctl /usr/bin/etcdctl

    cat << EOF > /etc/etcd/etcd.conf.yml
name: controller
data-dir: /var/lib/etcd
initial-cluster-state: 'new'
initial-cluster-token: 'etcd-cluster-01'
initial-cluster: controller=http://$CTL_MGNT_IP:2380
initial-advertise-peer-urls: http://$CTL_MGNT_IP:2380
advertise-client-urls: http://$CTL_MGNT_IP:2379
listen-peer-urls: http://0.0.0.0:2380
listen-client-urls: http://$CTL_MGNT_IP:2379
EOF

    cat << EOF > /lib/systemd/system/etcd.service
[Unit]
After=network.target
Description=etcd - highly-available key value store

[Service]
LimitNOFILE=65536
Restart=on-failure
Type=notify
ExecStart=/usr/bin/etcd --config-file /etc/etcd/etcd.conf.yml
User=etcd

[Install]
WantedBy=multi-user.target
EOF
    systemctl enable etcd
    systemctl start etcd
}

### Running function
### Checking and help syntax command
if [ $# -ne 1 ]; then
    echocolor  "STEP 2: Setup Environment"
    echo "Setup steps:"
    echo "    Install CrudIni"
    echo "    Install OpenStack client"
    echo "    Install NTP server"
    echo "    Install MariaDB 10.2"
    echo "    Install RabbitMQ"
    echo "    Install Memcached"
    echo "    Install Etcd"
    echo "Syntax command on"
    echo "    Controller: bash $0 controller"
    echo "    Compute1: bash $0 compute1"
    echo "    Compute2: bash $0 compute2"
    exit 1;
fi

if [ "$1" == "controller" ]; then 
    install_crudini
    install_python_client
    install_ntp $1
    install_database
    install_rabbitmq
    install_memcache
    install_etcd

else 
    install_crudini
    install_python_client
    install_ntp $1
fi
