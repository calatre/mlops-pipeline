#!/bin/bash

# User data script for MLOps EC2 instance
# This script installs Docker, Docker Compose, and sets up the MLOps environment

set -e

# Update system
yum update -y

# Install Docker
yum install -y docker
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install additional tools
yum install -y git python3-pip

# Create MLOps directory 
#EDIT: this had to go on provisioner remote-exec
#sudo mkdir -p /opt/mlops
#sudo chown -R ec2-user:ec2-user /opt/mlops
#cd /opt/mlops

#On Linux, the quick-start needs to know your host user id and needs to have group id set to 0. 
#Otherwise the files created in dags, logs, config and plugins will be created with root user ownership. 
#You have to make sure to configure them for the docker-compose:
#mkdir -p ./dags ./logs ./plugins ./config
#echo -e "AIRFLOW_UID=$(id -u)" > .env


# Upload docker-compose.yml and app files next
