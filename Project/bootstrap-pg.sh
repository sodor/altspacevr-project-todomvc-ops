#!/bin/bash

IP4ADDR=$(ip addr show | awk '/ inet / {print $2}' | sed 's|/.*||' | tail -n 1)
echo provisioning pg for node $IP4ADDR..

apt-get install -y postgresql-9.4

echo "config psql service in consul"
mkdir -p /etc/consul.d/
cat <<CONSUL_EOF >/etc/consul.d/todomvc.json
{"service": {"name": "psql", "port": 5432, "checks": [{"id": "tcp-psql", "name":"PSQL TCP port 5432", "tcp": "localhost:5432", "timeout":"1s"}]}}
CONSUL_EOF
service consul start

echo create todomvc user/database
su - postgres -c "createuser todomvc"
su - postgres -c "createdb -O todomvc todomvc"
su - postgres -c "psql" <<PG_EOF
alter role todomvc password 'todomvcasvr';
PG_EOF

if ! ss -nlp | grep '*:5432'
then
  echo setup pg listening
  sed -i "s/^#listen_addresses =.*/listen_addresses = '*'/" /etc/postgresql/9.4/main/postgresql.conf
  PG_RESTART=1
fi

if ! grep 192.168.11.0 /etc/postgresql/9.4/main/pg_hba.conf >/dev/null
then
  echo setup pg host-based authentication
  cat <<PG_EOF >/etc/postgresql/9.4/main/pg_hba.conf
local   all             postgres                                peer
local   all             all                                     md5
host    all             all             127.0.0.1/32            md5
host    all             all             ::1/128                 md5
host    all             all             192.168.11.0/24         md5
host    replication     replication     192.168.11.0/24         md5
PG_EOF
  PG_RESTART=1
fi

if ! grep -E "^wal_level = hot_standby" /etc/postgresql/9.4/main/pg_hba.conf >/dev/null
then
  echo setup wal for streaming replication
  sed -i "s/^#wal_level = .*/wal_level = hot_standby/" /etc/postgresql/9.4/main/postgresql.conf
  sed -i "s/^#max_wal_senders = .*/max_wal_senders = 5/" /etc/postgresql/9.4/main/postgresql.conf
  sed -i "s/^#wal_keep_segments = .*/wal_keep_segments = 32/" /etc/postgresql/9.4/main/postgresql.conf 
  PG_RESTART=1
fi

if hostname | grep -E '1$' >/dev/null
then
  echo setup replication user on master db
  su - postgres -c "createuser --replication replication"
  su - postgres -c "psql" <<PG_EOF
alter role replication password 'replicationasvr';
PG_EOF
else
  PG_RESTART=
  echo backup master onto hotstandby for streaming replication
  rm -rf /var/lib/postgresql/9.4/main-old/
  service postgresql stop
  mv /var/lib/postgresql/9.4/main/ /var/lib/postgresql/9.4/main-old/
  mkdir -p -m 700 /var/lib/postgresql/9.4/main/
  chown postgres:postgres /var/lib/postgresql/9.4/main
  su - postgres -c "PGPASSWORD=replicationasvr pg_basebackup -h 192.168.11.11 -D /var/lib/postgresql/9.4/main -P -U replication --xlog-method=stream -R"
  sed -i "s/^#hot_standby = .*/hot_standby = on/" /etc/postgresql/9.4/main/postgresql.conf
  service postgresql start
fi

if [ -n $PG_RESTART ] 
then
  service postgresql restart
fi

