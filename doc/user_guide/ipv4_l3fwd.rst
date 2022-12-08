..
  # Copyright (c) 2022, Arm Limited.
  #
  # SPDX-License-Identifier: Apache-2.0

###############
DPDK IPv4 L3fwd
###############

************
Introduction
************

The ``dpdk-l3fwd`` sample application demonstrates the use of the hash, LPM
and FIB based lookup methods provided in DPDK
to implement packet forwarding using `poll mode <https://doc.dpdk.org/guides-20.11/prog_guide/poll_mode_drv.html>`_
or `event mode <https://doc.dpdk.org/guides-20.11/prog_guide/eventdev.html>`_ PMDs for packet
I/O. The instructions provided in this guide do not cover all the features of this sample application. Users can refer to
`dpdk-l3fwd user guide <https://doc.dpdk.org/guides-21.11/sample_app_ug/l3_forward.html>`_ to learn and experiment additional features.

.. _Setup:

**********
Test Setup
**********

This guide assumes the following setup:

::

    +------------------+                              +-------------------+
    |                  |                              |                   |
    |  Traffic         |                         +----|       DUT         |
    |  Generator       | Ethernet Connection(s)  | N  |                   |
    |                  |<----------------------->| I  |                   |
    |                  |                         | C  |                   |
    |                  |                         +----|                   |
    +------------------+                              +-------------------+

As shown, the Device Under Test (DUT) should have at least one NIC port connected
to the traffic generator. The user can use any traffic generator.

Get NIC PCIe Address
~~~~~~~~~~~~~~~~~~~~

Identify the PCIe addresses of the NIC ports attached to the traffic generator.
Once the interface is known, then ``dpdk-devbind.py`` can identify the matching PCIe address::

    cd <nw_ds_workspace>/dataplane-stack
    sudo components/dpdk/usertools/dpdk-devbind.py -s

The output may look like:

.. code-block:: none

    Network devices using kernel driver
    ===================================
    0000:07:00.0 'RTL8111/8168/8411 PCI Express Gigabit Ethernet Controller 8168' if=enp7s0 drv=r8169 unused=vfio-pci *Active*
    0001:01:00.0 'MT28800 Family [ConnectX-5 Ex] 1019' if=enP1p1s0f0 drv=mlx5_core unused=vfio-pci
    0001:01:00.1 'MT28800 Family [ConnectX-5 Ex] 1019' if=enP1p1s0f1 drv=mlx5_core unused=vfio-pci

In this example output, if the interface ``enP1p1s0f0`` is connected to the traffic generator, then the corresponding
PCIe address is ``0001:01:00.0``.

Bind NIC to Proper Linux Driver
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

For NICs that support bifurcated drivers, like Mellanox NICs, please skip this step.

For other NICs to be used by DPDK, the NIC needs to be bound to the appropriate driver. 
In practice, the ``vfio-pci`` driver is sufficient. Before using ``vfio-pci``, be sure to load
the kernel module with ``modprobe vfio-pci``.
For more information, review DPDK's `Linux Drivers Guide <https://doc.dpdk.org/guides-21.11/linux_gsg/linux_drivers.html>`_.


To bind the NIC to the appropriate driver, run::

    cd <nw_ds_workspace>/dataplane-stack
    sudo modprobe vfio-pci # ensure kernel module is loaded
    sudo components/dpdk/usertools/dpdk-devbind.py -b vfio-pci <pcie_address>

For example, to bind PCIe address ``0000:06:00.1`` to ``vfio-pci``::

    sudo modprobe vfio-pci # ensure kernel module is loaded
    sudo components/dpdk/usertools/dpdk-devbind.py -b vfio-pci 0000:06:00.1

***
Run
***

To run `DPDK
L3fwd <https://doc.dpdk.org/guides-21.11/sample_app_ug/l3_forward.html>`__ application:

::

    cd <nw_ds_workspace>/dataplane-stack
    sudo components/dpdk/build/examples/dpdk-l3fwd [EAL Options] -- [L3fwd App Options]

Refer to DPDK documentation for supported `EAL
Options <https://doc.dpdk.org/guides/linux_gsg/linux_eal_parameters.html>`__ and
`L3fwd App Options <https://doc.dpdk.org/guides-21.11/sample_app_ug/l3_forward.html#running-the-application>`__.

For the configuration provided in ``setup.sh`` and a test setup with port 0 connected to traffic generator, use the following command to run the application::

    cd <nw_ds_workspace>/dataplane-stack
    sudo components/dpdk/build/examples/dpdk-l3fwd -n 4 -l 2 -a <pcie_address> -- -P -p 0x1 --config='(0,0,2)'

For example, to run ``dpdk-l3fwd`` using ``0001:01:00.0``::

    cd <nw_ds_workspace>/dataplane-stack
    sudo components/dpdk/build/examples/dpdk-l3fwd -n 4 -l 2 -a 0001:01:00.0 -- -P -p 0x1 --config='(0,0,2)'

Test
~~~~
The typical output for the above command contains::

    Initializing port 0 ... Creating queues: nb_rxq=1 nb_txq=1...
    Address:98:03:9B:71:24:2E, Destination:02:00:00:00:00:00, Allocated mbuf pool on socket 0
    LPM: Adding route 198.18.0.0 / 24 (0) [0001:01:00.0]
    LPM: Adding route 2001:200:: / 64 (0) [0001:01:00.0]
    txq=2,0,0

These logs show port 0 has MAC address ``98:03:9B:71:24:2E`` with PCIe address
``0001:01:00.0`` on the DUT. An IPv4 route matching the subnet
``198.18.0.0/24`` is added.

Configure the traffic generator to send packets to the NIC port,
using the MAC and IP address displayed in the logs. In this example,
use a destination MAC address of ``98:03:9B:71:24:2E`` and a destination
IP of ``198.18.10.21``. Then, ``dpdk-l3fwd`` will forward those packets out on port 0.

Stop
~~~~
Stop the ``dpdk-l3fwd`` process with Control-C or ``kill``. Next, if the NIC had been bound to a different Linux driver, rebind it to its original driver.
Find the original driver by running ``dpdk-devbind.py -s``, and notice the ``unused=`` part of the PCIe address.

For example, sample output from ``dpdk-devbind.py -s`` may look like::

    cd <nw_ds_workspace>/dataplane-stack
    sudo components/dpdk/usertools/dpdk-devbind.py -s

    Network devices using DPDK-compatible driver
    ============================================
    0000:07:00.0 'Ethernet Controller XL710 for 40GbE QSFP+ 1583' drv=vfio-pci unused=i40e
    ...

In this example, bind ``0000:07:00.0`` to the ``i40e`` Linux driver using the following command.

::

    cd <nw_ds_workspace>/dataplane-stack
    sudo components/dpdk/usertools/dpdk-devbind.py -b i40e 0000:07:00.0


*********************
Suggested Experiments
*********************
The example provided above covers a very simple use case of the DPDK L3fwd application.
Users are encouraged to experiment with various options provided by the application.

The users are also encouraged to try the following options to understand
the performance and scalability possible with Arm platforms.

- Number of RX/TX ring descriptors: This can affect the performance in multiple ways.
  For example, if the DUT is capable of storing the incoming packets in system cache,
  the incoming packets can trash the system cache, reducing the overall performance.
  To understand how these affect the performance, experiment by changing the
  number of descriptors. Change ``RTE_TEST_RX_DESC_DEFAULT`` and ``RTE_TEST_TX_DESC_DEFAULT``
  in file ``l3fwd.h`` and recompile DPDK.

- ``--config``: This parameter assigns the NIC RX queues to CPU cores. It is
  possible that a single queue might not be able to saturate a single CPU core.
  One can experiment by assigning multiple queues to a single core. For example, the option
  ``--config='(0,0,1),(0,1,1)'`` assigns the queues 0 and 1 of port 0 to lcore 1.
  Ensure that Receive Side Scaling (RSS) distributes the packets equally to all the
  enabled queues by sending multiple flows of traffic.

- CPU Scalability: Add more ports to DUT and run the application on more CPU cores
  to understand how the performance scales with the addition of CPU cores. Ensure
  that Receive Side Scaling (RSS) distributes the packets equally to all the
  enabled queues by sending multiple flows of traffic.

- Route Scalability: Add additional routes and multiple flows of traffic that exercise
  these routes. Additional routes can be added such that the accessed data size
  is more than the available L1, L2 or system cache size.

  To change forwarding rules, edit the global constants in:

  * ``main.c``: edit the ``ipv4_l3fwd_route_array`` or ``ipv6_l3fwd_route_array`` to adjust
    default routes for FIB or LPM lookups.


DPDK in this solution is built with all the sample applications enabled. The users
can run other sample applications by following the instructions in DPDK's `Sample Applications User Guide <https://doc.dpdk.org/guides/sample_app_ug/index.html>`__.

*********
Resources
*********

#. `DPDK Linux Getting Started Guide on DPDK Drivers <https://doc.dpdk.org/guides-21.11/linux_gsg/linux_drivers.html>`_
#. `DPDK User Guide on dpdk-l3fwd <https://doc.dpdk.org/guides-21.11/sample_app_ug/l3_forward.html>`_
#. `DPDK's dpdk-devbind.py documentation <https://doc.dpdk.org/guides-21.11/tools/devbind.html>`_
#. `DPDK Poll Mode Drivers <https://doc.dpdk.org/guides-20.11/prog_guide/poll_mode_drv.html>`_
#. `DPDK Event Mode <https://doc.dpdk.org/guides-20.11/prog_guide/eventdev.html>`_
#. `MLNX_OFED Software Download <https://docs.nvidia.com/networking/category/mlnxofedib>`_
