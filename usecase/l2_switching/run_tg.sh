#!/usr/bin/env bash

# Copyright (c) 2023, Arm Limited.
#
# SPDX-License-Identifier: Apache-2.0

help_func()
{
    echo "Usage: ./run_tg.sh OPTS [ARGS]"
    echo "where OPTS := -c cpu core assignments"
    echo "           := -h help"
    echo "      ARGS := \"-c\" assign VPP main thread to a CPU core and place worker threads"
    echo "              on isolated CPU cores according to a list of cores, separated by commas"
    echo "              Example: -c main-core,corelist-workers0,corelist-workers1,..."
    echo "Example:"
    echo "  ./run_tg.sh -c 3,4"
    echo
}

export DIR=$(cd "$(dirname "$0")";pwd)
export DATAPLANE_TOP=${DIR}/../..
. "${DATAPLANE_TOP}"/tools/check-path.sh

args="$@" 
options=(-o "hc:")
opts=$(getopt ${options[@]} -- $args)
eval set -- "$opts"

while true; do
    case "$1" in
      -h)
        help_func
        exit 0
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

if ! [[ ${MAINCORE} && ${WORKLIST} ]]; then
      echo "error: \"-c\" option bad usage"
      help_func
      exit 1
fi

check_vpp
check_vppctl

sockfile="/run/vpp/cli_tg.sock"

sudo ${vpp_binary} unix { cli-listen ${sockfile} }                             \
                   cpu { main-core ${MAINCORE} corelist-workers ${WORKLIST} } \
                   plugins { plugin dpdk_plugin.so { disable } }               \

echo "VPP starting up"
for i in `seq 10`; do
    echo -n "."
    sleep 1
done
echo " "

sudo ${vppctl_binary} -s ${sockfile} create memif socket id 1 filename /tmp/memif-dut-1
sudo ${vppctl_binary} -s ${sockfile} create int memif id 1 socket-id 1 rx-queues 1 tx-queues 1 slave
sudo ${vppctl_binary} -s ${sockfile} create memif socket id 2 filename /tmp/memif_dut-2
sudo ${vppctl_binary} -s ${sockfile} create int memif id 1 socket-id 2 rx-queues 1 tx-queues 1 slave
sudo ${vppctl_binary} -s ${sockfile} set interface mac address memif1/1 02:fe:a4:26:ca:ac
sudo ${vppctl_binary} -s ${sockfile} set interface mac address memif2/1 02:fe:51:75:42:ed
sudo ${vppctl_binary} -s ${sockfile} set int state memif1/1 up
sudo ${vppctl_binary} -s ${sockfile} set int state memif2/1 up
sudo ${vppctl_binary} -s ${sockfile} \
'packet-generator new {     \
  name tg0                  \
  limit -1                  \
  size 64-64                \
  node memif1/1-output      \
  tx-interface memif1/1     \
  data {                    \
      IP4: 00:00:0a:81:00:01 -> 00:00:0a:81:00:02  \
      UDP: 192.81.0.1  -> 192.81.0.2           \
      UDP: 1234 -> 2345     \
      incrementing 8        \
  }                         \
}'


echo "Traffic generator starting up"
for i in `seq 5`; do
    echo -n ".."
    sleep 1
done
echo " "

sudo ${vppctl_binary} -s  ${sockfile} packet-generator enable-stream tg0

echo "Done!"
