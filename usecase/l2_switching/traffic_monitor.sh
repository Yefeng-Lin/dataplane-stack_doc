#!/usr/bin/env bash

# Copyright (c) 2023, Arm Limited.
#
# SPDX-License-Identifier: Apache-2.0

help_func()
{
    echo "Usage: ./traffic_monitor.sh"
    echo
}

DIR=$(cd "$(dirname "$0")";pwd)
export DATAPLANE_TOP=${DIR}/../..
. "${DATAPLANE_TOP}"/tools/check-path.sh

while [ "$#" -gt "0" ]; do
    case "$1" in
      -h)
        help_func
	exit 0
	;;
      *)
        echo "Invalid Option!!"
	help_func
	exit 1
	;;
    esac
done

check_vpp
check_vppctl

sockfile="/run/vpp/cli_switch.sock"

sudo ${vppctl_binary} -s ${sockfile} clear interfaces
echo "letting VPP switch packets for 3 seconds"
for i in `seq 3`; do
    echo -n "..$i"
    sleep 1
done

echo " "
echo " "
echo "=========="
sudo ${vppctl_binary} -s ${sockfile} show interface
