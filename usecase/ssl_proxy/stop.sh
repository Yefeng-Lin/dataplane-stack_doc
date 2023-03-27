#!/usr/bin/env bash

# Copyright (c) 2023, Arm Limited.
#
# SPDX-License-Identifier: Apache-2.0

echo "Stop VPP instance, nginx proxy & server..."
sudo pkill -9 vpp
sudo pkill -9 nginx
