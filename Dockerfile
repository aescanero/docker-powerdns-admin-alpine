FROM alpine:3.11 AS builder
MAINTAINER "Alejandro Escanero Blanco <aescanero@disasterproject.com>"

RUN apk add --no-cache curl python3 mariadb-connector-c py3-lxml libldap yarn libressl \
  && pip3 install --upgrade pip \
  && apk add --no-cache --virtual build-dependencies mariadb-connector-c-dev xmlsec-dev gcc python3-dev musl-dev libffi-dev libressl-dev libxslt-dev libxml2-dev openldap-dev

RUN mkdir -p /opt/pdnsadmin/ && cd /opt/pdnsadmin \
  && curl -sSL https://github.com/ngoduykhanh/PowerDNS-Admin/archive/v0.2.2.tar.gz | tar -xzC /opt/pdnsadmin --strip 1 \
  && PATH=$PATH:~/.local/bin pip3 install --no-cache-dir --user -r requirements.txt

RUN cd /opt/pdnsadmin \
  && cat configs/development.py >config.py \
  && yarn install --pure-lockfile && yarn cache clean \
  && sed -i -r -e "s|'cssmin',\s?'cssrewrite'|'cssmin'|g" powerdnsadmin/assets.py \
  && PATH=$PATH:~/.local/bin FLASK_APP=/opt/pdnsadmin/powerdnsadmin/__init__.py flask assets build \
  && mv powerdnsadmin/static /tmp/static && mkdir powerdnsadmin/static \
  && cp -r /tmp/static/generated powerdnsadmin/static && cp -r /tmp/static/assets powerdnsadmin/static \
  && cp -r /tmp/static/img powerdnsadmin/static \
  && find /tmp/static/node_modules -name 'fonts' -exec cp -r {} powerdnsadmin/static ";" \
  && find /tmp/static/node_modules/icheck/skins/square -name '*.png' -exec cp {} powerdnsadmin/static/generated ";" \
  && echo -e "from flask_assets import Environment \n\
assets = Environment()\n\
assets.register('js_login', 'generated/login.js')\n\
assets.register('js_validation', 'generated/validation.js')\n\
assets.register('css_login', 'generated/login.css')\n\
assets.register('js_main', 'generated/main.js')\n\
assets.register('css_main', 'generated/main.css')\n\
">powerdnsadmin/assets.py

RUN pip install pip-autoremove && \
    pip-autoremove cssmin -y && \
    pip-autoremove jsmin -y && \
    pip-autoremove pytest -y && \
    pip uninstall -y pip-autoremove


FROM alpine:3.11
MAINTAINER "Alejandro Escanero Blanco <aescanero@disasterproject.com>"

#COPY --from=builder /usr/lib/python3.7/* /usr/lib/python3.7/

ENV FLASK_APP=/opt/pdnsadmin/powerdnsadmin/__init__.py \
    PATH=$PATH:/opt/.local/bin \
    PYTHONPATH=/opt/.local/lib/python3.8/site-packages 

RUN apk add --no-cache curl mariadb-connector-c python3 py3-lxml xmlsec libldap libressl tzdata \
  && addgroup -S pda && adduser -S -D -G pda pda && mkdir /data && chown pda:pda /data

COPY --from=builder /opt/pdnsadmin /opt/pdnsadmin
COPY --from=builder /root/.local /opt/.local

RUN echo -e "import os\n\
from os import environ, path\n\
basedir = os.path.abspath(os.path.dirname(__file__))\n\
BIND_ADDRESS = '0.0.0.0'\n\
TIMEOUT = 10\n\
LOG_LEVEL = 'ALERT'\n\
LOG_FILE = '/dev/stderr'\n\
SALT = '$2b$12$yLUMTIfl21FKJQpTkRQXCu'\n\
UPLOAD_DIR = os.path.join(basedir, 'upload')\n\
SAML_ENABLED = False\n\
OFFLINE_MODE = False\n\
SECRET_KEY = environ.get('PDNSADMIN_SECRET_KEY')\n\
PORT = environ.get('PDNSADMIN_PORT')\n\
SQLA_DB_USER = environ.get('PDNSADMIN_SQLA_DB_USER')\n\
SQLA_DB_PASSWORD = environ.get('PDNSADMIN_SQLA_DB_PASSWORD')\n\
SQLA_DB_HOST = environ.get('PDNSADMIN_SQLA_DB_HOST')\n\
SQLA_DB_PORT = environ.get('PDNSADMIN_SQLA_DB_PORT')\n\
SQLA_DB_NAME = environ.get('PDNSADMIN_SQLA_DB_NAME')\n\
SQLALCHEMY_TRACK_MODIFICATIONS = True\n\
SQLALCHEMY_DATABASE_URI = 'mysql://'+SQLA_DB_USER+':'+SQLA_DB_PASSWORD+'@'+SQLA_DB_HOST+':'+str(SQLA_DB_PORT)+'/'+SQLA_DB_NAME\n\
" >/opt/pdnsadmin/config.py

ADD entrypoint.sh /entrypoint.sh
ADD mysql /usr/bin/mysql
RUN chmod 0755 /entrypoint.sh && chmod 0755 /usr/bin/mysql && chmod -fR 755 /opt/.local

WORKDIR /opt/pdnsadmin

EXPOSE 9191/tcp
ENTRYPOINT ["/entrypoint.sh"]
#HEALTHCHECK CMD ["curl","-s","-o /dev/null","http://127.0.0.1/"]
#ENTRYPOINT ["/usr/bin/top"]
#CMD ["gunicorn","powerdnsadmin:create_app()","--user","pda","--group","pda"]