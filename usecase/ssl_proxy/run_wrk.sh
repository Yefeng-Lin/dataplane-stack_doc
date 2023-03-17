#!/usr/bin/env bash

# Copyright (c) 2023, Arm Limited.
#
# SPDX-License-Identifier: Apache-2.0

#!/usr/bin/env bash

set -e

export DIR
export DATAPLANE_TOP
export LOOP_BACK
export PHY_IFACE
export MAINCORE

help_func()
{
    echo "Usage: ./run_wrk.sh OPTS [ARGS]"
    echo "where  OPTS := -l ssl proxy test via loopback interface"
    echo "            := -p ssl proxy test via physical NIC"
    echo "            := -c isolate cpu core, example: -c 4"
    echo "            := -h help"
    echo "Example:"
    echo "  ./run_wrk.sh -l -c 4"
    echo "  ./run_wrk.sh -p -c 4"
    echo
}
 
DIR=$(cd "$(dirname "$0")" || exit 1 ;pwd)
DATAPLANE_TOP=${DIR}/../..
# shellcheck source=../../tools/check-path.sh
. "${DATAPLANE_TOP}"/tools/check-path.sh
wrk_binary=${DATAPLANE_TOP}/components/wrk2-aarch64/wrk

options=(-o "hlp:c:")
opts=$(getopt "${options[@]}" -- "$@")
eval set -- "$opts"

while true; do
    case "$1" in
      --help | -h)
          help_func
          exit 0
          ;;
      -l)
          export LOOP_BACK="1"
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
          export MAINCORE="$2"
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
 
if [[ ${LOOP_BACK} && ${PHY_IFACE} ]]; then
      echo "Don't support both -l and -p at the same time!!"
      help_func
      exit 1
fi
 
if ! [[ ${LOOP_BACK} || ${PHY_IFACE} ]]; then
      echo "Need a option: \"-l\" or \"-p\""
      help_func
      exit 1
fi
 
if ! [[ ${MAINCORE} ]]; then
      echo "error: \"-c\" option must be set"
      help_func
      exit 1
fi

check_ldp

if ! [[ $(command -v "${wrk_binary}") ]]; then
      echo "wrk2 building..."
      cd "${DIR}"/../../components
      git clone https://github.com/AmpereTravis/wrk2-aarch64.git
      cd wrk2-aarch64
      git am "${DIR}"/../../patches/wrk2/0001-wrk2-fd-vpp.patch
      make all > /dev/null 2>&1
fi

echo "Found wrk2 at: $(command -v "${wrk_binary}")"

echo "=========="
echo "Starting wrk2 test..."

VCL_WRK_CONF=vcl_wrk2.conf
if [ -n "$LOOP_BACK" ]; then
    sudo taskset -c "${MAINCORE}" sh -c "LD_PRELOAD=${LDP_PATH} VCL_CONFIG=${DIR}/${VCL_WRK_CONF} ${DATAPLANE_TOP}/components/wrk2-aarch64/wrk --rate 100000000 -t 1 -c 10 -d 10s https://172.16.2.1:8089/1kb"
fi

if [ -n "$PHY_IFACE" ]; then
    sudo taskset -c "${MAINCORE}" sh -c "${wrk_binary} --rate 100000000 -t 1 -c 10 -d 10s https://172.16.2.1:8089/1kb"
fi

echo ""
echo "Done!!"
