#!/bin/sh

#Based in work from Khanh Ngo "k@ndk.name" (https://github.com/ngoduykhanh/PowerDNS-Admin/blob/master/docker/PowerDNS-Admin/Dockerfile)

DB_MIGRATION_DIR='/opt/pdnsadmin/migrations'

[ -z ${PDNS_PROTO} ] && PDNS_PROTO="http"
[ -z ${PDNS_PORT} ] && PDNS_PORT=8081
[ -z ${PDNS_HOST} ] && PDNS_HOST="127.0.0.1"
[ -z ${PDNSADMIN_SQLA_DB_PORT} ] && PDNSADMIN_SQLA_DB_PORT=3306
[ -z ${PDNSADMIN_PORT} ] && PDNSADMIN_PORT=9191
[ -z ${PDNSADMIN_SECRET_KEY} ] && PDNSADMIN_SECRET_KEY='secret'
[ -z ${PDNSADMIN_SQLA_DB_USER} ] && PDNSADMIN_SQLA_DB_USER='powerdns'
[ -z ${PDNSADMIN_SQLA_DB_PASSWORD} ] && PDNSADMIN_SQLA_DB_PASSWORD='secret'
[ -z ${PDNSADMIN_SQLA_DB_HOST} ] && PDNSADMIN_SQLA_DB_HOST='127.0.0.1'
[ -z ${PDNSADMIN_SQLA_DB_NAME} ] && PDNSADMIN_SQLA_DB_NAME='powerdns'


# Wait for us to be able to connect to MySQL before proceeding
echo "===> Waiting for $PDNSADMIN_SQLA_DB_HOST MySQL service"
until nc -zv $PDNSADMIN_SQLA_DB_HOST $PDNSADMIN_SQLA_DB_PORT;
do
  echo "MySQL ($PDNSADMIN_SQLA_DB_HOST) is unavailable - sleeping"
  sleep 5
done

cat >/opt/pdnsadmin/config.py <<EOF
import os
basedir = os.path.abspath(os.path.dirname(__file__))
BIND_ADDRESS = '0.0.0.0'
TIMEOUT = 10
LOG_LEVEL = 'ALERT'
LOG_FILE = 'logfile.log'
SALT = '$2b$12$yLUMTIfl21FKJQpTkRQXCu'
UPLOAD_DIR = os.path.join(basedir, 'upload')
SAML_ENABLED = False
SAML_DEBUG = False
SAML_PATH = os.path.join(os.path.dirname(__file__), 'saml')
SAML_METADATA_URL = 'https://<hostname>/FederationMetadata/2007-06/FederationMetadata.xml'
SAML_METADATA_CACHE_LIFETIME = 1
SAML_ATTRIBUTE_ACCOUNT = 'https://example.edu/pdns-account'
SAML_SP_ENTITY_ID = 'http://<SAML SP Entity ID>'
SAML_SP_CONTACT_NAME = '<contact name>'
SAML_SP_CONTACT_MAIL = '<contact mail>'
SAML_SIGN_REQUEST = False
SAML_LOGOUT = False
EOF

echo "SECRET_KEY = '${PDNSADMIN_SECRET_KEY}'" >>/opt/pdnsadmin/config.py
echo "PORT = ${PDNSADMIN_PORT}" >>/opt/pdnsadmin/config.py
echo "SQLA_DB_USER = '${PDNSADMIN_SQLA_DB_USER}'" >>/opt/pdnsadmin/config.py
echo "SQLA_DB_PASSWORD = '${PDNSADMIN_SQLA_DB_PASSWORD}'" >>/opt/pdnsadmin/config.py
echo "SQLA_DB_HOST = '${PDNSADMIN_SQLA_DB_HOST}'" >>/opt/pdnsadmin/config.py
echo "SQLA_DB_PORT = ${PDNSADMIN_SQLA_DB_PORT}" >>/opt/pdnsadmin/config.py
echo "SQLA_DB_NAME = '${PDNSADMIN_SQLA_DB_NAME}'" >>/opt/pdnsadmin/config.py

cat >>/opt/pdnsadmin/config.py <<EOF
SQLALCHEMY_TRACK_MODIFICATIONS = True
SQLALCHEMY_DATABASE_URI = 'mysql://'+SQLA_DB_USER+':'+SQLA_DB_PASSWORD+'@'+SQLA_DB_HOST+':'+str(SQLA_DB_PORT)+'/'+SQLA_DB_NAME
EOF

cd /opt/pdnsadmin
export FLASK_APP=/opt/pdnsadmin/powerdnsadmin/__init__.py
virtualenv --system-site-packages --no-setuptools --no-pip flask
source ./flask/bin/activate

echo "===> DB management"
if [ ! -d "${DB_MIGRATION_DIR}" ]; then
  echo "---> Running DB Init"
  flask db init --directory ${DB_MIGRATION_DIR}
  flask db migrate -m "Init DB" --directory ${DB_MIGRATION_DIR}
  flask db upgrade --directory ${DB_MIGRATION_DIR}
#  ./init_data.py
else
  echo "---> Running DB Migration"
  flask db migrate -m "Upgrade DB Schema" --directory ${DB_MIGRATION_DIR}
  flask db upgrade --directory ${DB_MIGRATION_DIR}
fi

echo "===> Update PDNS API connection info"
# initial setting if not available in the DB
mysql -h${PDNSADMIN_SQLA_DB_HOST} -u${PDNSADMIN_SQLA_DB_USER} -p${PDNSADMIN_SQLA_DB_PASSWORD} -P${PDNSADMIN_SQLA_DB_PORT} ${PDNSADMIN_SQLA_DB_NAME} -e "INSERT INTO setting (name, value) SELECT * FROM (SELECT 'pdns_api_url',
 '${PDNS_PROTO}://${PDNS_HOST}:${PDNS_PORT}') AS tmp WHERE NOT EXISTS (SELECT name FROM setting WHERE name = 'pdns_api_url') LIMIT 1;"
mysql -h${PDNSADMIN_SQLA_DB_HOST} -u${PDNSADMIN_SQLA_DB_USER} -p${PDNSADMIN_SQLA_DB_PASSWORD} -P${PDNSADMIN_SQLA_DB_PORT} ${PDNSADMIN_SQLA_DB_NAME} -e "INSERT INTO setting (name, value) SELECT * FROM (SELECT 'pdns_api_key',
 '${PDNS_API_KEY}') AS tmp WHERE NOT EXISTS (SELECT name FROM setting WHERE name = 'pdns_api_key') LIMIT 1;"
[ ! -z ${DOMAIN} ] && mysql -h${PDNSADMIN_SQLA_DB_HOST} -u${PDNSADMIN_SQLA_DB_USER} -p${PDNSADMIN_SQLA_DB_PASSWORD} -P${PDNSADMIN_SQLA_DB_PORT} ${PDNSADMIN_SQLA_DB_NAME} -e "INSERT INTO domains (name, master, type, account)
  SELECT * FROM (SELECT '${DOMAIN}','','NATIVE','') AS tmp WHERE NOT EXISTS (SELECT name FROM domains WHERE name = '${DOMAIN}') LIMIT 1;"
FLASK_APP=/opt/pdnsadmin/powerdnsadmin/__init__.py /usr/bin/gunicorn -t 120 --workers 4 --bind "0.0.0.0:${PDNSADMIN_PORT}" --log-level info app:app
