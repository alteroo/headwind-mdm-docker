FROM ubuntu:focal
FROM tomcat:9.0

ENV HMDM_LANGUAGE='en' \
    HMDM_TOMTCAT_PORT="8080" \ 
    HMDM_TOMTCAT_HOST="localhost" \
    HMDM_TOMTCAT_PORTOCOL=http \
    HMDM_TOMTCAT_DOMAIN="0.0.0.0" \
    DEBIAN_FRONTEND=noninteractive \
    HMDM_VERSION=4.03 \
    HMDM_CLIENT_VERSION=4.01

RUN mkdir -p /home/hmdmr && cd /home/hmdmr
WORKDIR /home/hmdmr

RUN apt-get update -y && apt upgrade -y
RUN apt-get install android-tools-adb android-tools-fastboot postgresql -y
RUN apt install aapt wget unzip sudo -y
RUN wget https://h-mdm.com/files/hmdm-${HMDM_VERSION}-install-ubuntu.zip
RUN unzip hmdm-${HMDM_VERSION}-install-ubuntu.zip

COPY etc/server.xml /usr/local/tomcat/conf/server.xml
COPY etc/docker-entrypoint.sh /hmdm-entrypoint.sh
COPY etc/hmdm_install.sh /home/hmdmr/hmdm-install/
RUN chmod +x /hmdm-entrypoint.sh /home/hmdmr/hmdm-install/hmdm_install.sh

CMD ["/hmdm-entrypoint.sh"]
