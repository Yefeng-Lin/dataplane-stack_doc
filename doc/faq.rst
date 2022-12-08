..
  # Copyright (c) 2022, Arm Limited.
  #
  # SPDX-License-Identifier: Apache-2.0

###
FAQ
###

#. Q: Is there any existing open source project with similar goals or with
   which this project may conflict or overlap? If yes, please identify the
   project and explain why we should create the ARM open source project
   anyway?

   A: Yes, there are some open source projects serve similar purpose, e.g.,
   `OPNFV <https://www.opnfv.org/>`_. However, compared with the software we
   would like to create, `OPNFV <https://www.opnfv.org/>`_
   has a much larger scope for us to cover. Morever, we would like to simply
   the reference solutions, focus on combining some currently being
   contributed networking projects, e.g., DPDK, VPP, ODP, and provide
   reference solutions aligned with existing marketing requirements.

   Inside the project, we will apply some optimizations applicable on Arm
   platform only, to achieve better performance, and those architecture
   specific optimizations will not be likely accepted by upstream community.

#. Q: Could you please provide the project description of functionality or
   purpose?

   A: The network functions this software provided serves multiple purposes
   of,

   #. Showcase the integration of various components and act as poof of
      concept to all stakeholders.

   #. Allow for performance analysis/optimization with a solution that is
      close to customers’ production deployment.

   #. Provide customers with a out-of-the-box reference design for rapid
      design modeling.

#. Q: What's "Fixed Virtual Platforms" and "FPGA Emulator"? And what are they
   used for?

   A: "Fixed Virtual Platforms" and "FPGA Emulator" are some pre-silicon
   simulation/emulation platforms, which could be used to develop and
   validate software for CPU features in early stage. Running the software
   on these platforms could introduce benefits on,

   #. External CPU/IP dimensioning according to different customer use-case

   #. Internal microarchitecture profiling and tuning using networking workload
      during CPU design phase

#. Q: Please explain dataplane and controlplane, and their differences?

   A: The terms “control plane” and “data plane” are all about the separation of
   responsibilities within a networking system. The two most commonly referenced
   compositions in networking are the control plane and the data plane. The
   control plane is the part of a network that controls how data is forwarded,
   while the data plane is the actual forwarding process.

   * **Control plane**: refers to the all functions and processes that
     determine which path to use to send the packet or frame. Control
     plane is responsible for populating the routing table, drawing network
     topology, forwarding table and hence enabling the data plane functions.
     Control plane is the process of learning what we will do before
     sending the packet or frame.

   * **Data plane**: refers to all the functions and processes that forward
     packets/frames from one interface to another based on control plane logic.
     Routing table, forwarding table and the routing logic constitute the data
     plane function. Data plane packet goes through the router, and incoming
     and outgoing of frames are done based on control plane logic.
     Data plane is moving the actual packets based on what we learned from
     control plane.

#. Q: What's user space Network?

   A: User space network software takes exclusive control of a network adapter,
   implements the whole NIC driver and develops packet processing framework
   completely in user space.

   There are several primary reasons to move the networking functionalities
   from the kernel to user space:

   * Reduce the number of context switches required to process packet data, as
     each syscall causes a context switch, which takes up time and resources.

   * Reduce the amount of software on the stack. Linux kernel provides
     abstractions, which are designed for general purpose and could be quite
     complicated in implementing packet processing. Customized
     implementation could remove unnecessary abstractions, simplify the logic,
     and improve performance.

   * User space drivers are easier to develop and debug than kernel drivers.
     Developing networking functions and getting it merge in mainline kernel
     would take considerable time and effort. Moreover, the function release
     would be bounded by Linux’s release schedule. Finally, bugs in the source
     code may cause the kernel to crash.

   The user space networking ecosystems has really matured since some user space
   networking projects are open sourced, e.g.,
   `DPDK <https://www.dpdk.org/>`_,
   `VPP <https://fd.io/>`_,
   `Snort <https://www.snort.org/>`_.
   A whole ecosystem of technologies developed based on user space network
   software has emerged.

#. Q: How to install Mellanox ConnectX-5 OFED driver and update NIC firmware?

   A: To use Mellanox NIC, firstly install the OFED driver `MLNX_OFED <https://docs.nvidia.com/networking/display/MLNXOFEDv551032/Installing+MLNX_OFED>`_,
   and then `update NIC Firmware <https://docs.nvidia.com/networking/display/MLNXOFEDv551032/Updating+Firmware+After+Installation>`_.

   The key steps are:

   * Download the `OFED driver <http://www.mellanox.com/page/mlnx_ofed_eula?mtag=linux_sw_drivers&mrequest=downloads&mtype=ofed&mver=MLNX_OFED-5.4-3.1.0.0&mname=MLNX_OFED_LINUX-5.4-3.1.0.0-ubuntu20.04-aarch64.iso>`_

   * Install OFED driver::

        $ sudo mount -o ro,loop MLNX_OFED_LINUX-5.4-3.1.0.0-ubuntu20.04-aarch64.iso /mnt
        $ sudo /mnt/mlnxofedinstall --upstream-libs --dpdk

   * Update firmware after OFED installation::

        $ wget https://www.mellanox.com/downloads/MFT/mft-4.20.0-34-arm64-deb.tgz
        $ tar xvf mft-4.20.0-34-arm64-deb.tgz
        $ cd mft-4.20.0-34-arm64-deb/
        $ sudo ./install.sh
        $ sudo mst start
        $ sudo mlxfwmanager --online -u -d <device PCIe address>
