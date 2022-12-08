..
  # Copyright (c) 2022, Arm Limited.
  #
  # SPDX-License-Identifier: Apache-2.0

##############
VPP IPv4 L3fwd
##############

************
Introduction
************

VPP IPv4 L3fwd implements the typical routing function base on 32-bit IPv4
address. It forwards packets using Longest Prefix Match algorithm based on
the mtrie forwarding table.

This guide explains in detail on how to use the VPP based IPv4 forwarding
related use cases.

**********
Test Setup
**********

This guide assumes the following setup::

    +------------------+                              +-------------------+
    |                  |                              |                   |
    |  Traffic         |                         +----|       DUT         |
    |  Generator       | Ethernet Connection(s)  | N  |                   |
    |                  |<----------------------->| I  |                   |
    |                  |                         | C  |                   |
    |                  |                         +----|                   |
    +------------------+                              +-------------------+

As shown, the Device Under Test (DUT) should have at least one NIC connected
to the traffic generator. The user can use any traffic generator.

***
Run
***

.. _lshw output sample:

Find out which interface is connected with traffic generator,
``sudo ethtool --identify <interface>`` will typically blink a light on the NIC to help identify the
physical port associated with the interface.

Get interface name ``enP1p1s0f0`` from ``lshw`` command::

        $ sudo lshw -c net -businfo
        Bus info          Device      Class      Description
        ====================================================
        pci@0000:07:00.0  eth0        network    RTL8111/8168/8411 PCI Express Gigabit Ethernet Controller
        pci@0001:01:00.0  enP1p1s0f0  network    MT27800 Family [ConnectX-5]
        pci@0001:01:00.1  enP1p1s0f1  network    MT27800 Family [ConnectX-5]

Start vpp with ``interactive`` command line arguments, and for more argument parameters,
refer to `VPP configuration reference`_::

        cd <nw_ds_workspace>/dataplane-stack
        sudo ./components/vpp/build-root/install-vpp-native/vpp/bin/vpp unix {interactive}

Typically we configure VPP with 1 packet flow and 10k packet flows.
Both cases start with following common VPP command configuration::

        # Same for different packet flow setups
        vpp# create interface rdma host-if enP1p1s0f0 name eth0
        vpp# set interface ip address eth0 1.1.1.2/30
        vpp# set ip neighbor eth0 1.1.1.1 02:00:00:00:00:00
        vpp# set interface state eth0 up

For more detailed usage on above commands, refer to following links,

- `VPP rdma cli reference`_
- `VPP set interface ip address reference`_
- `VPP ip neighbor cli reference`_
- `VPP set interface state reference`_

For 1 packet flow case::

        # Add only one route entry here
        vpp# ip route add 10.0.0.0/32 count 1 via 1.1.1.1 eth0

For 10k packet flows case::

        # Add 10k route entries here
        vpp# ip route add 10.0.0.0/32 count 10000 via 1.1.1.1 eth0

Refer to `VPP ip route reference`_ for more ``ip route`` options.
To explore more on VPP's accepted commands, please review `VPP cli reference`_.

Test
~~~~

To display the current set of routes, use the command ``show ip fib``.
Here is a sample output for added routes::

        vpp# show ip fib 10.0.0.1/32
        ipv4-VRF:0, fib_index:0, flow hash:[src dst sport dport proto flowlabel ] epoch:0 flags:none locks:[adjacency:1, default-route:1, ]
        10.0.0.1/32 fib:0 index:17 locks:2
          CLI refs:1 src-flags:added,contributing,active,
            path-list:[22] locks:20000 flags:shared,popular, uPRF-list:22 len:1 itfs:[1, ]
              path:[26] pl-index:22 ip4 weight=1 pref=0 attached-nexthop:  oper-flags:resolved,
                1.1.1.1 eth0
              [@0]: ipv4 via 1.1.1.1 eth0: mtu:9000 next:3 flags:[] 02000000000098039b6b62680800
        
         forwarding:   unicast-ip4-chain
          [@0]: dpo-load-balance: [proto:ip4 index:19 buckets:1 uRPF:22 to:[0:0]]
            [0] [@5]: ipv4 via 1.1.1.1 eth0: mtu:9000 next:3 flags:[] 02000000000098039b6b62680800

Check the packet flow with IP destination 10.0.0.0/32, the next hop is resolved, packets will be forwarded to 1.1.1.1 via eth0.

To configure traffic generator for the destination MAC address,
get the VPP interface MAC address via ``show hardware-interfaces verbose``::

        vpp# show hardware-interfaces verbose
                      Name                Idx   Link  Hardware
        eth0                               1     up   eth0
          Link speed: 40 Gbps
          RX Queues:
            queue thread         mode
            0     vpp_wk_0 (1)   polling
            1     vpp_wk_0 (1)   polling
          Ethernet address 02:fe:40:5e:73:e3
          netdev enP1p1s0f0 pci-addr 0001:01:00.0

For 1 packet flow case, configure your traffic generator to send packets
with a destination MAC address of ``02:fe:40:5e:73:e3`` and an IP in the subnet ``10.0.0.0/32``,
then ``vpp`` will forward those packets out on eth0.

For 10000 packet flows case, configure your traffic generator to send packets
with a destination MAC address of ``02:fe:40:5e:73:e3`` and an increasing destination IP address,
increasing by 10000 times, starting from ``10.0.0.0/32`` with an increment of 1 in each increase,
then ``vpp`` will forward those packets out on eth0.

Stop
~~~~

To stop VPP, enter ``quit`` in VPP command line prompt::

        vpp# quit

*********************
Suggested Experiments
*********************

Add another interface
~~~~~~~~~~~~~~~~~~~~~

To add another interface in VPP, for example ``enP1p1s0f1`` in `lshw output sample`_.

Create another interface in VPP command line with different interface name::

        vpp# create interface rdma host-if enP1p1s0f1 name eth1
        vpp# set interface ip address eth1 3.3.3.2/30
        vpp# set interface state eth1 up

New routes can be add to this interface afterwards::

        vpp# ip route add 30.0.0.0/32 count 1 via 3.3.3.3 eth1

Start with configuration file
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

To start vpp with startup configuration file,
refer to `VPP starts with configuration file <https://s3-docs.fd.io/vpp/22.02/configuration/config_getting_started.html#configuration-file-startup-conf>`__

Create a very simple startup.conf file::

        cd <nw_ds_workspace>/dataplane-stack
        cat <<EOF > startup.conf
        unix {
                interactive
        }
        EOF

Instruct VPP to load this file with the -c option. For example::

        sudo ./components/vpp/build-root/install-vpp-native/vpp/bin/vpp -c startup.conf

Add CPU cores to worker thread
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

To add more CPU cores for VPP data plane, configure vpp with more workers for better performance,
refer to `VPP configuration cpu section <https://s3-docs.fd.io/vpp/22.02/configuration/reference.html#the-cpu-section>`__

::

        cpu {
                main-core 1
                corelist-workers 2-3,18-19
        }

Change number of descriptors in receive ring and transmit ring
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

To change number of descriptors in receive ring and transmit ring, increasing or reducing number can impact performance. Default is 1024,
refer to `VPP configuration num-rx-desc num-tx-desc <https://s3-docs.fd.io/vpp/22.02/configuration/reference.html#the-dpdk-section>`__

::

        dpdk {
                dev default {
                        num-rx-desc 512
                        num-tx-desc 512
                }
        }

Use faster DPDK vector PMDs
~~~~~~~~~~~~~~~~~~~~~~~~~~~

Disable multi-segment buffers, disable UDP / TCP TX checksum offload, needed to use faster DPDK vector PMDs, improves performance but disables Jumbo MTU support,
refer to `VPP configuration no-multi-seg <https://s3-docs.fd.io/vpp/22.02/configuration/reference.html#no-multi-seg>`__

::

        dpdk {
                no-multi-seg
                no-tx-checksum-offload
        }

Use other types of device drivers
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Besides Mellanox ConnectX-5, VPP supports NICs from other vendors as well. VPP is integrated with NICs using the following 2 methods:

* `VPP native device drivers <https://s3-docs.fd.io/vpp/22.02/developer/devicedrivers/index.html>`__

* `VPP dpdk device driver configuration <https://s3-docs.fd.io/vpp/22.02/configuration/reference.html#the-dpdk-section>`__

*********
Resources
*********

#. `VPP configuration reference <https://s3-docs.fd.io/vpp/22.02/configuration/reference.html>`_
#. `VPP rdma cli reference <https://s3-docs.fd.io/vpp/22.02/cli-reference/clis/clicmd_src_plugins_rdma.html>`_
#. `VPP set interface ip address reference <https://s3-docs.fd.io/vpp/22.02/cli-reference/clis/clicmd_src_vnet_ip.html#set-interface-ip-address>`_
#. `VPP ip neighbor cli reference <https://s3-docs.fd.io/vpp/22.02/cli-reference/clis/clicmd_src_vnet_ip-neighbor.html>`_
#. `VPP set interface state reference <https://s3-docs.fd.io/vpp/22.02/cli-reference/clis/clicmd_src_vnet.html#set-interface-state>`_
#. `VPP ip route reference <https://s3-docs.fd.io/vpp/22.02/cli-reference/clis/clicmd_src_vnet_ip.html#ip-route>`_
#. `VPP cli reference <https://s3-docs.fd.io/vpp/22.02/cli-reference/index.html>`_
