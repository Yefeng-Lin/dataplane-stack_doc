#!/usr/bin/env bash

# Copyright (c) 2023, Arm Limited.
#
# SPDX-License-Identifier: Apache-2.0

#!/usr/bin/env bash

help_func()
{
    echo "Usage: ./run_server.sh OPTS [ARGS]"
    echo "where  OPTS := -l ssl proxy test via loopback interface"
    echo "            := -p ssl proxy test via physical NIC"
    echo "            := -c set cpu affinity of iperf3 server"
    echo "            := -h help"
    echo "       ARGS := \"-c\" need cpu isolation core number, example: -c 2"
    echo "Example:"
    echo "  ./run_server.sh -l -c 2"
    echo "  ./run_server.sh -p -c 2"
    echo
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
          export PHY_IFACE="1"
          shift 1
          ;;
      -c)
          if [ "$#" -lt "2" ]; then
              echo "error: \"-c\" requires isolate cpu core"
              help_func
              exit 1
          fi
          export CORELIST="$2"
          shift 2
          ;;

      *)
          echo "Invalid Option!!"
          exit 1
          ;;
    esac
done
if [ ${PHY_IFACE} ]; then
    source ${DIR}/setup.sh -p
fi

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

if ! [ ${CORELIST} ]; then
      echo "error: \"-c\" option bad usage"
      help_func
      exit 1
fi

if ! [ ${LDP_PATH} ]; then
    echo "User don't specify the library path"
    echo "Try to find the proper paths..."
    LDP_PATH=$(ls ${DIR}/../../components/vpp/build-root/install-vpp-native/vpp/lib/aarch64-linux-gnu/libvcl_ldpreload.so)
    LDP_PATH=${LDP_PATH:-"/usr/lib/libvcl_ldpreload.so"}
else
    echo "Validate user-specified paths..."
fi

if ! [ -e ${LDP_PATH} ]; then
    echo "Can't find VPP's library"
    exit 1
fi

echo "Found VPP's library at: $(ls ${LDP_PATH})"

if [ ${PHY_IFACE} ]; then
    source ${DIR}/setup.sh -p
fi

VCL_SERVER_CONF=vcl_nginx.conf
NGINX_SERVER_CONF=nginx_server.conf

echo "=========="
echo "Starting Serevr"
if [ -n "$LOOPBACK" ]; then
    sudo taskset -c ${CORELIST} sh -c "LD_PRELOAD=${PRLOAD_PATH} VCL_CONFIG=${DIR}/${VCL_SERVER_CONF} nginx -c /etc/nginx/${NGINX_SERVER_CONF}"
fi
if [ -n "$PHY_IFACE" ]; then
    sudo taskset -c ${CORELIST} sh -c "nginx -c /etc/nginx/${NGINX_SERVER_CONF}"
fi
echo "Done!!"
