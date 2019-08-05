FROM alpine:edge
MAINTAINER "Alejandro Escanero Blanco <aescanero@disasterproject.com>"

RUN apk add --no-cache python3 curl py3-mysqlclient py3-yaml py3-pytest py3-tz py3-openssl py3-gunicorn py3-dnspython py3-pyldap \
  py3-sqlalchemy py3-flask py3-flask-login py3-bcrypt py3-configobj py3-requests py3-virtualenv py3-cryptography \
  py3-mako py3-lxml py3-defusedxml py3-dateutil py3-simplejson py3-webcolors py3-jsonschema \
  xmlsec mariadb-client \
  python3-dev xmlsec-dev musl-dev libxslt-dev gcc\
  && adduser -S pdnsadmin && cd /home/pdnsadmin/ \
  && curl -sSL https://github.com/ngoduykhanh/PowerDNS-Admin/archive/master.tar.gz | tar -xzC /home/pdnsadmin --strip 1 && virtualenv flask \
  && sed -i -e '/mysqlclient/d' -e '/YAML/d' -e '/pytest/d' -e '/pytz/d' -e '/pyOpenSSL/d' -e '/gunicorn/d' -e '/dnspython/d' \
  -e '/python-ldap/d' -e '/SQLAlchemy/d' -e '/Flask=/d' -e '/Flask-Login=/d' -e '/bcrypt/d' -e '/configobj/d' \
  -e '/requests/d' requirements.txt

RUN cd /home/pdnsadmin && pip3 install --no-cache-dir -r requirements.txt && apk del python3-dev xmlsec-dev musl-dev libxslt-dev gcc

ADD entrypoint.sh /entrypoint.sh
RUN chmod u+x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
