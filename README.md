# docker-powerdns-admin

[PowerDNS-Admin](https://github.com/ngoduykhanh/PowerDNS-Admin) provides a dashboard for PowerDNS management.
[PowerDNS](https://www.powerdns.com/) is an open source DNS Authoritative Server (answer questions about domains it knows about, but will not go out on the net to resolve queries about other domains) software.

The examples also packages:

- [aescanero/docker-powerdns-admin-alpine](https://github.com/aescanero/docker-powerdns-admin-alpine) based in [ngoduykhanh/PowerDNS-Admin](https://github.com/ngoduykhanh/PowerDNS-Admin) which provides a dashboard for PowerDNS management.
- [yobasystems/alpine-mariadb](https://github.com/yobasystems/alpine-mariadb) which is required for bootstrapping a MariaDB deployment for the database requirements of the PowerDNS and PowerDNS-Admin applications.

## Docker image for powerdns-admin to manage powerdns

This is a Alpine based image to reduce size (is the small of the newest PowerDNS-Admin images) and let a faster deployment of lastest PowerDNS-Admin (https://github.com/ngoduykhanh/PowerDNS-Admin)

This image only runs with a Mysql database (see examples)

There are some enviroment variables needed to run the container:

* PDNS_API_KEY: Access key to PowerDNS API (needed)
* DOMAIN: Domain to manage (needed)
* LOCALPATH: Path in the host machine where the database is stored (needed)
* DB_NAME: Database to use in the MySql Server for PowerDNS (needed)
* DB_USERNAME: User with access to manage the MySql Database (needed)
* DB_USER_PASSWORD: Password of the MySql user (needed)
* DB_ROOT_PASSWORD: Password of the MySql user (needed)

## How to test this container with Docker Composer:

```
$ mkdir ~/mysql
$ git clone https://github.com/aescanero/docker-powerdns-admin-alpine
$ cd docker-powerdns-admin-alpine
$ LOCALPATH="~/mysql" DOMAIN="disasterproject.com" DB_USERNAME="powerdns" DB_USER_PASSWORD="password" DB_ROOT_PASSWORD="password" DB_NAME="powerdns" PDNS_API_KEY="random" docker-compose up -d
$ docker-compose ps
```
And then open http://WHERE_IS_RUNNING_DOCKER:9191 to access PowerDNS-Admin
To remove:

```
$ cd ~/docker-powerdns-admin-alpine
$ docker-compose stop
$ docker-compose rm
```
Database is in ~/mysql, you must remove it if you don't use it again.

## Test the container with Podman:

```
mkdir ~/mysql
export LOCALPATH=`pwd`"/mysql"
export DOMAIN="disasterproject.com"
export DB_USERNAME="powerdns"
export DB_USER_PASSWORD="password"
export DB_ROOT_PASSWORD="password"
export DB_NAME="powerdns"
export PDNS_API_KEY="random"

sudo podman run -d -v ${LOCALPATH}:/var/lib/mysql \
-e MYSQL_PASSWORD="${DB_USER_PASSWORD}" \
-e MYSQL_DATABASE="${DB_NAME}" \
-e MYSQL_USER="${DB_USERNAME}" \
-e MYSQL_ROOT_PASSWORD="${DB_ROOT_PASSWORD}" \
--ip 10.88.0.254 --name mysql yobasystems/alpine-mariadb

sudo podman run -d \
-e PDNS_api_key="secret" \
-e PDNS_master="yes" \
-e PDNS_api="yes" \
-e PDNS_webserver="yes" \
-e PDNS_webserver_address="0.0.0.0" \
-e PDNS_webserver_allow_from="0.0.0.0/0" \
-e PDNS_webserver_password="secret" \
-e PDNS_version_string="anonymous" \
-e PDNS_default_ttl="1500" \
-e PDNS_soa_minimum_ttl="1200" \
-e PDNS_default_soa_name="ns1.${DOMAIN}" \
-e PDNS_default_soa_mail="hostmaster.${DOMAIN}" \
-e MYSQL_ENV_MYSQL_HOST="10.88.0.254" \
-e MYSQL_ENV_MYSQL_PASSWORD="${DB_USER_PASSWORD}" \
-e MYSQL_ENV_MYSQL_DATABASE="${DB_NAME}" \
-e MYSQL_ENV_MYSQL_USER="${DB_USERNAME}" \
-e MYSQL_ENV_MYSQL_ROOT_PASSWORD="${DB_ROOT_PASSWORD}" \
-p 53:53 --ip 10.88.0.252 --name powerdns pschiffe/pdns-mysql:alpine

sudo podman run -d -e PDNS_PROTO="http" \
-e PDNS_API_KEY="${PDNS_API_KEY}" \
-e PDNS_HOST="10.88.0.252" \
-e PDNS_PORT="8081" \
-e PDNSADMIN_SECRET_KEY="secret" \
-e PDNSADMIN_SQLA_DB_HOST="10.88.0.254" \
-e PDNSADMIN_SQLA_DB_PASSWORD="${DB_USER_PASSWORD}" \
-e PDNSADMIN_SQLA_DB_NAME="${DB_NAME}" \
-e PDNSADMIN_SQLA_DB_USER="${DB_USERNAME}" \
-p 9191:9191 --ip 10.88.0.253 --name powerdns-admin aescanero/powerdns-admin
```

## Chart for Kubernetes deployment, (using at least Helm v3 beta3):

### Introduction

This chart bootstraps a [pschiffe/docker-pdns](https://github.com/pschiffe/docker-pdns) deployment on a [Kubernetes](http://kubernetes.io) cluster using the [Helm](https://helm.sh) package manager.

## Prerequisites

- Kubernetes 1.4+ with Beta APIs enabled
- PV provisioner support in the underlying infrastructure (Optional)

## Installing the Chart

To install the chart with the release name `my-release`:

```console
$ helm install --name my-release https://raw.githubusercontent.com/aescanero/helm-powerdns/master/stable/powerdns.tgz
```

The command deploys PowerDNS on the Kubernetes cluster in the default configuration. The [configuration](#configuration) section lists the parameters that can be configured during installation.

> **Tip**: List all releases using `helm list`

## Uninstalling the Chart

To uninstall/delete the `my-release` deployment:

```console
$ helm delete my-release
```

The command removes all the Kubernetes components associated with the chart and deletes the release.

## Configuration

The following table lists the configurable parameters of the PowerDNS chart and their default values.

|             Parameter             |              Description                   |                         Default                         |
|-----------------------------------|--------------------------------------------|---------------------------------------------------------|
| `powerdns.enabled`                | Deploy the DNS Server packaged with Helm   | `true`                                                  |
| `powerdns.service.dns.type`       | Class of the Kubernetes DNS Service        | `LoadBalancer`                                          |
| `powerdns.service.dns.port`       | Port of the DNS Service                    | `53`                                                    |
| `powerdns.service.api.type`       | Class of the Kubernetes PowerDNSAPI Service| `ClusterIP`                                             |
| `powerdns.service.api.port`       | Port of the DNS Service                    | `53`                                                    |
| `powerdns.image.repository`       | PowerDNS image name                        | `pschiffe/pdns-mysql`                                   |
| `powerdns.image.tag`              | PowerDNS image tag                         | `alpine`                                                |
| `powerdns.image.pullPolicy`       | Image pull policy                          | `IfNotPresent`                                          |
| `powerdns.domain`                 | Automatically create a domain              | `external.local`                                        |
| `powerdns.master`                 | Deploy PowerDNS as master                  | `yes`                                                   |
| `powerdns.api`                    | Enable API for Management (need webserver) | `yes`                                                   |
| `powerdns.webserver`              | Enable web server to publish API           | `yes`                                                   |
| `powerdns.webserver_address`      | IP where the web server is published       | `0.0.0.0                                                |
| `powerdns.webserver_allow_from`   | Allow access to web server only from       | `0.0.0.0/0`                                             |
| `powerdns.version_string`         | Version to designate the DNS Server        | `anonymous`                                             |
| `powerdns.default_ttl`            | time-to-live of the DNS resources          | `1500`                                                  |
| `powerdns.soa_minimum_ttl`        | Minimal time-to-live of SOA                | `1200`                                                  |
| `powerdns.default_soa_name`       | Name to designate the zone                 | `ns1.external.local`                                    |
| `powerdns.mysql_host`             | Host of the external database              | `127.0.0.1`                                             |
| `powerdns.mysql_database`         | Name of the external database              | `powerdns`                                              |
| `powerdns.mysql_user`             | User of the external database              | `powerdns`                                              |
| `powerdns.mysql_rootpass`         | Password of the root user of external BD   | `nil`                                                   |
| `powerdns.mysql_pass`             | Password of the user                       | `nil`                                                   |
| `powerdns.resources`              | CPU/Memory resource requests/limits        | Memory: `512Mi`, CPU: `300m`                            |
| `mariadb.enabled`                 | Deploy the Database packaged with Helm     | `true`                                                  |
| `mariadb.image.repository`        | MariaDB image name                         | `yobasystems/alpine-mariadb`                            |
| `mariadb.image.tag`               | MariaDB image tag                          | `latest`                                                |
| `mariadb.image.pullPolicy`        | Image pull policy                          | `IfNotPresent`                                          |
| `mariadb.mysql_rootpass`          | Password of the root user of internal BD   | `nil`                                                   |
| `mariadb.mysql_pass`              | Password of the user                       | `nil`                                                   |
| `mariadb.persistence.enabled`     | Enable persistence using PVC               | `true`                                                  |
| `mariadb.persistence.storageClass`| PVC Storage Class for MariaDB volume       | `nil`                                                   |
| `mariadb.persistence.accessMode`  | PVC Access Mode for MariaDB volume         | `ReadWriteOnce`                                         |
| `mariadb.persistence.size`        | PVC Storage Request for MariaDB volume     | `1Gi`                                                   |
| `mariadb.resources`               | CPU/Memory resource requests/limits        | Memory: `512Mi`, CPU: `300m`                            |
| `powerdnsadmin.enabled`           | Deploy the Dashboard packaged with Helm    | `true`                                                  |
| `powerdnsadmin.service.type`      | Class of Kubernetes PowerDNS-Admin Service | `LoadBalancer`                                          |
| `powerdnsadmin.service.port`      | Port of the PowerDNS-Admin Service         | `9191`                                                  |
| `powerdnsadmin.image.repository`  | PowerDNS-Admin image name                  | `aescanero/powerdns-admin`                              |
| `powerdnsadmin.image.tag`         | PowerDNS-Admin image tag                   | `latest`                                                |
| `powerdnsadmin.image.pullPolicy`  | Image pull policy                          | `IfNotPresent`                                          |
| `powerdnsadmin.proto`             | Protocol of PowerDNS-Admin Service         | `http`                                                  |
| `powerdnsadmin.powerdns_host`     | Where is PowerDNS Service                  | `127.0.0.1`                                             |
| `powerdnsadmin.powerdns_port`     | Port of the PowerDNS API Service           | `8081`                                                  |
| `powerdnsadmin.mysql_host`        | Host of the external database              | `127.0.0.1`                                             |
| `powerdnsadmin.mysql_database`    | Name of the external database              | `powerdns`                                              |
| `powerdnsadmin.mysql_user`        | User of the external database              | `powerdns`                                              |
| `powerdnsadmin.mysql_pass`        | Password of the user                       | `nil`                                                   |
| `powerdnsadmin.resources`         | CPU/Memory resource requests/limits        | Memory: `512Mi`, CPU: `300m`                            |
| `powerdnsadmin.ingress.enabled`   | Deploy the Dashboard with Ingress          | `false`                                                 |
| `powerdnsadmin.ingress.class`     | Class of Ingress                           | `traefik`                                               |
| `powerdnsadmin.ingress.hostname`  | Hostname without domain part               | `powerdns-admin`                                        |
| `powerdnsadmin.ingress.path`      | Path within the url structure              | `/`                                                     |

The above parameters map to the env variables defined in each container. For more information please refer to each image documentation.

Specify each parameter using the `--set key=value[,key=value]` argument to `helm install`. For example,

```console
$ helm install --name powerdns-release \
  --set domain=disasterproject.com \
    https://raw.githubusercontent.com/aescanero/helm-powerdns/master/stable/powerdns.tgz
```

The above command sets the domain managed by PowerDNS to `disasterproject.com`.

Alternatively, a YAML file that specifies the values for the above parameters can be provided while installing the chart. For example,

```console
$ helm install --name my-release -f values.yaml https://raw.githubusercontent.com/aescanero/helm-powerdns/master/stable/powerdns.tgz
```

## Persistence

The [yobasystems/alpine-mariadb](https://github.com/yobasystems/alpine-mariadb) image stores the Database at `/var/lib/mysql` path of the container.

Persistent Volume Claims are used to keep the data across deployments.


More info in https://www.disasterproject.com
