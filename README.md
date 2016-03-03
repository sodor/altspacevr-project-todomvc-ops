# Altspace Programming Project - TodoMVC Operations

## TL;DR

A Vagrantfile which unpacks five debian jessie based virtualbox
servers. Two nginx servers run the TodoMVC webapp behind a
reverse_proxy instance. This nginx is setup to pass requests to the
local and adjacent webapp instances (this was meant to provide URI
hashing for better horizontal scaling, but for non-obvious reasons
that turns out to be not supported by free nginx). The webapps
themselves are hard wired to a master PostgreSQL database on
'pg1'. This, in turn, is also being stream replicated to a (readonly)
hotspare. Each server propgates it's service availability using
Consul, whose DNS API is being used by nginx to route to the available
webapps. The first server of each type acts as a Consul server for the
consensus protocol, and the web ui for Consul is available on the
fifth server: 'adm1'.

### What you get:
* 1x admin box (adm1): service discovery ui.
* 2x nginx+webapp box (nginx1+2): nginx load balancing across all the django webservers.
* 2x pgsql box (pg1+2): pg1 streams to the readonly hotspare.

### Quick Start:
```
$ vagrant up
```

## Things To Try:
* The TodoMVC app - http://1921.68.11.21 (or any other LB IP like: .22).
* Consul service discovery/health UI - http://192.168.11.5:8500/ui
* Stopping a webapp:
```
$ vagrant ssh nginx1
...
$ sudo service todomvc stop
...
```
* Scaling out more webservers (or db servers) in the Vagrantfile:
```
       node.vm.network "private_network", ip: "192.168.11.1#{i}"
       node.vm.provision :shell, path: "bootstrap-pg.sh"
     end
   end
 
-  (1..2).each do |i|
+  (1..4).each do |i|
     config.vm.define "nginx#{i}" do |node|
       node.vm.hostname = "nginx#{i}"
       node.vm.network "private_network", ip: "192.168.11.2#{i}"
```

### Production Todos:
In proximate order of doing:
* DNS load balancer in front of Nginx.
* Firewall from outside, except HTTP(S) on nginxX and a new SSH port on admX.
* Implement a simple auto-readonly failover mechanism for pgX in Consul.
* Update TodoMVC to route appropriate queries to the 'readonly' pgXs (or use middleware).
* Make smarter health check scripts for Consul.
* Stream syslogs back to adm server.
* Schedule DB dumps and ship offsite.
* Setup collectd on adm server, and agents on all nodes.
* Seperate webapp into it's own layer, and use gunicorn or similar instead of the built in django one.
* Switch to LXC and use at least two physical machines (one for each set of admN,nginxN,webN,pgN).
* Debian repo for private packages (eg: consul, todomvc).
* Jenkins to publish code changes into the repo and onto a staging environment.
* Ansible to make provisioning new servers a little less fragile.
* IPv6.

***

## IMHO

This project gave me an excuse to try out a bunch of new
technologies that I'd never really been forced to try: Docker,
Vagrant, Rails (and Ruby), Django. After reading the docs and trying
out some basic examples I abandoned Docker and Ruby. Along the way, I
also found Ansible and Consul, and also rediscovered LXC.

With respect to abandoning Docker: I think I like having a system I
can log into and debug. Isolating a single "application" within a VM
(or preferably a container) should also come with a set of tools that
help you look at that running system and help ensure it's running
properly. I just couldn't get comfortable with Docker's system
tooling and init wonkiness.

Rails probably would've worked fine if I'd spent more time to figure
out the generally accepted way to package it. I'd read previously
that, like Perl (big fan!), Ruby had many niceties (a first order
regex operator!). Unfortunately, from an ops perspective, it wasn't
working out for a quick project like this. So in the interests of
time, I (regretably?) switched to Python.

Vagrant really impressed me. I think it's core usefullness is making
"system architecturing" a more dev-like experience. I can see that
being able to simply describe a set of systems in a config file makes
it easier for non-traditional ops people (aka devs) to discover and
understand changes in the system. It's also great for sharing/testing
this kind of project with someone else (as we're doing here). However,
if I were doing this project in "real-life", I would have gone a
little further and rigged it all together with Ansible. I'm now
actually looking at Ansible for other projects - I really like how it
preserves the ability to config routers/switches because it doesn't
need an agent on the system.

I also experimented with LXC for this. It's now my favourite
container/cgroup software (faint praise, indeed). However, for this
project I wasn't sure if everybody would have had access to the
vagrant-lxc plugin, so I switched back to using Vagrant's default:
virtualbox (which made the vagrant-up's a lot slower).

I think the most interesting piece of this was discovering that Consul
had a DNS API for its service catalog. It was easy to plug it in to
Nginx to get to it dynamically route to the set of 'alive' backend
webapps (and I wouldn't need to write a bunch of nginx-lua to do that
magic for me). Unfortunately, it looks like the non-commercial version
of Nginx wouldn't let me layer URI hashing on top of this. In the
past, I would've used Squid or HAProxy to fill the load-balancer
role. It seems that Nginx is "the choice" for Rails and Django apps,
so I gave it a try.

I would've also liked to build a similar Consul based mechanism for
the webapp, so that it could auto-reconnect to an available postgres
database. Usually, I would bake the failover logic into the db client
application. With outside knowledge from the application of what it's
trying to do, you can usually make faster and more resilient failover
descisions. Using Consul for service discovery would've made that a
lot easier and safer to coordinate. The more traditional middleware
layer (eg: pgpool, pgbouncer), adds extra complexity right in the
middle of what should be one of the least latent and most reliable
connections in your stack.

All in all, thanks for the fun project!