#!/bin/bash
###############################################################################
## Init environment source
dir_path=$(dirname $0)
source $dir_path/config.cfg
source $dir_path/lib/functions.sh


###############################################################################
## Khai bao duong dan
path_hostname=/etc/hostname
path_interfaces=/etc/network/interfaces
path_hosts=/etc/hosts

###############################################################################
## Dinh nghia cac ham

function setup_ip_addr {
    print_header "Setup interfaces"
    test -f $path_interfaces.orig || cp $path_interfaces $path_interfaces.orig

    if [ "$1" == "controller" ]; then
        cat << EOF > /etc/network/interfaces
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

auto $MGNT_INTERFACE
iface $MGNT_INTERFACE inet static
    address $CTL_MGNT_IP
    netmask $NETMASK_ADD_MGNT

# The primary network interface
auto $EXT_INTERFACE
iface $EXT_INTERFACE inet static
    address $CTL_EXT_IP
    netmask $NETMASK_ADD_EXT
    gateway $GATEWAY_IP_EXT
    dns-nameservers $DNS_IP

# DATA VM
auto $DATA_INTERFACE
iface $DATA_INTERFACE inet static
    address $CTL_DATA_IP
    netmask $NETMASK_ADD_DATA
EOF

    elif [ "$1" == "compute1" ] || [ "$1" == "compute2" ]; then
        if [ "$1" == "compute1" ]; then
            COMPUTE_MGNT_IP=$COM1_MGNT_IP
            COMPUTE_EXT_IP=$COM1_EXT_IP
            COMPUTE_DATA_IP=$COM1_DATA_IP

        elif [ "$1" == "compute2" ]; then
            COMPUTE_MGNT_IP=$COM2_MGNT_IP
            COMPUTE_EXT_IP=$COM2_EXT_IP
            COMPUTE_DATA_IP=$COM2_DATA_IP
        fi

        cat << EOF > /etc/network/interfaces

# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

auto $MGNT_INTERFACE
iface $MGNT_INTERFACE inet static
    address $COMPUTE_MGNT_IP
    netmask $NETMASK_ADD_MGNT


# The primary network interface
auto $EXT_INTERFACE
iface $EXT_INTERFACE inet static
    address $COMPUTE_EXT_IP
    netmask $NETMASK_ADD_EXT
    gateway $GATEWAY_IP_EXT
    dns-nameservers $DNS_IP

auto $DATA_INTERFACE
iface $DATA_INTERFACE inet static
    address $COMPUTE_DATA_IP
    netmask $NETMASK_ADD_DATA

EOF

    fi
}

function setup_hostname {
    print_header "Setup /etc/hostname"

    if [ "$1" == "controller" ]; then
        echo "$HOST_CTL" > $path_hostname
    
    elif [ "$1" == "compute1" ]; then
        echo "$HOST_COM1" > $path_hostname

    elif [ "$1" == "compute2" ]; then
        echo "$HOST_COM2" > $path_hostname
    fi

    hostname -F $path_hostname
}

function setup_hosts {
    print_header "Setup /etc/hosts"
    test -f $path_hosts.orig || cp $path_hosts $path_hosts.orig

    if [ "$1" == "controller" ]; then
        HOST_NAME=$HOST_CTL
    elif [ "$1" == "compute1" ]; then
        HOST_NAME=$HOST_COM1
    elif [ "$1" == "compute2" ]; then
        HOST_NAME=$HOST_COM2
    fi

    cat << EOF > $path_hosts
127.0.0.1       localhost $HOST_NAME

# controller
$CTL_MGNT_IP    $HOST_CTL

# compute1
$COM1_MGNT_IP   $HOST_COM1
# compute2
$COM2_MGNT_IP   $HOST_COM2

# block1
$CIN_MGNT_IP    $HOST_CIN

# object1

EOF
}

function add_openstack_repo {
    print_header "Enable the OpenStack Queens repository"
    apt-get install software-properties-common -y
    add-apt-repository cloud-archive:queens -y

    print_install "Upgrade the packages for server"
    apt-get -y update
    apt-get -y upgrade
    apt-get -y dist-upgrade
}

###############################################################################
### Running function
### Checking and help syntax command
if [ $# -ne 1 ]; then
    print_header  "STEP 1: Setup Network"
    echo "Syntax command on"
    echo "    Controller: bash $0 controller"
    echo "    Compute1: bash $0 compute1"
    echo "    Compute2: bash $0 compute2"
    exit 1;
fi

### Pipeline
setup_ip_addr $1
setup_hostname $1
setup_hosts $1
add_openstack_repo

print_success "Reboot Server to continue"
