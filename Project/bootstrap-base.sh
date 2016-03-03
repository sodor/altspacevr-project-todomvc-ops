#!/bin/bash

#cat <<APT_EOF >/etc/apt/sources.list.d/jessie-backports.list
#deb http://httpredir.debian.org/debian jessie-backports main
#deb-src http://httpredir.debian.org/debian jessie-backports main
#APT_EOF
apt-get update
apt-get -y upgrade
apt-get -y install strace atop tcpdump

# the first server of each type is marked as a consul 'server' for elections
IP4ADDR=$(ip addr show | awk '/ inet / {print $2}' | sed 's|/.*||' | tail -n 1)
if hostname | grep -E '1$' >/dev/null
then
  FIRSTOFTYPE=-server
fi

echo "install/setup consul (no deb package yet)"
mkdir -p /etc/consul.d /var/run/consul
chown vagrant:nogroup /etc/consul.d /var/run/consul
cat <<CONSUL_EOF >/etc/default/consul
CONSUL_ARGS=agent $FIRSTOFTYPE -join=192.168.11.5
CONSUL_DATA=/var/run/consul
CONSUL_CONFD=/etc/consul.d
CONSUL_BIND=$IP4ADDR
CONSUL_EOF
install -o root -g root -m 755 /vagrant/consul /usr/local/bin
install -o root -g root -m 644 /vagrant/consul.service /etc/systemd/system/
systemctl enable consul.service

# TODO - config syslog to ship logs off system
