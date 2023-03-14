..
  # Copyright (c) 2023, Arm Limited.
  #
  # SPDX-License-Identifier: Apache-2.0

###################
VPP TCP Termination
###################

************
Introduction
************

VPP's host stack is a user space implementation of a number of transport,
session and application layer protocols. It leverages VPP’s graph based
forwarding model and vectorized packet processing to ensure high throughput
and scale transport protocol termination.

`iperf3`_ is a tool for active measurements of the maximum achievable bandwidth
on IP networks. In this guide it is used to measure the maximum attainable goodput
of the VPP's host stack on DUT node.

This guide explains in detail on how to integrate iperf3 with VPP's host stack
for tcp termination cases. The integration is done via LD_PRELOAD which
intercepts syscalls that are supposed to go into the kernel and reinjects
them into VPP. Users can execute bundled scripts in dataplane-stack repo to quickly
establish the tcp termination cases or manually run the use cases by following
detailed guidelines step by step.

First, ensure the proper VPP binaries path. To use VPP in dataplane-stack project
build system directory, run:

.. code-block:: shell

        export vpp_binary="<nw_ds_workspace>/dataplane-stack/components/vpp/build-root/install-vpp-native/vpp/bin/vpp"
        export vppctl_binary="<nw_ds_workspace>/dataplane-stack/components/vpp/build-root/install-vpp-native/vpp/bin/vppctl"
        export LDP_PATH="<nw_ds_workspace>/dataplane-stack/components/vpp/build-root/install-vpp-native/vpp/lib/aarch64-linux-gnu/libvcl_ldpreload.so"

To use package installed VPP (e.g. ``apt``, ``buildroot``) available in system ``PATH``, run:

.. code-block:: shell

        export vpp_binary="vpp"
        export vppctl_binary="vppctl"
        export LDP_PATH="/system_lib_path/libvcl_ldpreload.so"

.. note::
        The system lib path can be ``/usr/lib`` or ``/usr/lib/aarch64-linux-gnu``.

********************
Network Stack Layers
********************

.. figure:: ../images/kernel-vpp-stack.png
   :align: center

   Linux kernel stack VS VPP's host stack.

VPP's host stack provides alternatives to kernel-based sockets so that applications
can take full advantage of VPP's high performance. It implements a clean slate TCP
that supports vectorized packet processing and follows VPP’s highly scalable threading
model. The implementation is RFC compliant, supports a high number of high-speed TCP
protocol features. VPP's host stack also provides a transport pluggable session layer
that abstracts the interaction between applications and transports using a custom-built
shared memory infrastructure.

This guide demonstrates two kinds of iperf3 connection:

- Loopback connection on DUT node
- DPDK ethernet connection between DUT and client nodes

*******************
Loopback Connection
*******************

The loopback interface is a software virtual interface that is always up and available
after it has been configured. In this setup, both iperf3 server and client run over VPP's
host stack on DUT and communicate with each other through VPP loopback interfaces.

.. figure:: ../images/tcp_term_loop.png
   :align: center
   :width: 400

    Loopback connection

.. note::
        This setup requires three isolated cores. Cores 1-3 are assumed to be
        isolated in this guide.

Automated Execution
===================

Quickly setup VPP & iperf3 and test tcp termination use case:

.. code-block:: shell

        cd <nw_ds_workspace>/dataplane-stack
        ./usecase/tcp_term/run_vpp_hs.sh -l -c 1
        ./usecase/tcp_term/run_iperf3_server.sh -l -c 2
        ./usecase/tcp_term/run_iperf3_client.sh -c 3

.. note::
        Run ``./usecase/tcp_term/run_vpp_hs.sh --help`` for all supported options.

If the case runs successfully, the measurement results will be printed:

.. code-block:: none

        Connecting to host 172.16.1.1, port 5201
        [ 33] local 172.16.2.1 port 43757 connected to 172.16.1.1 port 5201
        [ ID] Interval           Transfer     Bitrate         Retr         Cwnd
        [ 33]   0.00-1.00   sec  2.23 GBytes  19.2 Gbits/sec  65535        555 MBytes
        [ 33]   1.00-2.00   sec  2.23 GBytes  19.2 Gbits/sec  4294901761   0.00 Bytes
        [ 33]   2.00-3.00   sec  2.23 GBytes  19.1 Gbits/sec  65535        555 MBytes
        [ 33]   3.00-4.00   sec  2.23 GBytes  19.2 Gbits/sec    0          555 MBytes
        [ 33]   4.00-5.00   sec  2.23 GBytes  19.2 Gbits/sec  4294901761   0.00 Bytes
        [ 33]   5.00-6.00   sec  2.23 GBytes  19.2 Gbits/sec  65535        555 MBytes
        [ 33]   6.00-7.00   sec  2.23 GBytes  19.2 Gbits/sec  4294901761   0.00 Bytes
        [ 33]   7.00-8.00   sec  2.23 GBytes  19.2 Gbits/sec  65535        555 MBytes
        [ 33]   8.00-9.00   sec  2.23 GBytes  19.2 Gbits/sec    0          555 MBytes
        [ 33]   9.00-10.00  sec  2.23 GBytes  19.2 Gbits/sec    0          -1874590816.00 Bytes
        - - - - - - - - - - - - - - - - - - - - - - - - -
        [ ID] Interval           Transfer     Bitrate         Retr
        [ 33]   0.00-10.00  sec  22.3 GBytes  19.2 Gbits/sec  65535             sender
        [ 33]   0.00-10.00  sec  22.3 GBytes  19.2 Gbits/sec                  receiver

.. note::
        VPP's host stack doesn't support tcp socket option ``TCP_INFO`` to get tcp
        connection information, so ``Retr`` and ``Cwnd`` columns in above output are meaningless.

Stop VPP and iperf3:

.. code-block:: shell

        ./usecase/tcp_term/stop.sh

Manual Execution
================

Users can also setup VPP & iperf3 and test tcp termination case step by step.

VPP Setup
~~~~~~~~~

Declare a variable to hold the cli socket for VPP:

.. code-block:: shell

        export sockfile="/run/vpp/cli.sock"

Start VPP as a daemon on core 1 with session enabled. For more configuration parameters,
refer to `VPP configuration reference`_:

.. code-block:: shell

        sudo ${vpp_binary} unix {cli-listen ${sockfile}} cpu {main-core 1 workers 0} tcp {cc-algo cubic} session {enable use-app-socket-api}

Create loopback interfaces and routes by following VPP commands:

.. code-block:: shell

        sudo ${vppctl_binary} -s ${sockfile} create loopback interface
        sudo ${vppctl_binary} -s ${sockfile} set interface state loop0 up
        sudo ${vppctl_binary} -s ${sockfile} create loopback interface
        sudo ${vppctl_binary} -s ${sockfile} set interface state loop1 up
        sudo ${vppctl_binary} -s ${sockfile} ip table add 1
        sudo ${vppctl_binary} -s ${sockfile} set interface ip table loop0 1
        sudo ${vppctl_binary} -s ${sockfile} ip table add 2
        sudo ${vppctl_binary} -s ${sockfile} set interface ip table loop1 2
        sudo ${vppctl_binary} -s ${sockfile} set interface ip address loop0 172.16.1.1/24
        sudo ${vppctl_binary} -s ${sockfile} set interface ip address loop1 172.16.2.1/24
        sudo ${vppctl_binary} -s ${sockfile} app ns add id server secret 1234 sw_if_index 1
        sudo ${vppctl_binary} -s ${sockfile} app ns add id client secret 5678 sw_if_index 2
        sudo ${vppctl_binary} -s ${sockfile} ip route add 172.16.1.1/32 table 2 via lookup in table 1
        sudo ${vppctl_binary} -s ${sockfile} ip route add 172.16.2.1/32 table 1 via lookup in table 2

For more detailed usage on above commands, refer to following links,

- `VPP set interface ip address reference`_
- `VPP set interface state reference`_
- `VPP app ns reference`_
- `VPP ip route reference`_

Create two vcl configuration files for iperf3 instances.

- For server instance ``vcl_iperf3_server_lb.conf``:

.. code-block:: none

        vcl {
          rx-fifo-size 4000000
          tx-fifo-size 4000000
          namespace-id server
          namespace-secret 1234
          app-scope-global
          app-socket-api /var/run/vpp/app_ns_sockets/server
        }

- For client instance ``vcl_iperf3_client.conf``:

.. code-block:: none

        vcl {
          rx-fifo-size 4000000
          tx-fifo-size 4000000
          namespace-id client
          namespace-secret 5678
          app-scope-global
          app-socket-api /var/run/vpp/app_ns_sockets/client
        }

The above configure vcl to request 4MB receive and transmit fifo sizes and
access to global session scope. Additionally, they provide the path to session
layer's different app namespace socket for iperf3 client and server instances.
For more vcl parameters usage, refer to `VPP vcl reference`_.

Test
~~~~

Start the iperf3 server on core 2 as a daemon over VPP's host stack:

.. code-block:: shell

        sudo taskset -c 2 sh -c "LD_PRELOAD=${LDP_PATH} VCL_CONFIG=/path/to/vcl_iperf3_server_lb.conf iperf3 -4 -s -D"

To examine the iperf3 server session in VPP, use the command ``sudo ${vppctl_binary} -s ${sockfile} show session verbose``.
Here is a sample output for iperf3 server session:

.. code-block:: none

        Connection                                                  State          Rx-f      Tx-f
        [0:0][T] 172.16.1.1:5201->0.0.0.0:0                         LISTEN         0         0
        Thread 0: active sessions 1

Start the iperf3 client on core 3 over VPP's host stack to connect to iperf3 server:

.. code-block:: shell

        sudo taskset -c 3 sh -c "LD_PRELOAD=${LDP_PATH} VCL_CONFIG=/path/to/vcl_iperf3_client.conf iperf3 -c 172.16.1.1"

If both iperf3 client and server run successfully, iperf3 client will output
similar results as in the script running section.

For more detailed iperf3 usage, refer to `iperf3 usage reference`_

Stop
~~~~

Kill VPP:

.. code-block:: shell

        $ sudo pkill -9 vpp

Kill iperf3 server:

.. code-block:: shell

        $ sudo pkill -9 iperf3

************************
DPDK Ethernet Connection
************************

In this tcp termination scenario, iperf3 server and client run on separated hardware
platforms and are connected with ethernet adaptors and cables. iperf3 server runs over
VPP's host stack on DUT, and iperf3 client runs over Linux kernel stack on client node.

.. figure:: ../images/tcp_term_dpdk.png
   :align: center
   :width: 400

    Ethernet connection

To find out which DUT interface is connected with client node,
``sudo ethtool --identify <interface_name>`` will typically blink a light on the
NIC to help identify the physical port associated with the interface.

Get interface name and PCIe address from ``lshw`` command:

.. code-block:: shell

        sudo lshw -c net -businfo

.. code-block:: none

        Bus info          Device      Class      Description
        ====================================================
        pci@0000:07:00.0  eth0        network    RTL8111/8168/8411 PCI Express Gigabit Ethernet Controller
        pci@0001:01:00.0  enP1p1s0f0  network    MT27800 Family [ConnectX-5]
        pci@0001:01:00.1  enP1p1s0f1  network    MT27800 Family [ConnectX-5]

In this setup example, ``enP1p1s0f0`` at PCIe address ``0001:01:00.0`` is used to
connect with client node. The IP address of this NIC interface in VPP is configured
as 1.1.1.2/30. The IP address of client node is 1.1.1.1/30.

Automated Execution
===================

Quickly setup VPP and iperf3 server on DUT:

.. code-block:: shell

        cd <nw_ds_workspace>/dataplane-stack
        ./usecase/tcp_term/run_dut.sh -p 0001:01:00.0 -c 1
        ./usecase/tcp_term/run_iperf3_server.sh -p -c 2

.. note::
        Use interface PCIe address on DUT to replace sample address in above example.

On client node start the iperf3 client to connect to iperf3 server on DUT:

.. code-block:: shell

        sudo taskset -c 1 iperf3 -c 1.1.1.2

If both iperf3 client and server run successfully, the measurement results will be printed by iperf3 client:

.. code-block:: none

        Connecting to host 1.1.1.2, port 5201
        [  5] local 1.1.1.1 port 59118 connected to 1.1.1.2 port 5201
        [ ID] Interval           Transfer     Bitrate         Retr  Cwnd
        [  5]   0.00-1.00   sec  1.85 GBytes  15.9 Gbits/sec  183   1.39 MBytes
        [  5]   1.00-2.00   sec  1.85 GBytes  15.9 Gbits/sec   44   1.37 MBytes
        [  5]   2.00-3.00   sec  1.85 GBytes  15.9 Gbits/sec   26   1.35 MBytes
        [  5]   3.00-4.00   sec  1.85 GBytes  15.9 Gbits/sec   33   1.54 MBytes
        [  5]   4.00-5.00   sec  1.85 GBytes  15.9 Gbits/sec   42   1.64 MBytes
        [  5]   5.00-6.00   sec  1.84 GBytes  15.8 Gbits/sec  110   1.35 MBytes
        [  5]   6.00-7.00   sec  1.85 GBytes  15.9 Gbits/sec   24   1.54 MBytes
        [  5]   7.00-8.00   sec  1.84 GBytes  15.8 Gbits/sec   35   1.38 MBytes
        [  5]   8.00-9.00   sec  1.85 GBytes  15.9 Gbits/sec   27   1.21 MBytes
        [  5]   9.00-10.00  sec  1.85 GBytes  15.9 Gbits/sec   21   1.41 MBytes
        - - - - - - - - - - - - - - - - - - - - - - - - -
        [ ID] Interval           Transfer     Bitrate         Retr
        [  5]   0.00-10.00  sec  18.5 GBytes  15.9 Gbits/sec  545             sender
        [  5]   0.00-10.00  sec  18.5 GBytes  15.9 Gbits/sec                  receiver

Stop VPP and iperf3:

.. code-block:: shell

        ./usecase/tcp_term/stop.sh

Manual Execution
================

Users can also setup VPP & iperf3 and test tcp termination case step by step.

VPP Setup
~~~~~~~~~

Declare a variable to hold the cli socket for VPP:

.. code-block:: shell

        export sockfile="/run/vpp/cli.sock"

Start VPP as a daemon on core 1 with interface PCIe address and session enabled:

.. code-block:: shell

        sudo ${vpp_binary} unix {cli-listen ${sockfile}} cpu {main-core 1 workers 0} tcp {cc-algo cubic} dpdk {dev 0000:01:00.0 {name eth0}} session {enable use-app-socket-api}

Bring VPP ethernet interface up and set ip address:

.. code-block:: shell

        sudo ${vppctl_binary} -s ${sockfile} set interface state eth0 up
        sudo ${vppctl_binary} -s ${sockfile} set interface ip address eth0 1.1.1.2/30

Create a VCL configuration file for iperf3 server instance ``vcl_iperf3_server_pn.conf``:

.. code-block:: none

        vcl {
          rx-fifo-size 4000000
          tx-fifo-size 4000000
          app-scope-global
          app-socket-api /var/run/vpp/app_ns_sockets/default
        }

The above configures vcl to request 4MB receive and transmit fifo sizes and access
to global session scope. For more vcl parameters usage, refer to `VPP vcl reference`_.

Start the iperf3 server on core 2 as a daemon over VPP's host stack:

.. code-block:: shell

        sudo taskset -c 2 sh -c "LD_PRELOAD=${LDP_PATH} VCL_CONFIG=/path/to/vcl_iperf3_server_pn.conf iperf3 -4 -s -D"

Test
~~~~

On client node run the iperf3 client to connect to the iperf3 server on DUT:

.. code-block:: shell

        sudo taskset -c 1 iperf3 -c 1.1.1.2

If both iperf3 client and server run successfully, iperf3 client will output
similar results as in the script running section.

Stop
~~~~

Kill VPP:

.. code-block:: shell

        sudo pkill -9 vpp

Kill iperf3 server:

.. code-block:: shell

        sudo pkill -9 iperf3

*********************
Suggested Experiments
*********************

For jumbo packets, increase VPP tcp mtu and buffer size to improve the performance.
Below is VPP example config:

.. code-block:: none

        tcp {
            cc-algo cubic
            mtu 9000
        }
        buffers {
            default data-size 10000
        }

*********
Resources
*********

#. `VPP configuration reference <https://s3-docs.fd.io/vpp/23.02/configuration/reference.html>`_
#. `VPP set interface ip address reference <https://s3-docs.fd.io/vpp/23.02/cli-reference/clis/clicmd_src_vnet_ip.html#set-interface-ip-address>`_
#. `VPP set interface state reference <https://s3-docs.fd.io/vpp/23.02/cli-reference/clis/clicmd_src_vnet.html#set-interface-state>`_
#. `VPP ip route reference <https://s3-docs.fd.io/vpp/23.02/cli-reference/clis/clicmd_src_vnet_ip.html#ip-route>`_
#. `VPP app ns reference <https://s3-docs.fd.io/vpp/23.02/cli-reference/clis/clicmd_src_vnet_session.html#app-ns>`_
#. `VPP cli reference <https://s3-docs.fd.io/vpp/23.02/cli-reference/index.html>`_
#. `VPP vcl reference <https://wiki.fd.io/view/VPP/HostStack/VCL>`_
#. `iperf3 <https://github.com/esnet/iperf>`_
#. `iperf3 usage reference <https://software.es.net/iperf/invoking.html>`_
