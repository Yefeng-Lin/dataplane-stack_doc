#!/usr/bin/env bash

# Copyright (c) 2023, Arm Limited.
#
# SPDX-License-Identifier: Apache-2.0

#kill vpp
echo "Stop traffic and release switch & traffic_generator instances..."
sudo pkill -9 vpp
