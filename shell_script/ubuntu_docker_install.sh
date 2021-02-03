#!/bin/bash
# This is for installing Docker engine on Ubuntu!!
# If you are not root user, run "sudo ./install_docker.sh"

echo "Install Docker Engine on Ubuntu"

# Uninstall old version
echo "#################################################################"
echo "################# Uninstall old docker version ##################"
echo "#################################################################"

for package in docker-engine docker.io containerd runc
do
	apt-get -y remove $package
done

# Set up the repository
echo "#################################################################"
echo "################# prerequisite for the repo #####################"
echo "#################################################################"

sudo apt-get update
sleep 5
for package in apt-transport-https ca-certificates curl gnupg-agent software-properties-common
do
	apt-get -y install $package
done

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -

echo "#################################################################"
echo "################ Set up the stable repository ###################"
echo "#################################################################"
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

# Install docker engine
echo "#################################################################"
echo "##################### Install Docker engine #####################"
echo "#################################################################"

apt-get update
apt-get -y install docker-ce docker-ce-cli containerd.io

# check
echo "#################################################################"
echo "############### Check Docker is installed well ##################"
echo "#################################################################"
docker run hello-world
sleep 2
echo "End installing docker"

