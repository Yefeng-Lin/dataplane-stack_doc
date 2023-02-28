#!/usr/bin/env bash

DIR=$(cd "$(dirname "$0")";pwd)

CORE_LIST=${CORE_LIST:-2}

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
      *)
          echo "Invalid Option!!"
          exit 1
          ;;
    esac
done

if [ -e "$(ls /usr/lib/libvcl_ldpreload.so.*)" ]; then
    PRLOAD_PATH=$(ls /usr/lib/libvcl_ldpreload.so.*)
else
    PRLOAD_PATH=$(ls ${DIR}/../../components/vpp/build-root/install-vpp-native/vpp/lib/aarch64-linux-gnu/libvcl_ldpreload.so.*)
fi

VCL_SERVER_CONF=vcl_nginx.conf
NGINX_SERVER_CONF=nginx.server.conf

sudo taskset -c ${CORE_LIST} sh -c "LD_PRELOAD=${PRLOAD_PATH} VCL_CONFIG=${DIR}/${VCL_SERVER_CONF} nginx -c /etc/nginx/${NGINX_SERVER_CONF}"
