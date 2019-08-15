FROM alpine:3.10
MAINTAINER "Alejandro Escanero Blanco <aescanero@disasterproject.com>"

RUN apk add --no-cache python3 curl py3-mysqlclient py3-openssl py3-cryptography py3-pyldap netcat-openbsd \
  py3-virtualenv xmlsec py3-lxml py3-setuptools
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
  && cd app/static && tar -cf t.tar `cat ../assets.py |grep node|cut -d\' -f 2|tr '\n' ' '` \
  && cd node_modules && find . -maxdepth 1 -type d ! -name "icheck" ! -name "bootstrap" ! -name "font-awesome" ! -name "ionicons" ! -name "multiselect" ! -name "." -exec rm -rf {} ";" \
  && cd .. && tar -xf t.tar && rm -f t.tar

#DON'T TOUCH
#bootstrap
#font-awesome
#icheck
#ionicons
#multiselect

ADD entrypoint.sh /entrypoint.sh
RUN chmod u+x /entrypoint.sh
ADD mysql /usr/bin/mysql
RUN chmod u+x /usr/bin/mysql

EXPOSE 9191
ENTRYPOINT ["/entrypoint.sh"]
