..
  # Copyright (c) 2022, Arm Limited.
  #
  # SPDX-License-Identifier: Apache-2.0

################
VPP L2 Switching
################

************
Introduction
************

VPP L2 Switching implements the typical switching function based on 48-bit MAC
address. It forwards packets based on the l2fib table. Below L2 features are supported:

- Forwarding
- Mac Learning
- Flooding

The l2fib table starts out empty, and there are two ways to create l2fib table:

Learning
~~~~~~~~

When VPP receives something, it takes a look at the Source MAC address field of the incoming frame. 
It uses the Source MAC and the interface the frame was received on to build an entry in the l2fib table.

Flooding
~~~~~~~~

The very cause of flooding is that destination MAC address of the packet is not in the l2fib table.
In this case the frame will be flooded out of all interfaces. All connected device will receive the frame.
The intended device will response back to the VPP and allow build an entry in l2fib table.

The above is the dynamic way. In the static option, add the MAC addresses in the l2fib table manually.
This guide explains in detail on how to use the VPP based L2 switching cases, and manually add l2fib table entry.

**********
Test Setup
**********

.. figure:: ../images/vpp-switching.png
   :align: center
   :width: 400

VPP switching supports DPDK interface, RDMA interface, MEMIF interface, and VETH interface.
As shown in above diagram, this guide will demonstrate memif interace and RDMA
interface cases for L2 switching. VPP switch instance can have two MEMIF connections
to another VPP instance as traffic generator on same DUT, or two RDMA NIC connections
to an external traffic generator.

****************
MEMIF connection
****************

Setup
~~~~~

The setup section will create a network topology as:

.. figure:: ../images/l2_switching_memif.png
   :align: center
   :width: 400

Start VPP as a daemon with config parameters::

        $ sudo /path/to/vpp unix {cli-listen /run/vpp/cli-dut.sock} cpu {main-core 0 corelist-workers 1}

.. note::
        For DUT with dataplane stack repo, vpp binary path is components/vpp/build-root/install-vpp-native/vpp/bin/vpp.

        For DUT with vpp package installed only (e.g., Arm FVP and FPGA), find vpp path by "which vpp".

Define variable to hold the VPP cli listen socket specified in above step::

        $ export sockfile=/run/vpp/cli-dut.sock

Add following VPP commands to create memif interfaces and associate interfaces with a bridge domain::

        sudo /path/to/vppctl -s ${sockfile} create memif socket id 1 filename /tmp/memif-dut-1
        sudo /path/to/vppctl -s ${sockfile} create int memif id 1 socket-id 1 rx-queues 1 tx-queues 1 master
        sudo /path/to/vppctl -s ${sockfile} create memif socket id 2 filename /tmp/memif-dut-2
        sudo /path/to/vppctl -s ${sockfile} create int memif id 1 socket-id 2 rx-queues 1 tx-queues 1 master
        sudo /path/to/vppctl -s ${sockfile} set interface mac address memif1/1 02:fe:a4:26:ca:f2
        sudo /path/to/vppctl -s ${sockfile} set interface mac address memif2/1 02:fe:51:75:42:42
        sudo /path/to/vppctl -s ${sockfile} set int state memif1/1 up
        sudo /path/to/vppctl -s ${sockfile} set int state memif2/1 up
        sudo /path/to/vppctl -s ${sockfile} set interface l2 bridge memif1/1 10
        sudo /path/to/vppctl -s ${sockfile} set interface l2 bridge memif2/1 10
        sudo /path/to/vppctl -s ${sockfile} l2fib add 00:00:0A:81:0:2 10 memif2/1 static

.. note::
        For DUT with dataplane stack repo, vppctl binary path is components/vpp/build-root/install-vpp-native/vpp/bin/vppctl.

        For DUT with vpp package installed only (e.g., Arm FVP and FPGA), find vppctl path by "which vppctl".

Alternatively, for DUT with dataplane repo, user can choose to run script `run_dut.sh -l` to setup vpp::
        
        $ cd /path/to/dataplane-stack
        $ ./usecase/l2_switching/run_dut.sh -l

.. note::

        Run "./usecase/l2_switching/run_dut.sh --help" for all supported options.

For more detailed usage of VPP commands in the `run_dut.sh`, refer to following links,

- `VPP rdma cli reference`_
- `VPP memif interface reference`_
- `VPP set interface state reference`_
- `VPP set interface l2 bridge reference`_

To explore more on VPP's accepted commands, please review `VPP cli reference`_.

Test
~~~~

Start another VPP instance as a daemon with config parameters::

        $ sudo /path/to/vpp unix {cli-listen /run/vpp/cli-tg.sock} cpu {main-core 2 corelist-workers 3}

Define variable to hold the VPP cli listen socket specified in above step::

        $ export sockfile-tg=/run/vpp/cli-tg.sock

Create a soft traffic generator with packet destination MAC address
of ``00:00:0a:81:00:02``::

        sudo /path/to/vppctl -s ${sockfile-tg} create memif socket id 1 filename /tmp/memif-dut-1
        sudo /path/to/vppctl -s ${sockfile-tg} create int memif id 1 socket-id 1 rx-queues 1 tx-queues 1 slave
        sudo /path/to/vppctl -s ${sockfile-tg} create memif socket id 2 filename /tmp/memif-dut-2
        sudo /path/to/vppctl -s ${sockfile-tg} create int memif id 1 socket-id 2 rx-queues 1 tx-queues 1 slave
        sudo /path/to/vppctl -s ${sockfile-tg} set interface mac address memif1/1 02:fe:a4:26:ca:ac
        sudo /path/to/vppctl -s ${sockfile-tg} set interface mac address memif2/1 02:fe:51:75:42:ed
        sudo /path/to/vppctl -s ${sockfile-tg} set int state memif1/1 up
        sudo /path/to/vppctl -s ${sockfile-tg} set int state memif2/1 up
        sudo /path/to/vppctl -s ${sockfile-tg} packet-generator new {        \
                                                name pg0                  \
                                                limit -1                  \
                                                size 64-64                \
                                                node memif1/1-output      \
                                                tx-interface memif1/1     \
                                                data {                    \
                                                IP4: 00:00:0A:81:0:1 -> 00:00:0A:81:0:2  \
                                                UDP: 192.81.0.1 -> 192.81.0.2  \
                                                UDP: 1234 -> 2345         \
                                                incrementing 8            \
                                                }                         \
                                            }


Start to send the traffic to DUT::

        sudo /path/to/vppctl -s ${sockfile-tg} packet-generator enable-stream pg0

Then ``vpp`` will forward those packets out on output interface. After several seconds,
run below command to check memif interfaces rx/tx counters on VPP switch instance::

        sudo /path/to/vppctl -s ${sockfile} show interface

Alternatively, for DUT with dataplane repo, user can choose to run the script `run_pg.sh`
to create a soft traffic generator and send packets to VPP switch::

        $ ./usecase/l2_switching/run_pg.sh

Then run the script ``traffic_monitor.sh`` to examine memif interfaces rx/tx counters.
Here is a sample output for memif interfaces::

        $ ./usecase/l2_switching/traffic_monitor.sh

          Name          Idx    State  MTU (L3/IP4/IP6/MPLS)     Counter          Count
        local0           0     down          0/0/0/0
        memif1/1         1      up          9000/0/0/0         rx packets       35205632
                                                               rx bytes       2253160448
        memif2/1         2      up          9000/0/0/0         tx packets       35205632
                                                               tx bytes       2253160448

Stop
~~~~

Kill VPP::

        $ sudo pkill -9 vpp

*******************
RDMA NIC connection
*******************

Setup
~~~~~

This guide assumes the following topology:

.. figure:: ../images/l2_switching_rdma.png
   :align: center
   :width: 400

Start VPP as a daemon with config parameters::

        $ sudo /path/to/vpp unix {cli-listen /run/vpp/cli.sock} cpu {main-core 1 corelist-workers 2}

.. note::
        For DUT with dataplane stack repo, vpp binary path is components/vpp/build-root/install-vpp-native/vpp/bin/vpp.

        For DUT with vpp package installed only (e.g., Arm FVP and FPGA), find vpp path by "which vpp".

Define variable to hold the VPP cli listen socket specified in above step::

        $ export sockfile=/run/vpp/cli.sock

For ethernet connections to extern traffic generator, add following VPP commands
to create ethernet interfaces and associate interfaces with a bridge domain::

        sudo /path/to/vppctl -s ${sockfile} create interface rdma host-if enP1p1s0f0 name eth0
        sudo /path/to/vppctl -s ${sockfile} set interface state eth0 up
        sudo /path/to/vppctl -s ${sockfile} create interface rdma host-if enP1p1s0f1 name eth1
        sudo /path/to/vppctl -s ${sockfile} set interface state eth1 up
        sudo /path/to/vppctl -s ${sockfile} set interface l2 bridge eth0 10
        sudo /path/to/vppctl -s ${sockfile} set interface l2 bridge eth1 10
        sudo /path/to/vppctl -s ${sockfile} l2fib add 00:00:0A:81:0:2 10 eth1 static

Alternatively, for DUT with dataplane repo, user can run `run_dut.sh -p` to create
ethernet interfaces in VPP and associate interfaces with a bridge domain::

        $ ./usecase/l2_switching/run_dut.sh -p enp1s0f0np0 enp1s0f0np1

.. note::
        Use interface names on DUT to replace sample NIC names here.

Test
~~~~

To display the MAC address entries of the L2 FIB table, use the command ``show l2fib all``.
Here is a sample output for added MAC address entry of ethernet connection::

        $ sudo /path/to/vppctl -s ${sockfile} show l2fib all
            Mac-Address     BD-Idx If-Idx BSN-ISN Age(min) static filter bvi         Interface-Name
         00:00:0a:81:00:02    1      2      0/0      no      *      -     -             eth1
        L2FIB total/learned entries: 1/0  Last scan time: 0.0000e0sec  Learn limit: 16777216

Configure your traffic generator to send packets with a destination MAC address
of ``00:00:0a:81:00:02``, then ``VPP`` will forward those packets out on eth1.

Use the command ``show interface`` to display interface tx/rx counters.
Here is a sample output for ethernet interfaces::

        $ sudo /path/to/vppctl -s ${sockfile} show interface

          Name               Idx    State  MTU (L3/IP4/IP6/MPLS)     Counter          Count
         local0               0     down          0/0/0/0
         eth0                 1      up          9000/0/0/0     rx packets              25261056
                                                                rx bytes             37891584000
         eth1                 2      up          9000/0/0/0     tx packets              25261056
                                                                tx bytes             37891584000

Stop
~~~~

Kill VPP::

        $ sudo pkill -9 vpp

*********
Resources
*********

#. `VPP configuration reference <https://s3-docs.fd.io/vpp/22.02/configuration/reference.html>`_
#. `VPP rdma cli reference <https://s3-docs.fd.io/vpp/22.02/cli-reference/clis/clicmd_src_plugins_rdma.html>`_
#. `VPP memif interface reference <https://s3-docs.fd.io/vpp/22.02/cli-reference/clis/clicmd_src_plugins_memif.html>`_
#. `VPP set interface state reference <https://s3-docs.fd.io/vpp/22.02/cli-reference/clis/clicmd_src_vnet.html#set-interface-state>`_
#. `VPP set interface l2 bridge reference <https://s3-docs.fd.io/vpp/22.02/cli-reference/clis/clicmd_src_vnet_l2.html#set-interface-l2-bridge>`_
#. `VPP cli reference <https://s3-docs.fd.io/vpp/22.02/cli-reference/index.html>`_
