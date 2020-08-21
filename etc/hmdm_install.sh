#!/bin/bash
#
# Headwind MDM installer script
# Tested on Ubuntu Linux 18.04 LTS, 19.10
#
REPOSITORY_BASE=https://h-mdm.com/files
CLIENT_VERSION=3.35
DEFAULT_SQL_HOST=localhost
DEFAULT_SQL_PORT=5432
DEFAULT_SQL_BASE=hmdm
DEFAULT_SQL_USER=hmdm
DEFAULT_SQL_PASS='topsecret'
DEFAULT_LOCATION="/opt/hmdm"
TOMCAT_HOME=$(ls -d /var/lib/tomcat* | tail -n1)
TOMCAT_ENGINE="Catalina"
TOMCAT_HOST="localhost"
DEFAULT_PROTOCOL=http
DEFAULT_BASE_DOMAIN="0.0.0.0"
DEFAULT_BASE_PATH="/hmdm"
DEFAULT_PORT="8080"
TEMP_DIRECTORY="/tmp"
TEMP_SQL_FILE="$TEMP_DIRECTORY/hmdm_init.sql"
TOMCAT_USER=$(ls -ld $TOMCAT_HOME/webapps | awk '{print $3}')

LANGUAGE=en
TOMCAT_HOME=/usr/local/tomcat


if [ ! -z "$HMDM_SQL_HOST" ]; then
    SQL_HOST=$HMDM_SQL_HOST
else
    SQL_HOST=$DEFAULT_SQL_HOST
fi

if [ ! -z "$HMDM_SQL_PORT" ]; then
    SQL_PORT=$HMDM_SQL_PORT
else
    SQL_PORT=$DEFAULT_SQL_PORT
fi

if [ ! -z "$HMDM_SQL_BASE" ]; then
    SQL_BASE=$HMDM_SQL_BASE
else
    SQL_BASE=$DEFAULT_SQL_BASE
fi


if [ ! -z "$HMDM_SQL_USER" ]; then
    SQL_USER=$HMDM_SQL_USER
else
    SQL_USER=$DEFAULT_SQL_USER
fi
if [ ! -z "$HMDM_SQL_PASS" ]; then
    SQL_PASS=$HMDM_SQL_PASS
else
    SQL_PASS=$DEFAULT_SQL_PASS
fi

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
LANGUAGE="$DEFAULT_HMDM_LANGUAGE"

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


if [ ! -z "$HMDM_TOMTCAT_PORTOCOL" ]; then
    PROTOCOL=$HMDM_TOMTCAT_PORTOCOL
else
    PROTOCOL=$DEFAULT_PROTOCOL
fi
if [ ! -z "$HMDM_BASE_DOMAIN" ]; then
    BASE_DOMAIN=$HMDM_BASE_DOMAIN
else
    BASE_DOMAIN=$DEFAULT_BASE_DOMAIN
fi
if [ ! -z "$HMDM_BASE_DOMAIN" ]; then
    BASE_DOMAIN=$HMDM_BASE_DOMAIN
else
    BASE_DOMAIN=$DEFAULT_BASE_DOMAIN
fi
PORT=$DEFAULT_PORT

# Set the default URL path.
if [ ! -z "$HMDM_BASE_PATH" ]; then
    BASE_PATH=$HMDM_BASE_PATH
else
    BASE_PATH=$DEFAULT_BASE_PATH
fi

TOMCAT_DEPLOY_PATH=$BASE_PATH
if [ "$BASE_PATH" == "ROOT" ]; then
    BASE_PATH=""
fi 

if [[ ! -z "$HMDM_BASE_DOMAIN" ]]; then
    BASE_HOST="$HMDM_BASE_DOMAIN:$PORT"
else
    BASE_HOST="$BASE_DOMAIN:$PORT"
fi

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
echo "Tomcat config file created: $TOMCAT_CONFIG_PATH/$TOMCAT_DEPLOY_PATH.xml"
chmod 644 $TOMCAT_CONFIG_PATH/$TOMCAT_DEPLOY_PATH.xml

echo "Deploying $SERVER_WAR to Tomcat: $TOMCAT_HOME/webapps/$TOMCAT_DEPLOY_PATH.war"
rm -f $INSTALL_FLAG_FILE > /dev/null 2>&1
cp $SERVER_WAR $TOMCAT_HOME/webapps/$TOMCAT_DEPLOY_PATH.war
chmod 644 $TOMCAT_HOME/webapps/$TOMCAT_DEPLOY_PATH.war

# Waiting until the end of deployment
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

exit 1
