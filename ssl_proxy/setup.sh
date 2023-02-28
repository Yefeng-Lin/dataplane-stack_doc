#!/usr/bin/env bash

# Copyright (c) 2023, Arm Limited.
#
# SPDX-License-Identifier: Apache-2.0

$# && export PHY_IFACE=1

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
echo "Done!!"
