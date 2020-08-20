# FROM ubuntu:18.04
FROM tomcat:8.5.57-jdk8-openjdk-buster

ENV HMDM_SQL_HOST=localhost \
    HMDM_SQL_PORT=5432 \
    HMDM_SQL_BASE=hmdm \
    HMDM_SQL_USER=hmdm \
    HMDM_SQL_PASS=Q1XIpOTkWU9Z \
    HMDM_LANGUAGE='en' \
    HMDM_TOMTCAT_PORT="8080" \ 
    HMDM_TOMTCAT_HOST="localhost" \
    HMDM_TOMTCAT_PORTOCOL=http \
    HMDM_TOMTCAT_DOMAIN="0.0.0.0" 

RUN mkdir -p /home/hmdmr && cd /home/hmdmr
WORKDIR /home/hmdmr

RUN apt-get update -y
RUN apt-get install android-tools-adb android-tools-fastboot postgresql -y
RUN apt install aapt wget unzip sudo -y
RUN wget https://h-mdm.com/files/hmdm-3.23-install-ubuntu.zip
RUN unzip hmdm-3.23-install-ubuntu.zip
RUN service postgresql start && \
    sudo -u postgres psql -c "CREATE USER hmdm WITH PASSWORD '$HMDM_SQL_PASS';" && \
    sudo -u postgres psql -c "CREATE DATABASE hmdm WITH OWNER=hmdm;"


COPY etc/docker-entrypoint.sh /hmdm-entrypoint.sh
COPY etc/hmdm_install.sh /home/hmdmr/
RUN chmod 775 /hmdm-entrypoint.sh /home/hmdmr/hmdm-install/hmdm_install.sh

# RUN cp /home/hmdmr/hmdm.xml /usr/local/tomcat8/conf/Catalina/localhost//hmdm.xml