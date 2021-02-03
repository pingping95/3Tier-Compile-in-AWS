#!/bin/bash

### BEGIN INIT INFO
### Provides     : Tomcat 9.0.41
### Supported OS : Ubuntu 18.04
### Description  : Install the Tomcat Server as a source compilation
### END INIT INFO






# Exit immediately if a command exits with a non-zero status
set -e


if [ $(cat /etc/os-release | grep "^NAME" | awk -F= '{print $2}' | awk -F\" '{print $2}') != 'Ubuntu' ]; then
    echo "#############################################"
    echo ""
    echo "This script is for Ubuntu 18.04 only."
    echo ""
    echo "#############################################"
    exit
fi




### Set Variable

TOMCAT_VERSION=9.0.41

### Define Functions

show_message() {
    echo "#############################################"
    echo ""
    echo "$1"
    echo ""
    echo "#############################################"
    sleep 5
}



## 1. Install JRE (Java Runtime Environment)


sudo apt-get update -y
sudo apt-get install openjdk-11-jre-headless -y


## 2. Set Environment Variable into /etc/profile

sudo bash -c 'cat >> /etc/profile' << EOF
# 1.  JAVA_HOME DIR
JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64/

# 2. TOMCAT SERVER HOME DIR
CATALINA_HOME=/usr/local/tomcat

# 3. binary
PATH=$PATH:/usr/lib/jvm/java-11-openjdk-amd64/bin

export JAVA_HOME CATALINA_HOME PATH
EOF

source /etc/profile


java -version 2> /dev/null

if [ $? -ne 0 ]; then
    show_message "OpenJDK Does not installed.."
    exit 0
fi




## 3. Create Tomcat user and Install Apache Tomcat

show_message "Create Tomcat user and Install Tomcat $TOMCAT_VERSION"



sudo groupadd tomcat
sudo useradd -s `which nologin | sed -n 1p` -g tomcat -d /usr/local/tomcat tomcat

cd /usr/local/src
sudo wget https://downloads.apache.org/tomcat/tomcat-9/v9.0.41/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz
sudo tar -zxvf apache-tomcat-$TOMCAT_VERSION.tar.gz
sudo mv apache-tomcat-$TOMCAT_VERSION /usr/local/tomcat



## 4. Permission
cd /usr/local
sudo chmod -R 755 tomcat
sudo chown -R tomcat:tomcat tomcat


## 5. Systemd Unit file

show_message "Make Tomcat service to use systemctl command"



sudo bash -c 'cat >> /etc/systemd/system/tomcat.service' << EOF

[Unit]
Description=Apache Tomcat Web Application Container
After=syslog.target network.target

[Service]
Type=forking
User=tomcat
Group=tomcat
ExecStart=/usr/local/tomcat/bin/startup.sh
ExecStop=/usr/local/tomcat/bin/shutdown.sh
SuccessExitStatus=143
Restart=always
RestartSec=10
UMask=0007

[Install]
WantedBy=multi-user.target

EOF


## 6. Restart Daemon

sudo systemctl daemon-reload 
sudo systemctl restart tomcat
sudo systemctl enable tomcat


show_message "Tomcat Installation completed"
