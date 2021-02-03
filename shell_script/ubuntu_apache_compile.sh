#!/bin/bash

### BEGIN INIT INFO
### Provides     : httpd 2.4.46
### Supported OS : Ubuntu 18.04
### Description  : Install the Apache web server as a source compilation
### END INIT INFO



# Exit immediately if a command exits with a non-zero status
set -e

### Check if this user has sudo privilege or not
if [ "$EUID" -ne 0 ]; then
    echo "##############################################"
    echo ""
    echo "ROOT Privilege is required."
    echo ""
    echo "Usage : sudo ./ubuntu_mod_jk_link.sh"
    echo ""
    echo "##############################################"
    exit
fi


if [ $(cat /etc/os-release | grep "^NAME" | awk -F= '{print $2}' | awk -F\" '{print $2}') != 'Ubuntu' ]; then
    echo "#############################################"
    echo ""
    echo "This script is for Ubuntu 18.04 only."
    echo ""
    echo "#############################################"
    exit
fi


### Set Variable

HTTPD_VERSION=2.4.46
PCRE_VERSION=8.44
APRUTIL_VERSION=1.6.1
APR_VERSION=1.7.0


### Define Functions

show_message() {
    echo "#############################################"
    echo ""
    echo "$1"
    echo ""
    echo "#############################################"
    sleep 5
}



# Install the necessary packages
apt-get update -y
apt-get install build-essential -y
apt-get install libexpat1-dev -y

if [ ! -d /usr/local/src ]; then
        mkdir /usr/local/src
fi


show_message "Install PCRE, APR, APR-util"


## Get source files from internet
cd /usr/local/src
wget https://ftp.pcre.org/pub/pcre/pcre-$PCRE_VERSION.tar.gz
wget https://downloads.apache.org//apr/apr-$APR_VERSION.tar.gz
wget https://downloads.apache.org//apr/apr-util-$APRUTIL_VERSION.tar.gz
wget https://downloads.apache.org//httpd/httpd-$HTTPD_VERSION.tar.gz

## tar 프로그램으로 tar.gz 압축 파일을 풀어준다.
tar xvfz apr-$APR_VERSION.tar.gz
tar xvfz apr-util-$APRUTIL_VERSION.tar.gz
tar xvfz pcre-$PCRE_VERSION.tar.gz
tar xvfz httpd-$HTTPD_VERSION.tar.gz

## 1. apr
cd /usr/local/src/apr-$APR_VERSION
./configure --prefix=/usr/local/apr
make; make install

## 2. apr-util
cd /usr/local/src/apr-util-$APRUTIL_VERSION
./configure --prefix=/usr/local/apr-util --with-apr=/usr/local/apr
make; make install

## 3. PCRE
cd /usr/local/src/pcre-$PCRE_VERSION
./configure --prefix=/usr/local/pcre
make; make install


cd /usr/local/src/httpd-$HTTPD_VERSION

./configure --prefix=/usr/local/apache \
--enable-module=so --enable-rewrite --enable-so \
--with-apr=/usr/local/apr \
--with-apr-util=/usr/local/apr-util \
--with-pcre=/usr/local/pcre \
--enable-mods-shared=all

make; make install




## create systemd service file and register httpd service

if [ -d /lib/systemd/system ]; then
cat << EOF > /lib/systemd/system/httpd.service
[Unit]
Description=apache
After=network.target syslog.target

[Service]
Type=forking
User=root
Group=root

ExecStart=/usr/local/apache/bin/apachectl start
ExecStop=/usr/local/apache/bin/apachectl stop

Umask=007
RestartSec=10
Restart=always

[Install]
WantedBy=multi-user.target
EOF

elif [ -d /usr/lib/systemd/system ]; then
cat << EOF > /lib/systemd/system/httpd.service
[Unit]
Description=apache
After=network.target syslog.target

[Service]
Type=forking
User=root
Group=root

ExecStart=/usr/local/apache/bin/apachectl start
ExecStop=/usr/local/apache/bin/apachectl stop

Umask=007
RestartSec=10
Restart=always

[Install]
WantedBy=multi-user.target
EOF

fi


show_message "Installation Completed"