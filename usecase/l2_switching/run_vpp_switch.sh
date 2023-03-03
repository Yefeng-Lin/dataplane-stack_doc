#!/usr/bin/env bash

# Copyright (c) 2023, Arm Limited.
#
# SPDX-License-Identifier: Apache-2.0

help_func()
{
    echo "Usage: ./run_vpp_switch.sh OPTS [ARGS]"
    echo "where  OPTS := -m L2 switching test via memif interface"
    echo "            := -p L2 switching test via physical NIC"
    echo "            := -c cpu core assignments"
    echo "            := -h help"
    echo "       ARGS := \"-p\" needs two physical NIC interface names, example: -p inputNIC,outputNIC"
    echo "               using \"lshw -c net -businfo\" get interface names"
    echo "            := \"-c\" assign VPP main thread to a CPU core and place worker threads"
    echo "               on isolated CPU cores according to a list of cores, separated by commas"
    echo "               Example: -c main-core,corelist-workers0,corelist-workers1,..."
    echo "Example:"
    echo "  ./run_vpp_switch.sh -m -c 1,2"
    echo "  ./run_vpp_switch.sh -p enP1p1s0f0,enP1p1s0f1 -c 1,2"
    echo
}

loopback()
{
    sudo ${vppctl_binary} -s ${sockfile} create memif socket id 1 filename /tmp/memif-dut-1
    sudo ${vppctl_binary} -s ${sockfile} create int memif id 1 socket-id 1 rx-queues 1 tx-queues 1 master
    sudo ${vppctl_binary} -s ${sockfile} create memif socket id 2 filename /tmp/memif_dut-2
    sudo ${vppctl_binary} -s ${sockfile} create int memif id 1 socket-id 2 rx-queues 1 tx-queues 1 master
    sudo ${vppctl_binary} -s ${sockfile} set interface mac address memif1/1 02:fe:a4:26:ca:f2
    sudo ${vppctl_binary} -s ${sockfile} set interface mac address memif2/1 02:fe:51:75:42:42
    sudo ${vppctl_binary} -s ${sockfile} set int state memif1/1 up
    sudo ${vppctl_binary} -s ${sockfile} set int state memif2/1 up
    sudo ${vppctl_binary} -s ${sockfile} set interface l2 bridge memif1/1 1
    sudo ${vppctl_binary} -s ${sockfile} set interface l2 bridge memif2/1 1
    sudo ${vppctl_binary} -s ${sockfile} l2fib add 00:00:0A:81:0:2 1 memif2/1 static
}

rdma_iface()
{
    echo "Creating RDMA interfaces[1/2]: ${NIC_name[0]}"
    sudo ${vppctl_binary} -s ${sockfile} create interface rdma host-if ${NIC_name[0]} name eth0
    sudo ${vppctl_binary} -s ${sockfile} set interface state eth0 up
    echo "Creating RDMA interfaces[2/2]: ${NIC_name[1]}"
    sudo ${vppctl_binary} -s ${sockfile} create interface rdma host-if ${NIC_name[1]} name eth1
    sudo ${vppctl_binary} -s ${sockfile} set interface state eth1 up
    sudo ${vppctl_binary} -s ${sockfile} set interface l2 bridge eth0 10
    sudo ${vppctl_binary} -s ${sockfile} set interface l2 bridge eth1 10
    sudo ${vppctl_binary} -s ${sockfile} l2fib add 00:00:0a:81:00:02 10 eth1 static
}

export DIR=$(cd "$(dirname "$0")";pwd)
export DATAPLANE_TOP=${DIR}/../..
. "${DATAPLANE_TOP}"/tools/check-path.sh

args="$@"
options=(-o "hmp:c:")
opts=$(getopt ${options[@]} -- $args)
eval set -- "$opts"

while true; do
    case "$1" in
      -h)
          help_func
          exit 0
          ;;
      -m)
          export MEMIF="1"
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
              echo "error: \"-c\" requires cpu isolation core number"
              help_func
              exit 1
          fi
          export MAINCORE=$(echo "$2" | cut -d "," -f 1)
          export WORKLIST=$(echo "$2" | cut -d "," -f 2-)
          if [[ ${MAINCORE} == "$2" ]]; then
              echo "error: \"-c\" option bad usage"
              exit 1
          fi
          shift 2
          ;;
      --)
          shift
          break
          ;;
      *)
          echo "Invalid Option!!"
          help_func
          exit 1
          ;;
    esac
done

if [[ ${MEMIF} && ${PHY_IFACE} ]]; then
    echo "Don't support both -m and -p at the same time!!"
    help_func
    exit 1
fi

if ! [[ ${MEMIF} || ${PHY_IFACE} ]]; then
    echo "Need a option: \"-m\" or \"-p\""
    help_func
    exit 1
fi

if [[ ${PHY_IFACE} && ! ${NIC_name} ]]; then
    echo "error: \"-p\" need two physical NIC interface names: [inputNIC,outputNIC]"
    help_func
    exit 1
fi

if ! [[ ${MAINCORE} && ${WORKLIST} ]]; then
    echo "error: \"-c\" option bad usage"
    help_func
    exit 1
fi

check_vpp
check_vppctl

sockfile="/run/vpp/cli_switch.sock"

sudo ${vpp_binary} unix { cli-listen ${sockfile} }                             \
                   cpu { main-core ${MAINCORE} corelist-workers ${WORKLIST} } \
                   plugins { plugin dpdk_plugin.so { disable } }               \

echo "VPP starting up"
for i in `seq 10`; do
    echo -n "."
    sleep 1
done
echo " "

if [ -n "$MEMIF" ]; then
    echo "Setting memif interfaces..."
    loopback
fi
if [ -n "$PHY_IFACE" ]; then
    echo "Setting rdma host-if..."
    rdma_iface
fi
echo "Done!"
