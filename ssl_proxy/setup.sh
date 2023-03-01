#!/usr/bin/env bash

# Copyright (c) 2023, Arm Limited.
#
# SPDX-License-Identifier: Apache-2.0

help_func()
{
    echo
    echo "Usage: ./setup.sh OPTS"
    echo "where  OPTS := -k setup nginx server via physical NIC"
    echo "               other cases, do not set option"
    echo "            := -h help"
    echo "Example:"
    echo "  ./run_dut.sh"
    echo "  ./run_dut.sh -k"
    echo
}

DIR=$(cd "$(dirname "$0")";pwd)
wrk_dir=${DIR}/../../wrk2-aarch64

while [ $# -gt 0 ]; do
    case "$1" in
       -h)
           help_func
	   exit 1
	   ;;
       -k)
           PHY_IFACE=1
	   shift 1
	   ;;
       *)
           echo "Invalid Option!!"
           exit 1
           ;;
    esac
done

if [ ! -d ${wrk_dir} ]; then
    cd ${DIR}/../../
    git clone https://github.com/AmpereTravis/wrk2-aarch64.git
    cd wrk2-aarch64
    git am ${DIR}/../../patches/ssl_proxy/0001-Modify-max-number-of-file-descriptors-tracked-to-run.patch
    make all
fi

echo "Creating ssl private keys and cerfificatesi..."
sudo mkdir -p /etc/nginx/certs
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/nginx/certs/server.key -out /etc/nginx/certs/server.crt
if ! [ ${PHY_IFACE} ]; then
      sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/nginx/certs/proxy.key -out /etc/nginx/certs/proxy.crt
fi

echo "$(ls /etc/nginx/certs/server.key)"
echo "$(ls /etc/nginx/certs/server.crt)"
if ! [ ${PHY_IFACE} ]; then
      echo "$(ls /etc/nginx/certs/proxy.key)"
      echo "$(ls /etc/nginx/certs/proxy.crt)"
fi

sudo mkdir -p /var/www/html

echo "Creating loads"
echo "...1kb"
sudo dd if=/dev/urandom of=/var/www/html/1kb bs=1024 count=1
echo
echo "Setup completed!"
