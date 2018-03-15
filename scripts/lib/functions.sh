#!/bin/bash -ex

function print_install {
    echo -e "\e[34m$1 \e[0m"
}

function print_header {
    echo -e "\e[44m> $1 \e[0m"
}

function print_success {
    echo -e "\e[42m$1 \e[0m"
}

function echocolor {
    echo -e "\e[93m$1 \e[0m"
}


# Ham sua file cau hinh cua OpenStack
function ops_edit {
    crudini --set $1 $2 $3 $4
}

# Cach dung
## Cu phap:
##			ops_edit_file $bien_duong_dan_file [SECTION] [PARAMETER] [VALUAE]
## Vi du:
###			filekeystone=/etc/keystone/keystone.conf
###			ops_edit_file $filekeystone DEFAULT rpc_backend rabbit


# Ham de del mot dong trong file cau hinh
function ops_del {
    crudini --del $1 $2 $3
}
