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
address. It forwards packets based on the l2fib table.

This guide explains in detail on how to use the VPP based L2 switching use case.

**********
Test Setup
**********

This guide assumes the following setup::

    +------------------+                              +-------------------+
    |                  |                              |                   |
    |  Traffic         | <--------------------------> |       DUT         |
    |  Generator       |        connections           |                   |
    |                  |                              |                   |
    |                  | <--------------------------> |                   |
    |                  |                              |                   |
    +------------------+                              +-------------------+

As shown, the Device Under Test (DUT) should have at least two connections
to the traffic generator. The user can use any traffic generator. The connections
can be logical memif connection to soft traffic generator located on same host
or physical ethernet connection to external traffic generator.

***
Run
***

For ethernet connections to extern traffic generator, run `run_dut.sh -p`
to create ethernet interfaces in vpp and associate interfaces with a bridge domain::

        $ ./usecase/l2_switching/run_dut.sh -p enp1s0f0np0 enp1s0f0np1

.. note::
        Use interface names on DUT to replace sample names here.

OR

For memif connections to soft traffic generator located on same host, run `run_dut.sh -l`
to create memif interfaces and associate interfaces with a bridge domain::

        $ ./usecase/l2_switching/run_dut.sh -l

.. note::
        Run "./usecase/l2_switching/run_dut.sh –h" for all supported options.

For more detailed usage of vpp commands in the `run_dut.sh`, refer to following links,

- `VPP rdma cli reference`_
- `VPP memif interface reference`_
- `VPP set interface state reference`_
- `VPP set interface l2 bridge reference`_

To explore more on VPP's accepted commands, please review `VPP cli reference`_.

Test
~~~~

Configure your traffic generator to send packets with a destination MAC address
of ``00:00:0a:81:00:02``, then ``vpp`` will forward those packets out on output interface.

For memif connections example, run the script `run_pg.sh` to create a soft traffic generator
and send packets to vpp switch::

        $ ./usecase/l2_switching/run_pg.sh

Run the script ``traffic_monitor.sh`` to examine interface rx/tx counters.
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

Kill vpp::

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
