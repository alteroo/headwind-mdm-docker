#!/bin/bash
#
# Headwind MDM installer script
# Tested on Ubuntu Linux 18.04 LTS, 19.10
#
HMDM_INSTALLED_ID=$HMDM_VERSION:$HMDM_CLIENT_VERSION
HMDM_INSTALLED_VERSIONS_FILE=/installed_versions
if [ "$HMDM_INSTALLED_ID" == "$(cat $HMDM_INSTALLED_VERSIONS_FILE)" ] ;then
    echo Version already initialised
    exit 1
fi

REPOSITORY_BASE=https://h-mdm.com/files
TOMCAT_HOME=/usr/local/tomcat
CLIENT_VERSION=$HMDM_CLIENT_VERSION
DEFAULT_LOCATION="/opt/hmdm"
TOMCAT_ENGINE="Catalina"
TOMCAT_HOST="localhost"
DEFAULT_PROTOCOL=http
DEFAULT_BASE_DOMAIN="0.0.0.0"
DEFAULT_BASE_PATH="/hmdm"
DEFAULT_PORT="8080"
TEMP_DIRECTORY="/tmp"
TEMP_SQL_FILE="$TEMP_DIRECTORY/tmp.sql"
TOMCAT_USER=$(ls -ld $TOMCAT_HOME/webapps | awk '{print $3}')


LANGUAGE=${HMDM_LANGUAGE:-en}
SQL_HOST=${HMDM_SQL_HOST:-localhost}
SQL_PORT=${HMDM_SQL_PORT:-5432}
SQL_BASE=${HMDM_SQL_DB:-hmdm}
SQL_USER=${HMDM_SQL_USER:-hmdm}
SQL_PASS=${HMDM_SQL_PASSWORD:-topsecret}

PROTOCOL=${HMDM_TOMTCAT_PORTOCOL:-$DEFAULT_PROTOCOL}
BASE_DOMAIN=${HMDM_BASE_DOMAIN:-$DEFAULT_BASEDOMAIN}
PORT=${HMDM_PORT:-$DEFAULT_PORT}

BASE_PATH="${HMDM_BASE_PATH:-DEFAULT_BASE_PATH}"
TOMCAT_DEPLOY_PATH=$BASE_PATH
if [ "$HMDM_PORT" == "SAME" ]; then
    PORT=""
fi
if [ "$BASE_PATH" == "ROOT" ]; then
    BASE_PATH=""
fi
BASE_HOST="$HMDM_BASE_DOMAIN:$PORT"

# Check if we are root
CURRENTUSER=$(whoami)

if [[ "$EUID" -ne 0 ]]; then
    echo "It is recommended to run the installer script as root."
    read -p "Proceed as $CURRENTUSER (Y/n)? " -n 1 -r
    echo
    if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check if there's an install folder
if [ ! -d "./install" ]; then
    echo "Cannot find installation directory (install)"
    echo "Please cd to the installation directory before running script!"
    exit 1
fi

# Check if there's aapt tool installed
if ! which aapt > /dev/null; then
    echo "Android App Packaging Tool is not installed!"
    echo "Please run: apt install aapt"
    exit 1
fi

# Check PostgreSQL installation
if ! which psql > /dev/null; then
    echo "PostgreSQL is not installed!"
    echo "Please run: apt install postgresql"
    exit 1
fi

# Check if tomcat user exists
getent passwd $TOMCAT_USER > /dev/null
if [ "$?" -ne 0 ]; then
    # Try tomcat8
    TOMCAT_USER="tomcat8"
    getent passwd $TOMCAT_USER >/dev/null
    if [ "$?" -ne 0 ]; then
        echo "Tomcat is not installed! User tomcat not found."
        echo "If you're running Tomcat as different user,"
        echo "please edit this script and update the TOMCAT_USER variable."
        exit 1
    fi
fi

# Search for the WAR
SERVER_WAR=./server/target/launcher.war
if [ ! -f $SERVER_WAR ]; then
    SERVER_WAR=$(ls hmdm*.war | tail -1)
fi
if [ ! -f $SERVER_WAR ]; then
    echo "FAILED to find the WAR file of Headwind MDM!"
    echo "Did you compile the project?"
    exit 1
fi

#read -p "Are you installing an open-source version? (Y/n)? " -n 1 -r
#echo
#if [[ $REPLY =~ ^[Yy]$ ]]; then
    CLIENT_VARIANT="os"
#else
#    CLIENT_VARIANT="master"
#fi

CLIENT_APK="hmdm-$CLIENT_VERSION-$CLIENT_VARIANT.apk"

echo "PostgreSQL database setup"
echo "========================="
echo "Make sure you've installed PostgreSQL and created the database:"
echo "# CREATE USER hmdm WITH PASSWORD 'topsecret';"
echo "# CREATE DATABASE hmdm WITH OWNER=hmdm;"
echo

PSQL_CONNSTRING="postgresql://$SQL_USER:$SQL_PASS@$SQL_HOST:$SQL_PORT/$SQL_BASE"
echo "$PSQL_CONNSTRING"
# Check the PostgreSQL access
echo "SELECT 1" | psql $PSQL_CONNSTRING > /dev/null 2>&1

echo
echo "File storage setup"
echo "=================="
echo "Please choose where the files uploaded to Headwind MDM will be stored"
echo "If the directory doesn't exist, it will be created"
echo "##### FOR TOMCAT 9, USE SANDBOXED DIR: /var/lib/tomcat9/work #####"
echo
echo "Default Headwind MDM directory [$DEFAULT_LOCATION]"
echo 

# Create directories
if [ ! -d $LOCATION ]; then
    mkdir -p $LOCATION || exit 1
    chown $TOMCAT_USER:$TOMCAT_USER $LOCATION || exit 1
fi
if [ ! -d $LOCATION/files ]; then
    mkdir $LOCATION/files
    chown $TOMCAT_USER:$TOMCAT_USER $LOCATION/files || exit 1
fi
if [ ! -d $LOCATION/plugins ]; then
    mkdir $LOCATION/plugins
    chown $TOMCAT_USER:$TOMCAT_USER $LOCATION/plugins || exit 1
fi
if [ ! -d $LOCATION/logs ]; then
    mkdir $LOCATION/logs
    chown $TOMCAT_USER:$TOMCAT_USER $LOCATION/logs || exit 1
fi

INSTALL_FLAG_FILE="$LOCATION/hmdm_install_flag"

# Logger configuration
cat ./install/log4j_template.xml | sed "s|_BASE_DIRECTORY_|$LOCATION|g" > $LOCATION/log4j-hmdm.xml
chown $TOMCAT_USER:$TOMCAT_USER $LOCATION/log4j-hmdm.xml

echo
echo "Web application setup"
echo "====================="
echo "Headwind MDM requires access from Internet"
echo "Please assign a public domain name to this server"
echo



echo
echo "Ready to install!"
echo "Location on server: $LOCATION"
echo "URL: $PROTOCOL://$BASE_HOST$BASE_PATH"

# Prepare the XML config
if [ ! -f ./install/context_template.xml ]; then
    echo "ERROR: Missing ./install/context_template.xml!"
    echo "The package seems to be corrupted!"
    exit 1
fi

# Removing old application
rm -rf $TOMCAT_HOME/webapps/$TOMCAT_DEPLOY_PATH > /dev/null 2>&1
rm -f $TOMCAT_HOME/webapps/$TOMCAT_DEPLOY_PATH.war > /dev/null 2>&1

# Waiting for undeploy
sleep 5

TOMCAT_CONFIG_PATH=$TOMCAT_HOME/conf/$TOMCAT_ENGINE/$TOMCAT_HOST
if [ ! -d $TOMCAT_CONFIG_PATH ]; then
    mkdir -p $TOMCAT_CONFIG_PATH || exit 1
    chown root:$TOMCAT_USER $TOMCAT_CONFIG_PATH
    chmod 755 $TOMCAT_CONFIG_PATH
fi
cat ./install/context_template.xml | sed "s|_SQL_HOST_|$SQL_HOST|g; s|_SQL_PORT_|$SQL_PORT|g; s|_SQL_BASE_|$SQL_BASE|g; s|_SQL_USER_|$SQL_USER|g; s|_SQL_PASS_|$SQL_PASS|g; s|_BASE_DIRECTORY_|$LOCATION|g; s|_PROTOCOL_|$PROTOCOL|g; s|_BASE_HOST_|$BASE_HOST|g; s|_BASE_DOMAIN_|$BASE_DOMAIN|g; s|_BASE_PATH_|$BASE_PATH|g; s|_INSTALL_FLAG_|$INSTALL_FLAG_FILE|g" > $TOMCAT_CONFIG_PATH/$TOMCAT_DEPLOY_PATH.xml
if [ "$?" -ne 0 ]; then
    echo "Failed to create a Tomcat config file $TOMCAT_CONFIG_PATH/$TOMCAT_DEPLOY_PATH.xml!"
    exit 1
fi 

chmod 644 $TOMCAT_CONFIG_PATH/$TOMCAT_DEPLOY_PATH.xml

echo "Deploying $SERVER_WAR to Tomcat: $TOMCAT_HOME/webapps/$TOMCAT_DEPLOY_PATH.war"
rm -f $INSTALL_FLAG_FILE > /dev/null 2>&1
cp $SERVER_WAR $TOMCAT_HOME/webapps/$TOMCAT_DEPLOY_PATH.war
chmod 644 $TOMCAT_HOME/webapps/$TOMCAT_DEPLOY_PATH.war

echo Waiting until the end of deployment
catalina.sh start
sleep 10
SUCCESSFUL_DEPLOY=0
for i in {1..120}; do
    if [ -f $INSTALL_FLAG_FILE ]; then
        if [[ $(< $INSTALL_FLAG_FILE) == "OK" ]]; then
            SUCCESSFUL_DEPLOY=1
        else
            SUCCESSFUL_DEPLOY=0
        fi
        break
    fi
    echo -n "."
    sleep 1
done
echo
killall java
rm -f $INSTALL_FLAG_FILE > /dev/null 2>&1
if [ $SUCCESSFUL_DEPLOY -ne 1 ]; then
    echo "ERROR: failed to deploy WAR file!"
    echo "Please check $TOMCAT_HOME/logs/catalina.out for details."
    exit 1
fi

echo "Deployment successful, initializing the database..."

# Initialize database
cat ./install/sql/hmdm_init.$LANGUAGE.sql | sed "s|_HMDM_BASE_|$LOCATION|g; s|_HMDM_VERSION_|$CLIENT_VERSION|g; s|_HMDM_APK_|$CLIENT_APK|g" > $TEMP_SQL_FILE
cat $TEMP_SQL_FILE | psql $PSQL_CONNSTRING > /dev/null 2>&1
if [ "$?" -ne 0 ]; then
    echo "ERROR: failed to execute SQL script!"
    echo "See $TEMP_SQL_FILE for details."
    exit 1
fi
rm -f $TEMP_SQL_FILE > /dev/null 2>&1

echo
echo "======================================"
echo "Headwind MDM has been installed!"
echo "To continue, open in your web browser:"
echo "$PROTOCOL://$BASE_HOST$BASE_PATH"
echo "Login: admin:admin"


echo "UPDATE applicationversions SET url=REPLACE(url, '$PROTOCOL://$BASE_HOST$BASE_PATH', 'https://h-mdm.com') WHERE url IS NOT NULL" | psql $PSQL_CONNSTRING >/dev/null 2>&1
FILES=$(echo "SELECT url FROM applicationversions WHERE url IS NOT NULL" | psql $PSQL_CONNSTRING 2>/dev/null | tail -n +3 | head -n -2)
CURRENT_DIR=$(pwd)
cd $LOCATION/files
for FILE in $FILES; do
    echo "Downloading $FILE..."
    wget $FILE
done
chown $TOMCAT_USER:$TOMCAT_USER *
echo "UPDATE applicationversions SET url=REPLACE(url, 'https://h-mdm.com', '$PROTOCOL://$BASE_HOST$BASE_PATH') WHERE url IS NOT NULL" | psql $PSQL_CONNSTRING >/dev/null 2>&1
cd $CURRENT_DIR


echo $HMDM_INSTALLED_ID > ${HMDM_INSTALLED_VERSIONS_FILE}

exit 1
