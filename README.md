# OpenStack Queens LAB

## Topology

![topo](./images/topo.png)

![requirement_hardware](./images/requirement_hardware.png)

## ALL node

- Download git & scripts

```sh
apt-get -y update && apt-get -y install git-core
git clone https://github.com/congto/OpenStack-Newton-Scripts.git /root/openstack
cd /root/openstack/scripts
chmod -R +x *.sh
```

- You can edit `config.cfg` file if needed

## Controller

- SSH with `root` account and run scripts

```sh
./setup01.sh controller
./setup02.sh controller
./setup03.sh controller
```

## Compute1 to ComputeN

- SSH with `root` account and run scripts

```sh
./setup01.sh compute1
./setup02.sh compute1
./setup03.sh compute1
```

## Create network, VM

- On Controller node, run

```sh
./create-vm.sh
```

## Login dashboad

- Dashboard: `192.168.81.30/horizon`
- User : `admin/Welcome123`

## Check

### Check by command or dashboard

![console](./images/img1.png)
![web](./images/img2.png)

## Credit


