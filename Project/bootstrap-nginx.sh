#!/bin/bash

IP4ADDR=$(ip addr show | awk '/ inet / {print $2}' | sed 's|/.*||' | tail -n 1)
echo provisioning nginx for node $IP4ADDR..

echo "setup todomvc app with systemd"
install -o root -g root -m 644 /vagrant/todomvc.service /etc/systemd/system/
systemctl enable todomvc.service

echo "install todomvc requirements with pip"
apt-get -y install python-pip postgresql-client libpq-dev python-dev
pip install -U -r /vagrant/todomvc/requirements.txt

echo "setup todomvc db (seems idempotent)"
/vagrant/todomvc/manage.py syncdb --noinput

# TODO - wrap in gunicorn or something similar
service todomvc start

echo "config todomvc+nginx service in consul"
mkdir -p /etc/consul.d/
cat <<CONSUL_EOF >/etc/consul.d/todomvc.json
{"service": {"name": "todomvc", "port": 8000, "checks": [{"id": "http-get-todomvc", "name": "HTTP GET /", "http": "http://127.0.0.1:8000", "interval": "5s"}]}}
{"service": {"name": "nginx", "port": 80, "checks": [{"id": "http-get-nginx", "name": "HTTP GET /", "http": "http://127.0.0.1:80", "interval": "5s"}]}}
CONSUL_EOF
service consul start

# get nginx
apt-get -y install nginx-light

echo "write the nginx config"
cat <<'NGINX_EOF' >/etc/nginx/sites-available/default

# use consul on loopback as resolver
resolver 127.0.0.1:8600;

#upstream backend {
#  zone backend 64k;
#  hash $request_uri consistent;
#  server todomvc.service.consul:8080;
#}

server {

  listen 80 default_server;
  listen [::]:80 default_server;
#  listen 443 ssl default_server;
#  listen [::]:443 ssl default_server;

  # TODO - hack to get around non-nginx+ - http://tenzer.dk/nginx-with-dynamic-upstreams/
  set $backend_endpoint http://todomvc.service.consul:8000;

  location / {
    proxy_pass $backend_endpoint;
#    health_check uri=/ interval=5 fails=2 passes=2;
  }

}

NGINX_EOF

service nginx restart
