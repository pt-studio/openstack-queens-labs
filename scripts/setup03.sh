#!/bin/bash
# Print the commands being run so that we can see the command that triggers
# an error.  It is also useful for following along as the install occurs.
set -o xtrace
set -e

###############################################################################
## Init environment source
TOP_DIR=$(cd $(dirname "$0") && pwd)
source $TOP_DIR/out/vars
source $TOP_DIR/lib/functions.sh

### Running function
### Checking and help syntax command
if [ $# -ne 1 ]; then
    echocolor  "STEP 3: Install OpenStack service"
    echo "Syntax command on"
    echo "    Controller: bash $0 controller"
    echo "    Compute{{N}}: bash $0 compute{{N}}"
    echo "    Block{{N}}: bash $0 block{{N}}"
    exit 1;
fi

if [ "$1" == "controller" ]; then
    source $TOP_DIR/install/01_keystone.sh
    source $TOP_DIR/install/02_glance.sh
    source $TOP_DIR/install/03_nova.sh
    source $TOP_DIR/install/04_neutron.sh
    source $TOP_DIR/install/05_horizon.sh

    install_keystone
    install_glance
    install_nova $1
    install_neutron $1

    install_horizon

elif [ "$1" == "compute1" ] || [ "$1" == "compute2" ]; then
    source $TOP_DIR/admin-openrc
    source $TOP_DIR/install/03_nova.sh
    source $TOP_DIR/install/04_neutron.sh

    install_nova $1
    install_neutron $1

fi
