#!/usr/bin/env bash

# Copyright (c) 2022, Arm Limited.
#
# SPDX-License-Identifier: Apache-2.0

#set -ex

help_func()
{
    echo
    echo "Usage: ./run_dut.sh OPTS [ARGS]"
    echo "where  OPTS := -l ssl proxy test via loopback interface"
    echo "            := -p ssl proxy test via physical NIC"
    echo "            := -c assign VPP main thread to a cpu isolation core"
    echo "            := -h help"
    echo "       ARGS := \"-p\" need two physical NIC interface names, example: -p inputNIC,outputNIC"
    echo "               using \"lshw -c net -businfo\" get interface names"
    echo "            := \"-c\" need a cpu isolation core number, example: -c 1"
    echo "Example:"
    echo "  ./run_dut.sh -l -c 1"
    echo "  ./run_dut.sh -p enp1s0f0np0,enp1s0f0np1 -c 1"
    echo
}

loopback()
{
    sudo ${vppctl_binary} -s ${sockfile} create loopback interface 
    sudo ${vppctl_binary} -s ${sockfile} set interface mtu packet 1500 loop0
    sudo ${vppctl_binary} -s ${sockfile} set interface state loop0 up
    sudo ${vppctl_binary} -s ${sockfile} create loopback interface
    sudo ${vppctl_binary} -s ${sockfile} set interface mtu packet 1500 loop1
    sudo ${vppctl_binary} -s ${sockfile} set interface state loop1 up
    sudo ${vppctl_binary} -s ${sockfile} create loopback interface
    sudo ${vppctl_binary} -s ${sockfile} set interface mtu packet 1500 loop2
    sudo ${vppctl_binary} -s ${sockfile} set interface state loop2 up
    sudo ${vppctl_binary} -s ${sockfile} ip table add 1
    sudo ${vppctl_binary} -s ${sockfile} set interface ip table loop0 1
    sudo ${vppctl_binary} -s ${sockfile} ip table add 2
    sudo ${vppctl_binary} -s ${sockfile} set interface ip table loop1 2
    sudo ${vppctl_binary} -s ${sockfile} ip table add 3 
    sudo ${vppctl_binary} -s ${sockfile} set interface ip table loop2 3
    sudo ${vppctl_binary} -s ${sockfile} set interface ip address loop0 172.16.1.1/24
    sudo ${vppctl_binary} -s ${sockfile} set interface ip address loop1 172.16.2.1/24
    sudo ${vppctl_binary} -s ${sockfile} set interface ip address loop2 172.16.3.1/24
    sudo ${vppctl_binary} -s ${sockfile} app ns add id nginx secret 1234 sw_if_index 1
    sudo ${vppctl_binary} -s ${sockfile} app ns add id proxy secret 1234 sw_if_index 2
    sudo ${vppctl_binary} -s ${sockfile} app ns add id client secret 1234 sw_if_index 3
    sudo ${vppctl_binary} -s ${sockfile} ip route add 172.16.1.1/32 table 2 via lookup in table 1
    sudo ${vppctl_binary} -s ${sockfile} ip route add 172.16.3.1/32 table 2 via lookup in table 3
    sudo ${vppctl_binary} -s ${sockfile} ip route add 172.16.2.1/32 table 1 via lookup in table 2
    sudo ${vppctl_binary} -s ${sockfile} ip route add 172.16.2.1/32 table 3 via lookup in table 2
}

btw_network()
{
    echo "Creating RDMA interfaces[1/2]: ${NIC_name[0]}"
    sudo ${vppctl_binary} -s ${sockfile} create interface rdma host-if ${NIC_name[0]} name eth0
    sudo ${vppctl_binary} -s ${sockfile} set interface ip address eth0 172.16.1.2/24
    sudo ${vppctl_binary} -s ${sockfile} set interface state eth0 up
    echo "Creating RDMA interfaces[2/2]: ${NIC_name[1]}"
    sudo ${vppctl_binary} -s ${sockfile} create interface rdma host-if ${NIC_name[1]} name eth1
    sudo ${vppctl_binary} -s ${sockfile} set interface ip address eth1 172.16.2.1/24
    sudo ${vppctl_binary} -s ${sockfile} set interface state eth1 up
    sudo ${vppctl_binary} -s ${sockfile} ip table add 1
    sudo ${vppctl_binary} -s ${sockfile} set interface ip table eth0 1
    sudo ${vppctl_binary} -s ${sockfile} ip table add 2
    sudo ${vppctl_binary} -s ${sockfile} set interface ip table eth1 2
    sudo ${vppctl_binary} -s ${sockfile} app ns add id nginx secret 1234 sw_if_index 1
    sudo ${vppctl_binary} -s ${sockfile} app ns add id proxy secret 1234 sw_if_index 2
    sudo ${vppctl_binary} -s ${sockfile} ip route add 172.16.2.1/32 table 2 via lookup in table 1
    sudo ${vppctl_binary} -s ${sockfile} ip route add 172.16.1.1/32 table 1 via lookup in table 2
}

DIR=$(cd "$(dirname "$0")";pwd)

while [ $# -gt 0 ]; do
    case "$1" in
      --help | -h)
          help_func
	  exit 0
	  ;;
      -l)
          export LOOPBACK="1"
	  shift 1
	  ;;
      -p)
          if [ "$#" -lt "2" ]; then
              echo "error: \"-p\" requires two physical NIC interfaces name"
              help_func
	      exit 1
          fi
          export PHY_IFACE="1"
	  export NIC_name
          NIC_name[0]=$(echo "$2" | cut -d "," -f 1)
          NIC_name[1]=$(echo "$2" | cut -d "," -f 2)
          if [[ ${NIC_name[0]} == "$2" ]]; then
              echo "error: \"-p\" option bad usage"
              exit 1
          fi
	  shift 2
	  ;;
      -c)
          if [ "$#" -lt "2" ]; then
              echo "error: \"-c\" requires a cpu isolation core number"
	      help_func
	      exit 1
	  fi
	  export MAINCORE="$2"
	  shift 2
	  ;;
      *)
	  echo "Invalid Option!!"
	  exit 1
	  ;;
    esac
done

if [[ ${LOOPBACK} && ${PHY_IFACE} ]]; then
    echo "Don't support set both -l and -p at the same time!!"
    help_func
    exit 1
fi

if ! [[ ${LOOPBACK} || ${PHY_IFACE} ]]; then
    echo "Need a option: \"-l\" or \"-p\""
    help_func
    exit 1
fi

if [[ ${PHY_IFACE} && ! ${NIC_name} ]]; then
    echo "error: \"-p\" need two physical NIC interface names: [inputNIC,outputNIC]"
    help_func
    exit 1
fi

if ! [ ${MAINCORE} ]; then
    echo "error: \"-c\" option must be set"
    help_func
    exit 1
fi

if ! [[ $(command -v $vpp_binary) && $(command -v $vppctl_binary) ]]; then
    echo "User don't specify the VPP or VPPCTL binary paths"
    echo "Try to find the proper paths..."
    vpp_binary=$(command -v "${DIR}/../../components/vpp/build-root/install-vpp-native/vpp/bin/vpp")
    vppctl_binary=$(command -v "${DIR}/../../components/vpp/build-root/install-vpp-native/vpp/bin/vppctl")
    vpp_binary=${vpp_binary:-vpp}
    vppctl_binary=${vppctl_binary:-vppctl}
else
    echo "Validate user-specified paths..."
fi

if ! [ $(command -v $vpp_binary) ]; then
    echo
    echo "Can't find vpp!!"
    exit 1
fi

if ! [ $(command -v $vppctl_binary) ]; then
    echo
    echo "Can't find vppctl!!"
    exit 1
fi

echo "Found VPP binary at: $(command -v ${vpp_binary})"
echo "Found VPPCTL binary at: $(command -v ${vppctl_binary})"

source setup.sh
sockfile="/run/vpp/cli-master.sock"
 
sudo ${vpp_binary} unix { cli-listen ${sockfile} }                   \
                  cpu { main-core ${MAINCORE} workers 0 } \
		  tcp { cc-algo cubic }                             \
		  plugins { plugin dpdk_plugin.so { disable } }     \
		  session { enable use-app-socket-api }             \
 
echo "VPP starting up"
for i in `seq 10`; do
    echo -n "."
    sleep 1
done
echo " "

if [ -n "$LOOPBACK" ]; then
    echo "Setting loopback interfaces..."
    loopback
fi
if [ -n "$PHY_IFACE" ]; then
    echo "Setting rdma host-if..."
    btw_network    
fi

echo "Done!!"
