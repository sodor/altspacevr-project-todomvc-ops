#!/bin/bash

IP4ADDR=$(ip addr show | awk '/ inet / {print $2}' | sed 's|/.*||' | tail -n 1)
echo provisioning adm for node $IP4ADDR..

echo "override bootstrap-base for consul server"
cat <<CONSUL_EOF >/etc/default/consul
CONSUL_ARGS=agent -server -bootstrap-expect 1 -ui --client=${IP4ADDR}
CONSUL_DATA=/var/run/consul
CONSUL_CONFD=/etc/consul.d
CONSUL_BIND=$IP4ADDR
CONSUL_EOF
service consul start

# TODO - config syslog to recieve remote logs
