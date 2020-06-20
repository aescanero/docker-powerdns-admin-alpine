#!/bin/sh

#Based in work from Khanh Ngo "k@ndk.name" (https://github.com/ngoduykhanh/PowerDNS-Admin/blob/master/docker/PowerDNS-Admin/Dockerfile)

export PATH=$PATH:/opt/.local/bin
export PYTHONPATH=/opt/.local/lib/python3.8/site-packages/
export FLASK_CONF=/opt/pdnsadmin/config.py
export DB_MIGRATION_DIR_INIT='/opt/pdnsadmin/migrations.init'
export DB_MIGRATION_DIR_UPDATE='/opt/pdnsadmin/migrations.update'

[ -z ${PDNS_PROTO} ] && export PDNS_PROTO="http"
[ -z ${PDNS_PORT} ] && export PDNS_PORT=8081
[ -z ${PDNS_HOST} ] && export PDNS_HOST="127.0.0.1"
[ -z ${PDNSADMIN_SQLA_DB_PORT} ] && export PDNSADMIN_SQLA_DB_PORT=3306
[ -z ${PDNSADMIN_PORT} ] && export PDNSADMIN_PORT=9191
[ -z ${PDNSADMIN_SECRET_KEY} ] && export PDNSADMIN_SECRET_KEY='secret'
[ -z ${PDNSADMIN_SQLA_DB_USER} ] && export PDNSADMIN_SQLA_DB_USER='powerdns'
[ -z ${PDNSADMIN_SQLA_DB_PASSWORD} ] && export PDNSADMIN_SQLA_DB_PASSWORD='secret'
[ -z ${PDNSADMIN_SQLA_DB_HOST} ] && export PDNSADMIN_SQLA_DB_HOST='127.0.0.1'
[ -z ${PDNSADMIN_SQLA_DB_NAME} ] && export PDNSADMIN_SQLA_DB_NAME='powerdns'


# Wait for us to be able to connect to MySQL before proceeding
echo "===> Waiting for $PDNSADMIN_SQLA_DB_HOST MySQL service"
until nc -zv $PDNSADMIN_SQLA_DB_HOST $PDNSADMIN_SQLA_DB_PORT;
do
  echo "MySQL ($PDNSADMIN_SQLA_DB_HOST) is unavailable - sleeping"
  sleep 5
done

if mysql -h${PDNSADMIN_SQLA_DB_HOST} -u${PDNSADMIN_SQLA_DB_USER} -p${PDNSADMIN_SQLA_DB_PASSWORD} -P${PDNSADMIN_SQLA_DB_PORT} ${PDNSADMIN_SQLA_DB_NAME} -e "DESCRIBE domain_template_record;" 2>&1 \
  |grep "Table 'powerdns.domain_template_record' doesn't exist" >/dev/null
then
# INIT DB
  flask db upgrade --directory "/opt/pdnsadmin/migrations.init"
else
# UPDATE DB if needed
  flask db upgrade --directory "/opt/pdnsadmin/migrations.update"
fi

echo "===> Update PDNS API connection info"
# initial setting if not available in the DB
mysql -h${PDNSADMIN_SQLA_DB_HOST} -u${PDNSADMIN_SQLA_DB_USER} -p${PDNSADMIN_SQLA_DB_PASSWORD} -P${PDNSADMIN_SQLA_DB_PORT} ${PDNSADMIN_SQLA_DB_NAME} -e "INSERT INTO setting (name, value) SELECT * FROM (SELECT 'pdns_api_url',
 '${PDNS_PROTO}://${PDNS_HOST}:${PDNS_PORT}') AS tmp WHERE NOT EXISTS (SELECT name FROM setting WHERE name = 'pdns_api_url') LIMIT 1;"
mysql -h${PDNSADMIN_SQLA_DB_HOST} -u${PDNSADMIN_SQLA_DB_USER} -p${PDNSADMIN_SQLA_DB_PASSWORD} -P${PDNSADMIN_SQLA_DB_PORT} ${PDNSADMIN_SQLA_DB_NAME} -e "INSERT INTO setting (name, value) SELECT * FROM (SELECT 'pdns_api_key',
 '${PDNS_API_KEY}') AS tmp WHERE NOT EXISTS (SELECT name FROM setting WHERE name = 'pdns_api_key') LIMIT 1;"
[ ! -z ${DOMAIN} ] && mysql -h${PDNSADMIN_SQLA_DB_HOST} -u${PDNSADMIN_SQLA_DB_USER} -p${PDNSADMIN_SQLA_DB_PASSWORD} -P${PDNSADMIN_SQLA_DB_PORT} ${PDNSADMIN_SQLA_DB_NAME} -e "INSERT INTO domains (name, master, type, account)
  SELECT * FROM (SELECT '${DOMAIN}','','NATIVE','') AS tmp WHERE NOT EXISTS (SELECT name FROM domains WHERE name = '${DOMAIN}') LIMIT 1;"

if [ $(id -u) -eq 0 ] 
then
  su -s /bin/sh pda -c "gunicorn -t 120 --workers 4 --bind '0.0.0.0:${PDNSADMIN_PORT}' --log-level info 'powerdnsadmin:create_app()'"
else
  gunicorn -t 120 --workers 4 --bind '0.0.0.0:${PDNSADMIN_PORT}' --log-level info 'powerdnsadmin:create_app()'
fi
