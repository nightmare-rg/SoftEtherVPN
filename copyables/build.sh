#!/bin/bash

apt-get update && apt-get install build-essential git libreadline-dev libncurses5-dev libssl-dev iptables -y

git clone --depth 1 https://github.com/SoftEtherVPN/SoftEtherVPN.git /usr/local/src/vpnserver

cd /usr/local/src/vpnserver

cp src/makefiles/linux_64bit.mak Makefile
make

cp bin/vpnserver/vpnserver /opt/vpnserver
cp bin/vpnserver/hamcore.se2 /opt/hamcore.se2
cp bin/vpncmd/vpncmd /opt/vpncmd

rm -rf /usr/local/src/vpnserver

gcc -o /usr/local/sbin/run /usr/local/src/run.c

rm /usr/local/src/run.c

#cleanup
apt-get remove -y build-essential && apt-get -y autoremove
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

exit 0
