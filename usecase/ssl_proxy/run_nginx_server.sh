#!/usr/bin/env bash

# Copyright (c) 2023, Arm Limited.
#
# SPDX-License-Identifier: Apache-2.0

#!/usr/bin/env bash

help_func()
{
    echo "Usage: ./run_nginx_server.sh OPTS [ARGS]"
    echo "where  OPTS := -l ssl proxy test via loopback interface"
    echo "            := -p ssl proxy test via physical NIC"
    echo "            := -c set cpu affinity of nginx https server, example: -c 2"
    echo "            := -h help"
    echo "Example:"
    echo "  ./run_nginx_server.sh -l -c 2"
    echo "  ./run_nginx_server.sh -p -c 2"
    echo
}

export DIR=$(cd "$(dirname "$0")";pwd)
export DATAPLANE_TOP=${DIR}/../..
. "${DATAPLANE_TOP}"/tools/check-path.sh

args="$@"
options=(-o "hlp:c:")
opts=$(getopt ${options[@]} -- $args)
eval set -- "$opts"

while true; do
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
      --)
          shift
          break
          ;;
      *)
          echo "Invalid Option!!"
          exit 1
          ;;
    esac
done

if [[ ${LOOPBACK} && ${PHY_IFACE} ]]; then
      echo "Don't support both -l and -p at the same time!!"
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

check_ldp

if [ ${PHY_IFACE} ]; then
    source ${DIR}/setup.sh -k
fi

VCL_SERVER_CONF=vcl_nginx_server.conf
NGINX_SERVER_CONF=nginx_server.conf

echo "=========="
echo "Starting Serevr"
if [ -n "$LOOPBACK" ]; then
    sudo taskset -c ${CORELIST} sh -c "LD_PRELOAD=${LDP_PATH} VCL_CONFIG=${DIR}/${VCL_SERVER_CONF} nginx -c ${DIR}/${NGINX_SERVER_CONF}"
fi
if [ -n "$PHY_IFACE" ]; then
    sudo taskset -c ${CORELIST} sh -c "nginx -c ${DIR}/${NGINX_SERVER_CONF}"
fi
echo "Done!!"