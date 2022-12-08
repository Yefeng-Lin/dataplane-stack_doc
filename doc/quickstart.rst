..
  # Copyright (c) 2022, Arm Limited.
  #
  # SPDX-License-Identifier: Apache-2.0

################
Quickstart Guide
################

************
Introduction
************

Welcome to the Dataplane Stack reference solution quickstart guide. This guide
provides instructions on how to fetch source code, build the source code and run sample
applications.

By following the steps in this quickstart guide to the end, you will set up two
user space programs for high-throughput packet forwarding. The programs accept
packets from NIC port 0 and forward them out on the same NIC port based on their
destination IP address.

Users and Essential Skills
~~~~~~~~~~~~~~~~~~~~~~~~~~

The reference solutions are targeted for a networking software development or
performance analysis engineer who has in-depth networking knowledge, but does
not know about Arm necessarily.

Mastering knowledge on certain user space open source networking projects,
e.g., DPDK, VPP, ODP, will help gain deeper understanding of this guide
and the reference solutions more easily.

*****
Setup
*****

The sample applications described in this guide require the following setup.

::

    +------------------+                              +-------------------+
    |                  |                              |                   |
    |  Traffic         |                         +----|       DUT         |
    |  Generator       |   Ethernet Connection   | N  |                   |
    |                  |<----------------------->| I  |                   |
    |                  |                 (Port 0)| C  |                   |
    |                  |                         +----|                   |
    +------------------+                              +-------------------+

As shown, the Device Under Test (DUT) should have at least one NIC connected
to the traffic generator on port 0. The user can use any traffic
generator. The DUT is also used to download the solution repository and
build the code. Cross compilation is not supported currently.

****************
Tested Platforms
****************

The sample applications are tested on the following platforms.

DUT
~~~

-  Ampere Altra (Neoverse-N1)

   -  Ubuntu 20.04.3 LTS (Focal Fossa)
   -  `Kernel 5.17.0-051700-generic <https://www.linuxcapable.com/how-to-install-linux-kernel-5-17-on-ubuntu-20-04-lts/>`_

NIC
~~~

-  `Mellanox ConnectX-5 <https://www.nvidia.com/en-us/networking/ethernet/connectx-5/>`__

   -  OFED driver: MLNX_OFED_LINUX-5.4-3.1.0.0
   -  Firmware version: 16.30.1004 (MT\_0000000013).

.. note::

    To use Mellanox NIC, install OFED driver and update NIC firmware by following the guidance in :doc:`FAQ <faq>`.

*****************
Preparing the DUT
*****************

Requirements
~~~~~~~~~~~~

The DUT needs to have a minimum hardware configuration as below.

 * Processor: Minimum 1 GHz and 4 CPU cores
 * Hard Drive: Minimum 32 GB
 * Memory (RAM): Minimum 8 GB
 * Network Interface Controller: Minimum 10G port connecting to Traffic
   Generator
 * Connection to internet to download the source code and dependent packages

This documentation assumes the user has installed Ubuntu 20.04 (Focal) on
the DUT.

 * Admin (root) privileges are required to run the software and set up the
   DUT.
 * Access to the internet is mandatory for downloading solution source code
   and installing all dependent packages and libraries.
 * Scripts are provided to install the dependent packages and libraries.
 * Mellanox OFED driver is installed and NIC firmware is updated.
 * gcc 9.4.0 or newer version is required to compile the software.
 * The provided scripts must be run in a bash shell.

The following utilities must be available on the DUT:
 * git
 * curl
 * python
 * python3

To configure Git, run:

::

    git config --global user.email "you@example.com"
    git config --global user.name "Your Name"

Follow the instructions provided in
`git-repo <https://gerrit.googlesource.com/git-repo>`__ to install the
``repo`` tool manually.

Download Source Code
~~~~~~~~~~~~~~~~~~~~

Create a new folder that will be the workspace, henceforth referred to as
``<nw_ds_workspace>`` in these instructions:

::

    mkdir <nw_ds_workspace>
    cd <nw_ds_workspace>
    export NW_DS_RELEASE=refs/tags/NW-DS-2022.06.30

.. note::

  Sometimes new features and additional bug fixes are made available in
  the git repositories, but are not tagged yet as part of a release.
  To pick up these latest changes, remove the
  ``-b <release tag>`` option from the ``repo init`` command below.
  However, please be aware that such untagged changes may not be formally
  verified and should be considered unstable until they are tagged in an
  official release.

To clone the repository, run the following commands:

::

    repo init \
        -u https://git.gitlab.arm.com/arm-reference-solutions/arm-reference-solutions-manifest.git \
        -b ${NW_DS_RELEASE} \
        -m dataplane-stack.xml
    repo sync


Setup
~~~~~

This solution includes a ``setup.sh`` bash script responsible for the setup
process.

The setup script:

- Installs and upgrades the required packages
- Configures platform level parameters required to run the applications

The affected packages and parameters can be found in ``setup.sh``.

To set up the DUT:

::

    cd <nw_ds_workspace>/dataplane-stack
    sudo ./setup.sh

Build
~~~~~

This solution uses Makefile to build all the components.

The Makefile:

- Builds DPDK and the L3fwd sample application
- Builds VPP

To build Dataplane Stack, run the following on DUT:

::

    cd <nw_ds_workspace>/dataplane-stack
    make all

.. note::

  The compilation might take some time to complete.

Reboot
~~~~~~
After setting up DUT and building the software, reboot the DUT. This ensures the setup changes are reflected before
running the sample applications.

Get NIC Information
~~~~~~~~~~~~~~~~~~~

Identify the interface and PCIe address of the NIC port attached to the traffic generator.
``sudo ethtool --identify <interface name>`` will help identify which NIC port is associated with a given interface name.
``sudo lshw -c net -businfo`` will identify the PCIe address for the interface.

For example, if ``enP1p1s0f0`` is attached to the traffic generator, then running ``lshw -c net -businfo`` will show
the PCIe address as ``0001:01:00.0``::

        $ sudo lshw -c net -businfo
        Bus info          Device      Class      Description
        ====================================================
        pci@0000:07:00.0  eth0        network    RTL8111/8168/8411 PCI Express Gigabit Ethernet Controller
        pci@0001:01:00.0  enP1p1s0f0  network    MT27800 Family [ConnectX-5]
        pci@0001:01:00.1  enP1p1s0f1  network    MT27800 Family [ConnectX-5]

**********
DPDK L3fwd
**********

Bind NIC to Proper Linux Driver
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

For NICs that support bifurcated drivers, like Mellanox NICs, please skip this step.

For other NICs to be used by DPDK, the NIC needs to be bound to the appropriate driver.
In practice, ``vfio-pci`` driver is sufficient. Before using ``vfio-pci``, be sure to load
the kernel module with ``modprobe vfio-pci``.
For more information, review DPDK's `Linux Drivers Guide <https://doc.dpdk.org/guides-21.11/linux_gsg/linux_drivers.html>`_.


To bind the NIC to the appropriate driver, run::

    cd <nw_ds_workspace>/dataplane-stack
    sudo modprobe vfio-pci # ensure kernel module is loaded
    sudo components/dpdk/usertools/dpdk-devbind.py -b vfio-pci <pcie_address>

For example, to bind PCIe address ``0000:06:00.1`` to ``vfio-pci``::

    sudo modprobe vfio-pci # ensure kernel module is loaded
    sudo components/dpdk/usertools/dpdk-devbind.py -b vfio-pci 0000:06:00.1

Run
~~~

To run `DPDK
L3fwd <https://doc.dpdk.org/guides-21.11/sample_app_ug/l3_forward.html>`__ application:

::

    cd <nw_ds_workspace>/dataplane-stack
    sudo components/dpdk/build/examples/dpdk-l3fwd -n 4 -l 2 -a <pcie_address> -- -P -p 0x1 --config='(0,0,2)'

For example, to run ``dpdk-l3fwd`` using ``0001:01:00.0``::

    cd <nw_ds_workspace>/dataplane-stack
    sudo components/dpdk/build/examples/dpdk-l3fwd -n 4 -l 2 -a 0001:01:00.0 -- -P -p 0x1 --config='(0,0,2)'

Test
~~~~
For example, the typical output contains::

    Initializing port 0 ... Creating queues: nb_rxq=1 nb_txq=1...
    Address:98:03:9B:71:24:2E, Destination:02:00:00:00:00:00, Allocated mbuf pool on socket 0
    LPM: Adding route 198.18.0.0 / 24 (0) [0001:01:00.0]
    LPM: Adding route 2001:200:: / 64 (0) [0001:01:00.0]
    txq=2,0,0

These logs show port 0 has MAC address ``98:03:9B:71:24:2E`` with PCIe address
``0001:01:00.0`` on the DUT. 1 IPv4 route matching the subnet
``198.18.0.0/24`` is added.

Configure the traffic generator to send packets to the NIC port,
using the MAC and IP address displayed in the logs. In this example,
use a destination MAC address of ``98:03:9B:71:24:2E`` and a destination
IP of ``198.18.0.21``. Then, ``dpdk-l3fwd`` will forward those packets out on port 0.

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

In this example, bind ``0000:07:00.0`` to the ``i40e`` Linux driver using the following command ::

    cd <nw_ds_workspace>/dataplane-stack
    sudo components/dpdk/usertools/dpdk-devbind.py -b i40e 0000:07:00.0


*********
VPP L3fwd
*********

.. note::

    Currently, the instructions provided in this section work with Mellanox NICs only.

Run
~~~

To run `VPP <https://fd.io/>`__::

    cd <nw_ds_workspace>/dataplane-stack
    sudo ./components/vpp/build-root/install-vpp-native/vpp/bin/vpp unix {interactive}

.. note::

    It is possible that VPP may throw warnings and errors during
    initialization. These can be ignored safely.

Configure VPP with L3 interface and routes in VPP command prompt,
note the interface name ``enP1p1s0f0`` below is obtained from above ``lshw`` command:

.. code-block:: none

        vpp# create interface rdma host-if enP1p1s0f0 name eth0
        vpp# set interface mac address eth0 00:11:22:33:44:55
        vpp# set interface ip address eth0 1.1.1.2/24
        vpp# set interface state eth0 up
        vpp# ip route add 198.18.0.0/24 via 1.1.1.1
        vpp# set ip neighbor eth0 1.1.1.1 02:00:00:00:00:00

Test
~~~~

After running the above command, configure the traffic generator to send packets to port 0
with a destination MAC address of ``00:11:22:33:44:55`` and an IP in the subnet ``198.18.0.0/24``.
``vpp`` will forward those packets out on port 0.

Stop
~~~~

To stop VPP, enter ``quit`` in VPP command line prompt:

.. code-block:: none

        vpp# quit

************************
Changelog & Known Issues
************************

To check newly added features, feature changes, and known issues in each of
the releases, please refer to :doc:`CHANGELOG <../changelog>`.
