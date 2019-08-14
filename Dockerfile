FROM alpine:3.10
MAINTAINER "Alejandro Escanero Blanco <aescanero@disasterproject.com>"

RUN apk add --no-cache python3 curl py3-mysqlclient py3-openssl py3-cryptography py3-pyldap netcat-openbsd \
  py3-virtualenv mariadb-client xmlsec py3-lxml py3-setuptools
RUN apk add --no-cache --virtual build-dependencies libffi-dev libxslt-dev python3-dev musl-dev gcc yarn xmlsec-dev
RUN mkdir /xmlsec && curl -sSL https://github.com/mehcode/python-xmlsec/archive/1.3.6.tar.gz | tar -xzC /xmlsec --strip 1 \
  && cd /xmlsec && pip3 install --no-cache-dir .
RUN mkdir -p /opt/pdnsadmin/ && cd /opt/pdnsadmin \
  && curl -sSL https://github.com/ngoduykhanh/PowerDNS-Admin/archive/master.tar.gz | tar -xzC /opt/pdnsadmin --strip 1 \
  && sed -i -e '/mysqlclient/d' -e '/pyOpenSSL/d' -e '/python-ldap/d' requirements.txt \
  && pip3 install --no-cache-dir -r requirements.txt
RUN cd /opt/pdnsadmin \
  && cp config_template.py config.py \
  && yarn install --pure-lockfile && yarn cache clean \
  && virtualenv --system-site-packages --no-setuptools --no-pip flask && source ./flask/bin/activate && flask assets build \
  && apk del build-dependencies && rm -rf /xmlsec/ \
  && cd app/static/node_modules && find . -maxdepth 1 -type d ! -name "icheck" ! -name "." -exec rm -rf {} ";"

ADD entrypoint.sh /entrypoint.sh
RUN chmod u+x /entrypoint.sh

EXPOSE 9191
ENTRYPOINT ["/entrypoint.sh"]
