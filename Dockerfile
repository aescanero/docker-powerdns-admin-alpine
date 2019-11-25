FROM alpine:3.10 AS builder
MAINTAINER "Alejandro Escanero Blanco <aescanero@disasterproject.com>"

RUN apk add --no-cache --virtual build-dependencies libffi-dev libxslt-dev python3-dev musl-dev gcc yarn xmlsec-dev
RUN apk add --no-cache curl py3-lxml py3-mysqlclient py3-openssl py3-cryptography py3-pyldap py3-virtualenv py3-lxml py3-setuptools py3-gunicorn

RUN mkdir /xmlsec && curl -sSL https://github.com/mehcode/python-xmlsec/archive/1.3.6.tar.gz | tar -xzC /xmlsec --strip 1 \
  && cd /xmlsec && pip3 install --no-cache-dir .

RUN mkdir -p /opt/pdnsadmin/ && cd /opt/pdnsadmin \
  && curl -sSL https://github.com/ngoduykhanh/PowerDNS-Admin/archive/master.tar.gz | tar -xzC /opt/pdnsadmin --strip 1 \
  && sed -i -e '/mysqlclient/d' -e '/pyOpenSSL/d' -e '/python-ldap/d' requirements.txt \
  && virtualenv --system-site-packages --no-setuptools --no-pip flask && source ./flask/bin/activate \
  && pip3 install --no-cache-dir -r requirements.txt

RUN cd /opt/pdnsadmin \
  && cp config_template.py config.py \
  && yarn install --pure-lockfile && yarn cache clean \
  && virtualenv --system-site-packages --no-setuptools --no-pip flask && source ./flask/bin/activate && flask assets build \
  && cd app/static && tar -cf t.tar `cat ../assets.py |grep node|cut -d\' -f 2|tr '\n' ' '` \
  && cd node_modules && find . -maxdepth 1 -type d ! -name "icheck" ! -name "bootstrap" ! -name "font-awesome" ! -name "ionicons" ! -name "multiselect" ! -name "." -exec rm -rf {} ";" \
  && cd .. && tar -xf t.tar && rm -f t.tar

RUN du -hs /usr/lib/python3.7
RUN du -hs /opt/pdnsadmin/
RUN which flask
RUN ls -ltr /usr/bin/

FROM alpine:3.10
MAINTAINER "Alejandro Escanero Blanco <aescanero@disasterproject.com>"

COPY --from=builder /usr/lib/python3.7/* /usr/lib/python3.7/

RUN apk add --no-cache curl python3 py3-mysqlclient py3-openssl py3-cryptography py3-pyldap netcat-openbsd \
  py3-virtualenv py3-lxml py3-setuptools py3-gunicorn py3-flask

COPY --from=builder /opt/pdnsadmin /opt/pdnsadmin

ADD entrypoint.sh /entrypoint.sh
RUN chmod u+x /entrypoint.sh
ADD mysql /usr/bin/mysql
RUN chmod u+x /usr/bin/mysql

EXPOSE 9191
ENTRYPOINT ["/entrypoint.sh"]
