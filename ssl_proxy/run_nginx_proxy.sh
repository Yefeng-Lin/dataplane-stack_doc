#!/usr/bin/env bash

# Copyright (c) 2023, Arm Limited.
#
# SPDX-License-Identifier: Apache-2.0

#!/usr/bin/env bash

help_func()
{
    echo "Usage: ./run_proxy.sh OPTS [ARGS]"
    echo "where  OPTS := -c set cpu affinity of iperf3 client"
    echo "            := -h help"
    echo "       ARGS := \"-c\" need cpu isolation core number, example: -c 3"
    echo "Example:"
    echo "  ./run_proxy.sh -c 3"
    echo
}

DIR=$(cd "$(dirname "$0")";pwd)

while [ $# -gt 0 ]; do
    case "$1" in
      --help | -h)
          help_func
          exit 0
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

VCL_PROXY_CONF=vcl_nginx_proxy.conf
NGINX_PROXY_CONF=nginx_proxy.conf

echo "=========="
echo "Starting Proxy"
sudo taskset -c ${CORELIST} sh -c "LD_PRELOAD=${LDP_PATH} VCL_CONFIG=${DIR}/${VCL_PROXY_CONF} nginx -c /etc/nginx/${NGINX_PROXY_CONF}"
echo "Done!!"
