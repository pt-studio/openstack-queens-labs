#!/bin/bash

###############################################################################
## Init enviroiment source
dir_path=$(dirname $0)
source $dir_path/config.cfg
source $dir_path/lib/functions.sh
source $dir_path/admin-openrc

### Running function
### Checking and help syntax command
if [ $# -ne 1 ]; then
    echocolor  "STEP 3: Install OpenStack service"
    echo "Syntax command on"
    echo "    Controller: bash $0 controller"
    echo "    Compute1: bash $0 compute1"
    echo "    Compute2: bash $0 compute2"
    exit 1;
fi

if [ "$1" == "controller" ]; then
    ./$dir_path/install/install_keystone.sh
    ./$dir_path/install/install_glance.sh

    ./$dir_path/install/install_nova.sh $1
    ./$dir_path/install/install_neutron.sh $1

    ./$dir_path/install/install_horizon.sh

elif [ "$1" == "compute1" ] || [ "$1" == "compute2" ]; then
    ./$dir_path/install/install_nova.sh $1
    ./$dir_path/install/install_neutron.sh $1

fi
