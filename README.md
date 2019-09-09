# docker-powerdns-admin
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

## YAML For Kubernetes deployment, (using a loadBalancer service):

There are some enviroment variables needed to run the container:

* PDNS_PROTO: (http|https) protocol of PowerDNS API (Default http)
* PDNS_PORT: Port of PowerDNS API REST (Default 8081)
* PDNS_HOST: IP or name of the PowerDNS Server (Default: 127.0.0.1)
* PDNS_API_KEY: Access key to PowerDNS API (no default)
* PDNSADMIN_PORT: Port of the PowerDNS-Admin Service (Default 9191)
* PDNSADMIN_SECRET_KEY: Key to generate access session (Default: secret)
* PDNSADMIN_SQLA_DB_PORT: Port of MySql Server (Default 3306)
* PDNSADMIN_SQLA_DB_NAME: Database to use in the MySql Server (Default: powerdns)
* PDNSADMIN_SQLA_DB_USER: User with access to manage the MySql Database (Default: powerdns)
* PDNSADMIN_SQLA_DB_PASSWORD: Password of the MySql user (Default: secret)
* PDNSADMIN_SQLA_DB_HOST: IP or name of the MySql Server (Default: 127.0.0.1)

```
---
apiVersion: v1
kind: Namespace
metadata:
  name: powerdns
---
apiVersion: v1
kind: Secret
metadata:
  name: s-powerdns
  namespace: powerdns
type: Opaque
data:
  PDNS_APIKEY: M0lhOFRXOVhRQ1VpU2ha
  PDNSADMIN_SECRET: M0lhOFRXOVhRQ1VpU2ha
  MYSQL_PASS: M0lhOFRXOVhRQ1VpU2ha
---
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: powerdns
  namespace: powerdns
spec:
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: powerdns
    spec:
      # Only use if you're also using RBAC
      # serviceAccountName: powerdns
      containers:
      - name: powerdns
        image: pschiffe/pdns-mysql:alpine
        lifecycle:
          postStart:
            exec:
              command: ["/bin/sh", "-c", "sleep 20 ; pdnsutil create-zone demo-network.local"]
        env:
        - name: PDNS_api_key
          valueFrom:
            secretKeyRef:
              name: s-powerdns
              key: PDNS_APIKEY
        - name: PDNS_master
          value: "yes"
        - name: PDNS_api
          value: "yes"
        - name: PDNS_webserver
          value: "yes"
        - name: PDNS_webserver_address
          value: "127.0.0.1"
        - name: PDNS_webserver_allow_from
          value: "127.0.0.1/32"
        - name: PDNS_webserver_password
          valueFrom:
            secretKeyRef:
              name: s-powerdns
              key: PDNS_APIKEY
        - name: PDNS_version_string
          value: "anonymous"
        - name: PDNS_default_ttl
          value: "1500"
        - name: PDNS_soa_minimum_ttl
          value: "1200"
        - name: PDNS_default_soa_name
          value: "ns1.demo-network.local"
        - name: PDNS_default_soa_mail
          value: "hostmaster.demo-network.local"
        - name: MYSQL_ENV_MYSQL_HOST
          value: "127.0.0.1"
        - name: MYSQL_ENV_MYSQL_PASSWORD
          valueFrom:
            secretKeyRef:
              name: s-powerdns
              key: MYSQL_PASS
        - name: MYSQL_ENV_MYSQL_DATABASE
          value: "powerdns"
        - name: MYSQL_ENV_MYSQL_USER
          value: "powerdns"
        - name: MYSQL_ENV_MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: s-powerdns
              key: MYSQL_PASS
        ports:
        - containerPort: 53
          name: dns
          protocol: UDP
        - containerPort: 8081
          name: powerdns-api
          protocol: TCP
      - name: powerdns-admin
        image: aescanero/powerdns-admin
        env:
        - name: PDNS_API_KEY
          valueFrom:
            secretKeyRef:
              name: s-powerdns
              key: PDNS_APIKEY
        - name: PDNSADMIN_SECRET_KEY
          valueFrom:
            secretKeyRef:
              name: s-powerdns
              key: PDNSADMIN_SECRET
        - name: PDNS_PROTO
          value: "http"
        - name: PDNS_HOST
          value: "127.0.0.1"
        - name: PDNS_PORT
          value: "8081"
        - name: PDNSADMIN_SQLA_DB_HOST
          value: "127.0.0.1"
        - name: PDNSADMIN_SQLA_DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: s-powerdns
              key: MYSQL_PASS
        - name: PDNSADMIN_SQLA_DB_NAME
          value: "powerdns"
        - name: PDNSADMIN_SQLA_DB_USER
          value: "powerdns"
        ports:
        - containerPort: 9191
          name: pdns-admin-http
          protocol: TCP
      - name: mysql
        image: yobasystems/alpine-mariadb
        env:
        - name: MYSQL_PASSWORD
          valueFrom:
            secretKeyRef:
              name: s-powerdns
              key: MYSQL_PASS
        - name: MYSQL_DATABASE
          value: "powerdns"
        - name: MYSQL_USER
          value: "powerdns"
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: s-powerdns
              key: MYSQL_PASS
---
apiVersion: v1
kind: Service
metadata:
  name: endpoint-dns
  namespace: powerdns
spec:
  ports:
  - name: dns
    port: 53
    protocol: UDP
    targetPort: dns
  selector:
    app: powerdns
  type: LoadBalancer
---
apiVersion: v1
kind: Service
metadata:
  name: powerdns-admin
  namespace: powerdns
spec:
  ports:
  - name: pdns-admin-http
    port: 80
    protocol: TCP
    targetPort: pdns-admin-http
  selector:
    app: powerdns
  type: LoadBalancer

```

More info in https://www.disasterproject.com
