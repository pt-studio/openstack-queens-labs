#!/bin bash

function _network_interfaces() {
    local path_interfaces=/etc/network/interfaces
    local path_interfaces_d=/etc/network/interfaces.d

    test -f $path_interfaces.orig || cp $path_interfaces $path_interfaces.orig

    cat templates/interfaces > $path_interfaces
    mkdir -p $path_interfaces_d

    local MGNT_IP=""
    local EXT_IP=""
    local DATA_IP=""

    if [ "$1" == "controller" ]; then
        MGNT_IP=$COM1_MGNT_IP
        EXT_IP=$COM1_EXT_IP
        DATA_IP=$COM1_DATA_IP

    elif [ "$1" == "compute1" ] || [ "$1" == "compute2" ]; then
        if [ "$1" == "compute1" ]; then
            MGNT_IP=$COM1_MGNT_IP
            EXT_IP=$COM1_EXT_IP
            DATA_IP=$COM1_DATA_IP

        elif [ "$1" == "compute2" ]; then
            MGNT_IP=$COM2_MGNT_IP
            EXT_IP=$COM2_EXT_IP
            DATA_IP=$COM2_DATA_IP
        fi
    fi

    cat << EOF > $path_interfaces_d/openstack.conf
# The Management Network
auto $MGNT_INTERFACE
allow-hotplug $MGNT_INTERFACE
iface $MGNT_INTERFACE inet static
    address $MGNT_IP
    netmask $NETMASK_ADD_MGNT

# The tenant / XVLAN network
auto $DATA_INTERFACE
allow-hotplug $DATA_INTERFACE
iface $DATA_INTERFACE inet static
    address $DATA_IP
    netmask $NETMASK_ADD_DATA

# The provider network
auto $EXT_INTERFACE
allow-hotplug $EXT_INTERFACE
iface $EXT_INTERFACE inet static
    address $EXT_IP
    netmask $NETMASK_ADD_EXT
    gateway $GATEWAY_IP_EXT
    dns-nameservers $DNS_IP

EOF
}

function _netplan_interfaces {
}

function setup_ip_addr {
    print_header "Setup interfaces"
    if [[ `lsb_release -rs` == "16.04" ]]; then
        _network_interfaces $1
    elif [[ `lsb_release -rs` == "18.04" ]]; then
        _netplan_interfaces $1
    else
        echo 'OS not suppported'
        exit 1
    fi
}

function setup_hostname {
    local path_hostname=/etc/hostname

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
    local path_hosts=/etc/hosts

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
$CTL_MGNT_IP    $MGNT_FQDN_CTL

# compute1
$COM1_MGNT_IP   $MGNT_FQDN_COM1
# compute2
$COM2_MGNT_IP   $MGNT_FQDN_COM2

# block1
$CIN_MGNT_IP    $MGNT_FQDN_CIN1

# object1

EOF
}
