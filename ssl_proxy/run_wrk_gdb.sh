#!/usr/bin/env bash


DIR=$(cd "$(dirname "$0")";pwd)

CORE_LIST=${CORE_LIST:-4}

if [ -e "$(ls /usr/lib/libvcl_ldpreload.so.*)" ]; then
      PRLOAD_PATH=$(ls /usr/lib/libvcl_ldpreload.so.*)
  else
      PRLOAD_PATH=$(ls ${DIR}/../../components/vpp/build-root/install-vpp_debug-native/vpp/lib/aarch64-linux-gnu/libvcl_ldpreload.so.*)
  fi

VCL_WRK_CONF=vcl_wrk.conf

SIZE_ARR=("1kb" "5kb" "10kb" "100kb")

#  sudo taskset -c ${CORE_LIST} sh -c "LD_PRELOAD=${PRLOAD_PATH} VCL_CONFIG=${DIR}/${VCL_WRK_CONF} ../../../wrk2-aarch64/wrk --rate 100000000 -t 1 -c 10 -d 2s http://172.16.2.1:8089/${e}"
#for e in ${SIZE_ARR[@]}
#do
  sudo gdbserver --wrapper env LD_PRELOAD=${PRLOAD_PATH} VCL_CONFIG=${DIR}/${VCL_WRK_CONF} -- :4321 ../../../wrk2-aarch64/wrk --rate 100000000 -t 2 -c 2 -d 10s http://172.16.2.1:8089/1kb
#done
