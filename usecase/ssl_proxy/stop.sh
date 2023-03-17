#!/usr/bin/env bash

# Copyright (c) 2023, Arm Limited.
#
# SPDX-License-Identifier: Apache-2.0

echo "release VPP instance and nginx proxy & server..."
sudo pkill -9 vpp
sudo pkill -9 nginx
