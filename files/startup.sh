#!/bin/bash


echo "deb https://download.gocd.org /" | sudo tee /etc/apt/sources.list.d/gocd.list
curl https://download.gocd.org/GOCD-GPG-KEY.asc | sudo apt-key add -
sudo apt-get update -y

# Install GOCD Server
sudo apt-get install go-server

# Start GOCD Server
service go-server start

# Install GOCD Agent
sudo apt-get install go-agent

# Start GOCD Agent
service go-agent start