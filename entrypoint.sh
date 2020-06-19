#!/bin/sh

#Based in work from Khanh Ngo "k@ndk.name" (https://github.com/ngoduykhanh/PowerDNS-Admin/blob/master/docker/PowerDNS-Admin/Dockerfile)

export PATH=$PATH:/opt/.local/bin
export DB_MIGRATION_DIR='/opt/pdnsadmin/migrations'
export PYTHONPATH=/opt/.local/lib/python3.8/site-packages/
export FLASK_CONF=/opt/pdnsadmin/config.py

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

#cd /opt/pdnsadmin
#virtualenv --system-site-packages --no-setuptools --no-pip powerdnsadmin
#source ./powerdnsadmin/bin/activate
#export FLASK_APP=/opt/pdnsadmin/powerdnsadmin/__init__.py

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

[ $(id -u) -eq 0 ] && su -s /bin/sh pda -c "gunicorn -t 120 --workers 4 --bind '0.0.0.0:${PDNSADMIN_PORT}' --log-level info 'powerdnsadmin:create_app()'" \
  || gunicorn -t 120 --workers 4 --bind '0.0.0.0:${PDNSADMIN_PORT}' --log-level info 'powerdnsadmin:create_app()'
