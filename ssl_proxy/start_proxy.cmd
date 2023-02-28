create loopback interface
set interface mtu packet 1500 loop0
set interface state loop0 up
create loopback interface
set interface mtu packet 1500 loop1
set interface state loop1 up
create loopback interface
set interface mtu packet 1500 loop2
set interface state loop2 up
ip table add 1
set interface ip table loop0 1
ip table add 2
set interface ip table loop1 2
ip table add 3 
set interface ip table loop2 3
set interface ip address loop0 172.16.1.1/24
set interface ip address loop1 172.16.2.1/24
set interface ip address loop2 172.16.3.1/24
app ns add id nginx secret 1234 sw_if_index 1
app ns add id proxy secret 5678 sw_if_index 2
app ns add id wrk secret 5678 sw_if_index 3
ip route add 172.16.1.1/32 table 2 via lookup in table 1
ip route add 172.16.3.1/32 table 2 via lookup in table 3
ip route add 172.16.2.1/32 table 1 via lookup in table 2
ip route add 172.16.2.1/32 table 3 via lookup in table 2
