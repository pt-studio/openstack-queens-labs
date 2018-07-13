#!/bin/bash
# Print the commands being run so that we can see the command that triggers
# an error.  It is also useful for following along as the install occurs.
set -o xtrace

###############################################################################
## Init environment source
TOP_DIR=$(cd $(dirname "$0") && pwd)
source $TOP_DIR/lib/functions.sh
source $TOP_DIR/lib/network.sh

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

print_success "Reboot Server to continue"
