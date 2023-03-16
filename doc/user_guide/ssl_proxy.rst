..
  # Copyright (c) 2023, Arm Limited.
  #
  # SPDX-License-Identifier: Apache-2.0

#################
SSL REVERSE PROXY
#################

************
Introduction
************

A proxy server is a intermediary server that forwards requests for content from
clients to servers across network. A SSL reverse proxy is a type of proxy server
that controls Secure Sockets Layer – SSL traffic – to ensure secure transmission
of data between clients and servers. It acts as an intermediary, performing SSL
encryption and decryption between the client and the server. For client, it acts
as a server. For server, it acts as a client.

wrk2 is a modern HTTP benchmarking tool capable of generating significant load
when run on a single multi-core CPU. NGINX is open source software for web
serving, reverse proxying, caching, load balancing, media streaming, and more.

This guide explains in detail on how to integrate wrk2 and NGINX with VPP's
host stack for ssl proxy cases. The integration is done via LD_PRELOAD which
intercepts syscalls that are supposed to go into the kernel and reinjects
them into VPP. Users can execute bundled scripts in dataplane-stack repo to quickly
establish the ssl proxy cases or manually run the use cases by following detailed
guidelines step by step.

********************
Network Stack Layers
********************

.. figure:: ../images/nginx_kernel_vpp_stack.png
   :align: center

   Linux kernel stack VS VPP's host stack

VPP's host stack provides alternatives to kernel-based sockets so that applications
can take full advantage of VPP's high performance. It implements a clean slate TCP
that supports vectorized packet processing and follows VPP’s highly scalable threading
model. The implementation is RFC compliant, supports a high number of high-speed TCP
protocol features. VPP's host stack also provides a transport pluggable session layer
that abstracts the interaction between applications and transports using a custom-built
shared memory infrastructure.

This guide demonstrates two kinds of ssl proxy connection:

- Loopback connection on DUT node
- Ethernet connection between DUT and client/server nodes

*******************
Loopback Connection
*******************

The loopback interface is a software virtual interface that is always up and available
after it has been configured. In this setup, NGINX https server, NGINX reverse proxy
and wrk2 client run over VPP's host stack on DUT and communicate with each other
through VPP loopback interfaces.

.. figure:: ../images/ssl_proxy_loop.png
   :align: center
   :width: 800

   Loopback connection

.. note::
        This setup requires four isolated cores. Cores 1-4 are assumed to be
        isolated in this guide.

Automated Execution
===================

Quickly set up VPP & NGINX and test ssl reverse proxy case:

.. code-block:: shell

        cd <nw_ds_workspace>/dataplane-stack
        ./usecase/ssl_proxy/run_vpp.sh -l -c 1
        ./usecase/ssl_proxy/run_nginx_server.sh -l -c 2
        ./usecase/ssl_proxy/run_nginx_proxy.sh -c 3 
        ./usecase/ssl_proxy/run_wrk2.sh -c 4 

.. note::
        You will be asked a series of questions in order to embed the information
        correctly in the certificate. Fill out the prompts appropriately.

.. note::
        Run ``./usecase/ssl_proxy/run_vpp.sh --help`` for all supported options.

If the case runs successfully, the measurement results will be printed:

.. code-block:: none

        Initialised 1 threads in 0 ms.
        Running 10s test @ https://172.16.2.1:8089/1kb
          1 threads and 10 connections
          Thread Stats   Avg      Stdev     Max   +/- Stdev
            Latency     5.00s     2.87s    9.99s    57.76%
            Req/Sec        nan       nan   0.00      0.00%
          750658 requests in 10.00s, 0.89GB read
        Requests/sec:  75065.43
        Transfer/sec:     91.49MB

Stop VPP and NGINX:

.. code-block:: shell

        ./usecase/ssl_proxy/stop.sh

Manual Execution
================

Users can also set up VPP & NGINX and test ssl reverse proxy case step by step.

VPP Setup
~~~~~~~~~

Declare a variable to hold the cli socket for VPP:

.. code-block:: shell

        export sockfile="/run/vpp/cli.sock"

Run VPP as a daemon on core 1 with session layer enabled.

.. code-block:: shell

        sudo ./vpp unix {cli-listen ${sockfile}} cpu {main-core 1} tcp {cc-algo cubic} session {enable use-app-socket-api}

For more configuration parameters, refer to `VPP configuration reference`_.

Create loopback interfaces and routes by following VPP commands:

.. code-block:: shell

        sudo ./vppctl -s ${sockfile} create loopback interface
        sudo ./vppctl -s ${sockfile} set interface state loop0 up
        sudo ./vppctl -s ${sockfile} create loopback interface
        sudo ./vppctl -s ${sockfile} set interface state loop1 up
        sudo ./vppctl -s ${sockfile} create loopback interface
        sudo ./vppctl -s ${sockfile} set interface state loop2 up
        sudo ./vppctl -s ${sockfile} ip table add 1
        sudo ./vppctl -s ${sockfile} set interface ip table loop0 1
        sudo ./vppctl -s ${sockfile} ip table add 2
        sudo ./vppctl -s ${sockfile} set interface ip table loop1 2
        sudo ./vppctl -s ${sockfile} ip table add 3
        sudo ./vppctl -s ${sockfile} set interface ip table loop2 3
        sudo ./vppctl -s ${sockfile} set interface ip address loop0 172.16.1.1/24
        sudo ./vppctl -s ${sockfile} set interface ip address loop1 172.16.2.1/24
        sudo ./vppctl -s ${sockfile} set interface ip address loop2 172.16.3.1/24
        sudo ./vppctl -s ${sockfile} app ns add id server secret 1234 if loop0
        sudo ./vppctl -s ${sockfile} app ns add id proxy secret 1234 if loop1
        sudo ./vppctl -s ${sockfile} app ns add id client secret 1234 if loop2
        sudo ./vppctl -s ${sockfile} ip route add 172.16.1.1/32 table 2 via lookup in table 1
        sudo ./vppctl -s ${sockfile} ip route add 172.16.3.1/32 table 2 via lookup in table 3
        sudo ./vppctl -s ${sockfile} ip route add 172.16.2.1/32 table 1 via lookup in table 2
        sudo ./vppctl -s ${sockfile} ip route add 172.16.2.1/32 table 3 via lookup in table 2

For more detailed usage on above commands, refer to the following links,

- `VPP set interface ip address reference`_
- `VPP set interface state reference`_
- `VPP ip route reference`_
- `VPP app ns reference`_

Create VCL configuration files for NGINX instances and wrk2.

- For NGINX https server ``vcl_nginx_server.conf``:

.. code-block:: none

        vcl {
          heapsize 64M
          segment-size 4000000000
          add-segment-size 4000000000
          rx-fifo-size 4000000
          tx-fifo-size 4000000
          namespace-id server
          namespace-secret 1234
          app-scope-global
          app-socket-api /var/run/vpp/app_ns_sockets/server
        }

- For NGINX reverse proxy ``vcl_nginx_proxy.conf``:

.. code-block:: none

        vcl {
          heapsize 64M
          segment-size 4000000000
          add-segment-size 4000000000
          rx-fifo-size 4000000
          tx-fifo-size 4000000
          namespace-id proxy
          namespace-secret 1234
          app-scope-global
          app-socket-api /var/run/vpp/app_ns_sockets/proxy
        }

- For wrk2 https client ``vcl_wrk2.conf``:

.. code-block:: none

        vcl {
          heapsize 64M
          segment-size 4000000000
          add-segment-size 4000000000
          rx-fifo-size 4000000
          tx-fifo-size 4000000
          namespace-id client
          namespace-secret 1234
          use-mq-eventfd
          app-scope-global
          app-socket-api /var/run/vpp/app_ns_sockets/client
        }

The above configure VCL to request 4MB receive and transmit fifo sizes and access
to global session scope. Additionally, they provide the path to session layer's
different app namespace socket for NGINX instances and wrk2. For more VCL parameters
usage, refer to `VPP vcl reference`_.

NGINX Setup
~~~~~~~~~~~

Create ssl private keys and certificates for NGINX https server and reverse proxy:

.. code-block:: shell

        sudo mkdir -p /etc/nginx/certs
        sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/nginx/certs/server.key -out /etc/nginx/certs/server.crt
        sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/nginx/certs/proxy.key -out /etc/nginx/certs/proxy.crt

.. note::

        You will be asked a series of questions in order to embed the information
        correctly in the certificate. Fill out the prompts appropriately.

Create NGINX config file ``nginx_server.conf`` for NGINX https server:

.. code-block:: none

        worker_processes 1;
        pid /run/nginx_server.pid;

        events {}

        http {
                sendfile on;
                tcp_nopush on;
                keepalive_requests 1000000000;

                default_type application/octet-stream;

                access_log off;
                error_log /dev/null crit;

                server {
                        listen 8445 ssl;
                        server_name $hostname;
                        ssl_protocols TLSv1.3;
                        ssl_prefer_server_ciphers on;
                        ssl_certificate /etc/nginx/certs/server.crt;
                        ssl_certificate_key /etc/nginx/certs/server.key;
                        ssl_conf_command Ciphersuites TLS_AES_128_GCM_SHA256;
                        root /var/www/html;

                        location / {
                                try_files $uri $uri/ =404;
                        }
                }
        }

Create NGINX config file ``nginx_proxy.conf`` for NGINX reverse proxy:

.. code-block:: none

        worker_processes 1;
        pid /run/nginx_proxy.pid;

        events {}

        http {
                sendfile on;
                tcp_nopush on;
                keepalive_requests 1000000000;

                default_type application/octet-stream;

                access_log off;
                error_log /dev/null crit;

                upstream ssl_file_server_com {
                        server 172.16.1.1:8445;
                        keepalive 1024;
                }

                server {
                        listen 8089 ssl;
                        server_name $hostname;
                        ssl_protocols TLSv1.3;
                        ssl_prefer_server_ciphers on;
                        ssl_certificate /etc/nginx/certs/proxy.crt;
                        ssl_certificate_key /etc/nginx/certs/proxy.key;
                        ssl_conf_command Ciphersuites TLS_AES_128_GCM_SHA256;

                        location / {
                                limit_except GET {
                                deny all;
                                }
                                proxy_pass https://ssl_file_server_com;
                                proxy_http_version 1.1;
                                proxy_set_header Connection "";
                                proxy_ssl_protocols TLSv1.3;
                        }
                }
        }

.. note::
        The https server ip address should be used as the upstream server in ``nginx_proxy.conf`` file.

For more detailed usage on above NGINX configuration, refer to the following links,

- `nginx core functionality reference`_
- `nginx http core module reference`_
- `nginx http upstream module reference`_
- `nginx http proxy module reference`_
- `nginx http ssl module reference`_

Create a 1kb file in NGINX https server root directory for downloading:

.. code-block:: shell

        sudo mkdir -p /var/www/html
        sudo dd if=/dev/urandom of=/var/www/html/1kb bs=1024 count=1

Declare a variable to hold the VPP library for ``LD_PRELOAD``:

.. code-block:: shell

        export LDP_PATH="<nw_ds_workspace>/dataplane-stack/components/vpp/build-root/install-vpp-native/vpp/lib/aarch64-linux-gnu/libvcl_ldpreload.so"

Start NGINX https server on core 2 over VPP's host stack:

.. code-block:: shell

        sudo taskset -c 2 sh -c "LD_PRELOAD=${LDP_PATH} VCL_CONFIG=/path/to/vcl_nginx_server.conf nginx -c /path/to/nginx_server.conf"

Start NGINX reverse proxy on core 3 over VPP's host stack:

.. code-block:: shell

        sudo taskset -c 3 sh -c "LD_PRELOAD=${LDP_PATH} VCL_CONFIG=/path/to/vcl_nginx_proxy.conf nginx -c /path/to/nginx_proxy.conf"

To examine the NGINX sessions in VPP, use the command ``sudo ./vppctl -s ${sockfile} show session verbose``.
Here is a sample output for NGINX sessions:

.. code-block:: none

        Connection                                                  State          Rx-f      Tx-f
        [0:0][T] 172.16.2.1:8089->0.0.0.0:0                         LISTEN         0         0
        [0:1][T] 172.16.1.1:8445->0.0.0.0:0                         LISTEN         0         0
        Thread 0: active sessions 2

Test
~~~~

If wrk2 is not installed, first download, patch and build wrk2 for aarch64 platform:

.. code-block:: shell

        cd <nw_ds_workspace>/dataplane-stack/components
        git clone https://github.com/AmpereTravis/wrk2-aarch64.git
        cd wrk2-aarch64
        git am <nw_ds_workspace>/dataplane-stack/patches/wrk2/0001-wrk2-fd-vpp.patch
        make all

Run wrk2 client on core 4 over VPP's host stack to test ssl reverse proxy with 1kb
file downloading:

.. code-block:: shell

        sudo taskset -c 4 sh -c "LD_PRELOAD=${LDP_PATH} VCL_CONFIG=/path/to/vcl_wrk2.conf ./wrk --rate 100000000 -t 1 -c 10 -d 10s https://172.16.2.1:8089/1kb"

.. note::
        Extremely high rate (--rate) is used to ensure throughput is measured.
        Number of connections (-c) is set to 10 to produce high throughput.
        Test duration (-d) is 10 seconds.
        Url is NGINX reverse proxy's url.

If both wrk2 and NGINX run successfully, wrk2 will output measurement result similar
to the following:

.. code-block:: none

        Initialised 1 threads in 0 ms.
        Running 10s test @ https://172.16.2.1:8089/1kb
          1 threads and 10 connections
          Thread Stats   Avg      Stdev     Max   +/- Stdev
            Latency     5.00s     2.87s    9.99s    57.76%
            Req/Sec        nan       nan   0.00      0.00%
          750658 requests in 10.00s, 0.89GB read
        Requests/sec:  75065.43
        Transfer/sec:     91.49MB

Stop
~~~~

Kill VPP:

.. code-block:: shell

        sudo pkill -9 vpp

Kill NGINX instances:

.. code-block:: shell

        sudo pkill -9 nginx

*******************
Ethernet Connection
*******************

In this ssl reverse proxy scenario, NGINX https server, NGINX reverse proxy and
wrk2 https client run on separated hardware platforms. The DUT has one NIC interface
connected with the server node, and another NIC interface connected with the client node.
NGINX reverse proxy runs over VPP's host stack on DUT. NGINX https server runs over Linux
kernel stack on server node. wrk2 https client runs over Linux kernel stack on client node.

.. figure:: ../images/ssl_proxy_dpdk.png
        :align: center
        :width: 800

    Ethernet connection

To find out which DUT interfaces are connected with https client/server nodes,
``sudo ethtool --identify <interface_name>`` will typically blink a light on the
NIC to help identify the physical port associated with the interface.

Get interface names and PCIe addresses from ``lshw`` command:

.. code-block:: shell

        sudo lshw -c net -businfo

The output will look similar to:

.. code-block:: none

        Bus info          Device      Class      Description
        ====================================================
        pci@0000:07:00.0  eth0        network    RTL8111/8168/8411 PCI Express Gigabit Ethernet Controller
        pci@0001:01:00.0  enP1p1s0f0  network    MT27800 Family [ConnectX-5]
        pci@0001:01:00.1  enP1p1s0f1  network    MT27800 Family [ConnectX-5]

In this setup example, ``enP1p1s0f0`` at PCIe address ``0001:01:00.0`` is used to
connect with the client node. The IP address of this NIC interface in VPP is configured
as 172.16.2.1/24. The IP address of client node is 172.16.2.2/24. ``enP1p1s0f1`` at PCIe
address ``0001:01:00.1`` is used to connect with the server node. The IP address of this
NIC interface in VPP is configured as 172.16.1.2/24. The IP address of server node
is 172.16.1.1/24.

Automated Execution
===================

Quickly set up VPP and NGINX reverse proxy on DUT:

.. code-block:: shell

        cd <nw_ds_workspace>/dataplane-stack
        ./usecase/ssl_proxy/run_vpp.sh -p 0001:01:00.0,0001:01:00.1 -c 1
        ./usecase/ssl_proxy/run_nginx_proxy.sh -c 2 

.. note::
        Replace sample addresses in above command with desired PCIe addresses on DUT.

.. note::
        You will be asked a series of questions in order to embed the information
        correctly in the certificate. Fill out the prompts appropriately.

On server node start NGINX https server:

.. code-block:: shell

        cd <nw_ds_workspace>/dataplane-stack
        ./usecase/ssl_proxy/run_nginx_server.sh -p

On client node download, build and run wrk2 to test ssl reverse proxy:

.. code-block:: shell

        x86: git clone https://github.com/giltene/wrk2.git && cd wrk2
        OR
        aarch64: git clone https://github.com/AmpereTravis/wrk2-aarch64.git && cd wrk2-aarch64
        make all
        sudo taskset -c 1 ./wrk --rate 100000000 -t 1 -c 10 -d 10s https://172.16.2.1:8089/1kb"
 
If the case runs successfully, the measurement results will be printed by wrk2 client:

.. code-block:: none

        Initialised 1 threads in 0 ms.
        Running 10s test @ https://172.16.2.1:8089/1kb
          1 threads and 10 connections
          Thread Stats   Avg      Stdev     Max   +/- Stdev
            Latency     5.01s     2.88s    9.99s    57.66%
            Req/Sec        nan       nan   0.00      0.00%
          424079 requests in 10.00s, 516.87MB read
        Requests/sec:  42406.22
        Transfer/sec:     51.68MB

Stop VPP and NGINX on DUT:

.. code-block:: shell

        ./usecase/ssl_proxy/stop.sh

Stop NGINX on server node:

.. code-block:: shell

        ./usecase/ssl_proxy/stop.sh

Manual Execution
================

Users can also set up VPP & NGINX and test ssl reverse proxy case step by step.

VPP Setup
~~~~~~~~~

Declare a variable to hold the cli socket for VPP:

.. code-block:: shell

        export sockfile="/run/vpp/cli.sock"

Run VPP as a daemon on core 1 with interface PCIe addresses and session layer enabled:

.. code-block:: shell

        cd <nw_ds_workspace>/dataplane-stack/components/vpp/build-root/install-vpp-native/vpp/bin
        sudo ./vpp unix {cli-listen ${sockfile}} cpu {main-core 1} tcp {cc-algo cubic} dpdk {dev 0000:01:00.0 {name eth0} dev 0000:01:00.1 {name eth1}} session {enable use-app-socket-api}

.. note::
        Replace sample addresses in above command with desired PCIe addresses on DUT.

Bring two VPP ethernet interfaces up and set ip addresses:

.. code-block:: shell

        sudo ./vppctl -s ${sockfile} set interface state eth0 up
        sudo ./vppctl -s ${sockfile} set interface ip address eth0 172.16.2.1/24
        sudo ./vppctl -s ${sockfile} set interface state eth1 up
        sudo ./vppctl -s ${sockfile} set interface ip address eth1 172.16.1.2/24

Create a VCL configuration file for NGINX reverse proxy ``vcl_nginx_proxy_pn.conf``:

.. code-block:: none

        vcl {
          heapsize 64M
          segment-size 4000000000
          add-segment-size 4000000000
          rx-fifo-size 4000000
          tx-fifo-size 4000000
          app-socket-api /var/run/vpp/app_ns_sockets/default
        }

The above configures VCL to request 4MB receive and transmit fifo sizes and 
provides the path to vpp's session layer socket api. For more VCL parameters
usage, refer to `VPP vcl reference`_.

NGINX Setup on DUT
~~~~~~~~~~~~~~~~~~

Create ssl private key and certificate for NGINX reverse proxy:

.. code-block:: shell

        sudo mkdir -p /etc/nginx/certs
        sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/nginx/certs/proxy.key -out /etc/nginx/certs/proxy.crt

.. note::
        You will be asked a series of questions in order to embed the information
        correctly in the certificate. Fill out the prompts appropriately.

Create NGINX config file ``nginx_proxy.conf`` for NGINX reverse proxy. It is same
as the ``nginx_proxy.conf`` in loopback connection section. 

Start NGINX on core 2 over VPP's host stack:

.. code-block:: shell

        sudo taskset -c 2 sh -c "LD_PRELOAD=${LDP_PATH} VCL_CONFIG=/path/to/vcl_nginx_proxy_pn.conf nginx -c /path/to/nginx_proxy.conf"

To examine the NGINX proxy session in VPP, run the command ``sudo ./vppctl -s ${sockfile} show session verbose``.
Here is a sample output for nginx proxy session:

.. code-block:: none

        Connection                                                  State          Rx-f      Tx-f
        [0:0][T] 0.0.0.0:8089->0.0.0.0:0                         LISTEN         0         0
        Thread 0: active sessions 1 

NGINX Setup on Server Node
~~~~~~~~~~~~~~~~~~~~~~~~~~

On server node create ssl private key and certificate for NGINX https server:

.. code-block:: shell

        sudo mkdir -p /etc/nginx/certs
        sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/nginx/certs/server.key -out /etc/nginx/certs/server.crt

Create NGINX config file ``nginx_server.conf`` for NGINX https server. It is same
as the ``nginx_server.conf`` in loopback connection section. 

Create a 1kb file in NGINX https server root directory for downloading:

.. code-block:: shell

        sudo mkdir -p /var/www/html
        sudo dd if=/dev/urandom of=/var/www/html/1kb bs=1024 count=1

Start NGINX https server:

.. code-block:: shell

        sudo taskset -c 1 nginx -c /path/to/nginx_server.conf

Test
~~~~

On client node download, build and run wrk2 to test ssl reverse proxy case:

.. code-block:: shell

        x86: git clone https://github.com/giltene/wrk2.git && cd wrk2
        OR
        aarch64: git clone https://github.com/AmpereTravis/wrk2-aarch64.git && cd wrk2-aarch64
        make all
        sudo taskset -c 1 ./wrk --rate 100000000 -t 1 -c 10 -d 10s https://172.16.2.1:8089/1kb"
 
If both wrk2 and NGINX run successfully, wrk2 will output measurement result similar
to the following:

.. code-block:: none

        Initialised 1 threads in 0 ms.
        Running 10s test @ https://172.16.2.1:8089/1kb
          1 threads and 10 connections
          Thread Stats   Avg      Stdev     Max   +/- Stdev
            Latency     5.01s     2.88s    9.99s    57.66%
            Req/Sec        nan       nan   0.00      0.00%
          424079 requests in 10.00s, 516.87MB read
        Requests/sec:  42406.22
        Transfer/sec:     51.68MB

Stop
~~~~

Kill VPP on DUT:

.. code-block:: shell

        sudo pkill -9 vpp

Kill NGINX on DUT and server nodes:

.. code-block:: shell

        sudo pkill -9 nginx

*********
Resources
*********

#. `VPP configuration reference <https://s3-docs.fd.io/vpp/22.02/configuration/reference.html>`_
#. `VPP set interface ip address reference <https://s3-docs.fd.io/vpp/22.02/cli-reference/clis/clicmd_src_vnet_ip.html#set-interface-ip-address>`_
#. `VPP set interface state reference <https://s3-docs.fd.io/vpp/22.02/cli-reference/clis/clicmd_src_vnet.html#set-interface-state>`_
#. `VPP ip route reference <https://s3-docs.fd.io/vpp/22.02/cli-reference/clis/clicmd_src_vnet_ip.html#ip-route>`_
#. `VPP app ns reference <https://s3-docs.fd.io/vpp/22.02/cli-reference/clis/clicmd_src_vnet_session.html#app-ns>`_
#. `VPP cli reference <https://s3-docs.fd.io/vpp/22.02/cli-reference/index.html>`_
#. `VPP vcl reference <https://wiki.fd.io/view/VPP/HostStack/VCL>`_
#. `nginx core functionality reference <https://nginx.org/en/docs/ngx_core_module.html>`_
#. `nginx http core module reference <https://nginx.org/en/docs/http/ngx_http_core_module.html>`_
#. `nginx http upstream module reference <https://nginx.org/en/docs/http/ngx_http_upstream_module.html>`_
#. `nginx http proxy module reference <https://nginx.org/en/docs/http/ngx_http_proxy_module.html>`_
#. `nginx http ssl module reference <https://nginx.org/en/docs/http/ngx_http_ssl_module.html>`_
#. `nginx http ssl module reference <https://nginx.org/en/docs/http/ngx_http_ssl_module.html>`_
