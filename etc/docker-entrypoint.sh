#!/bin/sh

# Start postgres
adb devices

if [ ! -f '/usr/local/tomcat/conf/Catalina/localhost//hmdm.xml' ]; then
    cd /home/hmdmr/hmdm-install/
    ./hmdm_install.sh
fi

# #change the russian text in the dashboard to english
# PGPASSWORD=${HMDM_SQL_PASSWORD:-topsecret} psql -h ${HMDM_SQL_HOST:-localhost} -u postgres ${HMDM_SQL_USER:-psql} -d ${HMDM_SQL_DB:-hmdm} -c "UPDATE userroles SET name = 'Super Administrator', description = 'The all seeing eye of sauron' WHERE id = '1';"
# PGPASSWORD=${HMDM_SQL_PASSWORD:-topsecret} psql -h ${HMDM_SQL_HOST:-localhost} -u postgres ${HMDM_SQL_USER:-psql} -d ${HMDM_SQL_DB:-hmdm} -c "UPDATE userroles SET name = 'Administrator', description = 'Serves as the administrator for one customer record' WHERE id = '2';"
# PGPASSWORD=${HMDM_SQL_PASSWORD:-topsecret} psql -h ${HMDM_SQL_HOST:-localhost} -u postgres ${HMDM_SQL_USER:-psql} -d ${HMDM_SQL_DB:-hmdm} -c "UPDATE userroles SET name = 'User', description = 'User for one customer record' WHERE id = '3';"
# PGPASSWORD=${HMDM_SQL_PASSWORD:-topsecret} psql -h ${HMDM_SQL_HOST:-localhost} -u postgres ${HMDM_SQL_USER:-psql} -d ${HMDM_SQL_DB:-hmdm} -c "UPDATE userroles SET name = 'Observer', description = 'The observer is watching keenly' WHERE id = '100';"
# PGPASSWORD=${HMDM_SQL_PASSWORD:-topsecret} psql -h ${HMDM_SQL_HOST:-localhost} -u postgres ${HMDM_SQL_USER:-psql} -d ${HMDM_SQL_DB:-hmdm} -c "UPDATE groups SET name = 'Default' WHERE id = '1';"
# PGPASSWORD=${HMDM_SQL_PASSWORD:-topsecret} psql -h ${HMDM_SQL_HOST:-localhost} -u postgres ${HMDM_SQL_USER:-psql} -d ${HMDM_SQL_DB:-hmdm} -c "UPDATE configurations SET name = 'Default', description = 'Basic configuration for all devices' WHERE id = '1';"

cd ..
catalina.sh run
