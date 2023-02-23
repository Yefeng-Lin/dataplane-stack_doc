..
  # Copyright (c) 2022, Arm Limited.
  #
  # SPDX-License-Identifier: Apache-2.0

##########
User Guide
##########

Welcome to the Dataplane Stack reference solution user guide. This guide provides
the detailed guidelines to end users on how to download, build and execute the
solution on Arm platforms. Guidelines on experimenting with various parameters
that affect performance of the uses cases are described in detail. This guide
is intended to describe complex and practical uses cases requiring complex
test setup.

**************************
Users and Essential Skills
**************************

The reference solutions are targeted for a networking software development or
performance analysis engineer who has in-depth networking knowledge, but does
not know about Arm necessarily.

Using this guide requires in-depth knowledge on networking use cases. Mastering
knowledge on certain user space open source networking projects,
e.g., DPDK, VPP, ODP, will help gain deeper understanding of this guide
and the reference solutions more easily.

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

    To use Mellanox NIC, install OFED driver and update NIC firmware by following the guidance in :doc:`FAQ <../faq>`.

*****************
Preparing the DUT
*****************

The DUT is also used to download the solution repository and
build the code. Cross compilation is not supported currently.

Requirements
~~~~~~~~~~~~

The DUT needs to have a minimum hardware configuration as below.

 * Processor: Minimum 1 GHz and 4 CPU cores
 * Hard Drive: Minimum 32 GB
 * Memory (RAM): Minimum 8 GB
 * Network Interface Controller: Minimum 10G port connecting to Traffic
   Generator
 * Ethernet connection to internet

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

  Sometimes new features and additional bug fixes will be made available in
  the git repositories and will not yet have been tagged as part of a
  release. To pick up these latest changes, remove the
  ``-b <release tag>`` option from the ``repo init`` command below. However,
  please be aware that such untagged changes have not yet been formally
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

This solution includes a ``setup.sh`` Bash script responsible for the setup
process.

The setup script:

- Installs and upgrades the following packages

  ``net-tools build-essential manpages-dev libnuma-dev python python3-venv cmake meson pkg-config python3-pyelftools lshw``

- Configures platform level parameters required to run the applications

Specifically, it overwrites ``GRUB_CMDLINE_LINUX`` in ``/etc/default/grub`` to

- reserve one 1G hugepage (via ``hugepagesz=1G hugepages=1``)
- reserve 512 2M hugepages (via ``hugepagesz=2M hugepages=512``)
- set IOMMU into passthrough mode (via ``iommu.passthrough=1``)
- isolate CPUs 2 and 3 from the Linux scheduler (via ``isolcpus=2-3``)
- isolate CPUs 2 and 3 from processing RCU callbacks (via ``rcu_nocbs=2-3``)
- set CPUs 2 and 3 to omit scheduling clock ticks  (via ``nohz_full=2-3``)
- disable cpufreq and cpuidle subsystems (via ``cpufreq.off=1`` and
  ``cpuidle.off=1``)

To isolate more or different CPUs, edit ``setup.sh`` accordingly. To help speedup
compilation, ensure that there are sufficient number of CPUs (at least 4 if possible)
that are not isolated.

.. raw:: html

   <details>
   <summary><a>Why reserve hugepages?</a></summary>

.. code-block:: none

    Hugepages help prevent TLB misses and are commonly used by networking
    applications to manage memory. The larger the hugepage, the greater the
    performance increase due to fewer TLB misses and fewer page table walks.

    1GB hugepages are easiest to reserve at boot time, as reservation during
    run time is likely to not be possible. Run time reservation would require
    1GB of available contiguous memory, which typically is not available.

.. raw:: html

   </details>
   <br />

.. raw:: html

   <details>
   <summary><a>Why isolate CPUs?</a></summary>

.. code-block:: none

    The combination of the kernel parameters mentioned above ensure that the
    CPUs run only the desired application. They never process kernel RCU
    callbacks, don't generate schedling ticks as there is only one process
    running on them, and are isolated from running any processes other than
    the ones pinned to them (the desired application).


.. raw:: html

   </details>
   <br />


To set up the DUT:

::

    cd <nw_ds_workspace>/dataplane-stack
    sudo ./setup.sh


Build
~~~~~

This solution uses Makefile to build all the components.

The Makefile:

- Builds DPDK and the L3fwd sample applications
- Builds VPP

To build Dataplane Stack, run the following on DUT:

::

    cd <nw_ds_workspace>/dataplane-stack
    make all

It is also possible to compile the components individually by specifying ``make dpdk`` or ``make vpp``.
Run ``make help`` to view a list of all Makefile targets.

The above mentioned ``make`` commands can also be used to rebuild after modifying the code.

Reboot
~~~~~~
After setting up DUT and building the software, reboot the DUT. This ensures the setup changes are reflected before
running the sample applications.


Get NIC Interface
~~~~~~~~~~~~~~~~~
Next, identify the interface(s) on the NIC(s) connected to the traffic
generator.

.. raw:: html

   <details>
   <summary><a>How to find the right interfaces?</a></summary>

.. code-block:: none

    $ sudo ethtool --identify <interface>
    will typically blink a light on the NIC to help identify the
    physical port associated with the interface.

.. raw:: html

   </details>
   <br />

*******************************************
Porting/Integrating to another Arm platform
*******************************************

Although the solution is tested on limited hardware platforms, the solution
might work just fine on other Arm platforms. However, such platforms should
support ArmV8 architecture at least and should be supported by the underlying
components.


*********
Use Cases
*********


.. toctree::
   :titlesonly:
   :maxdepth: 2

   ipv4_l3fwd
   ipv4_vpp
   l2_switching_vpp
   tcp_term
