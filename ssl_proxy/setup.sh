#!/usr/bin/env bash

# Copyright (c) 2023, Arm Limited.
#
# SPDX-License-Identifier: Apache-2.0

help_func()
{
    echo
    echo "Usage: ./setup.sh OPTS"
    echo "where  OPTS := -k setup nginx server via physical NIC"
    echo "               other cases, do not set this option"
    echo "            := -h help"
    echo "Example:"
    echo "  ./setup.sh"
    echo "  ./setup.sh -k"
    echo
}

DIR=$(cd "$(dirname "$0")";pwd)
wrk_binary=${DIR}/../../wrk2-aarch64/wrk

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

if ! [ $(command -v $wrk_binary) ]; then
      cd ${DIR}/../../components
      git clone https://github.com/AmpereTravis/wrk2-aarch64.git
      cd wrk2-aarch64
      git am ${DIR}/../../patches/wrk2/0001-wrk2-fd-vpp.patch
      make all > /dev/null 2>&1
fi

if [ $(command -v $wrk_binary) ]; then
    echo "wrk2 build succeeded."
fi

sudo mkdir -p /etc/nginx/certs
if ! [[ -e /etc/nginx/certs/server.key && -e /etc/nginx/certs/server.crt ]]; then
        echo "Creating ssl server's private keys and cerfificatesi..."
        sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/nginx/certs/server.key -out /etc/nginx/certs/server.crt
fi

if ! [ ${PHY_IFACE} ]; then
      if ! [[ -e /etc/nginx/certs/proxy.key && -e /etc/nginx/certs/proxy.crt ]]; then
              echo "Creating ssl proxy's private keys and cerfificatesi..."
              sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/nginx/certs/proxy.key -out /etc/nginx/certs/proxy.crt
      fi
fi

echo "$(ls /etc/nginx/certs/server.key)"
echo "$(ls /etc/nginx/certs/server.crt)"
if ! [ ${PHY_IFACE} ]; then
      echo "$(ls /etc/nginx/certs/proxy.key)"
      echo "$(ls /etc/nginx/certs/proxy.crt)"
fi

sudo mkdir -p /var/www/html

if ! [ -e /var/www/html/1kb ]; then
      echo "Creating 1kb load file"
      sudo dd if=/dev/urandom of=/var/www/html/1kb bs=1024 count=1
      echo "$(ls /var/www/html/1kb)"
fi
echo
echo "Setup completed!"
