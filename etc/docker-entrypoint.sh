#!/bin/sh

# Start postgres
catalina.sh start
adb devices
service postgresql restart

# Create database if doesn't exist
if [ $HMDM_SQL_USER != 'hmdm' ]; then
    sudo -u postgres psql -c "CREATE USER $HMDM_SQL_USER WITH PASSWORD '$HMDM_SQL_PASS';"
fi

if [ $HMDM_SQL_BASE != 'hmdm' ]; then
    sudo -u postgres psql -c "CREATE DATABASE $HMDM_SQL_BASE WITH OWNER=$HMDM_SQL_USER;"
fi

if [ ! -f '/usr/local/tomcat/conf/Catalina/localhost//hmdm.xml' ]; then
    cd /home/hmdmr/hmdm-install/
    ./hmdm_install.sh
fi

#change the russian text in the dashboard to english
sudo -u postgres psql -d hmdm -c "UPDATE userroles SET name = 'Super Administrator', description = 'The all seeing eye of sauron' WHERE id = '1';" 
sudo -u postgres psql -d hmdm -c "UPDATE userroles SET name = 'Administrator', description = 'Serves as the administrator for one customer record' WHERE id = '2';"
sudo -u postgres psql -d hmdm -c "UPDATE userroles SET name = 'User', description = 'User for one customer record' WHERE id = '3';"
sudo -u postgres psql -d hmdm -c "UPDATE userroles SET name = 'Observer', description = 'The observer is watching keenly' WHERE id = '100';"
sudo -u postgres psql -d hmdm -c "UPDATE groups SET name = 'Default' WHERE id = '1';"
sudo -u postgres psql -d hmdm -c "UPDATE configurations SET name = 'Default', description = 'Basic configuration for all devices' WHERE id = '1';"

catalina.sh stop
sleep 30
cd ..
catalina.sh run

