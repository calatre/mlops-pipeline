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

# Docker readiness check function
wait_for_docker() {
    local max_attempts=30
    local attempt=0
    local delay=2
    local timeout=60
    
    log_message() {
        echo "$(date +'%Y-%m-%d %H:%M:%S') - $1"
    }
    
    log_message "Starting Docker readiness check..."
    
    while ! docker info > /dev/null 2>&1; do
        attempt=$((attempt + 1))
        if [ $attempt -ge $max_attempts ]; then
            log_message "ERROR: Docker daemon failed to start after $max_attempts attempts"
            exit 1
        fi
        log_message "Waiting for Docker daemon... (attempt $attempt/$max_attempts)"
        sleep $delay
        
        # Exponential backoff with cap
        delay=$((delay * 2))
        if [ $delay -gt $timeout ]; then
            delay=$timeout
        fi
    done
    
    log_message "Docker daemon is ready!"
}

# Wait for Docker to be fully ready
wait_for_docker

# Create MLOps directory 
#EDIT: this had to go on provisioner remote-exec
#sudo mkdir -p /opt/mlops
#sudo chown -R ec2-user:ec2-user /opt/mlops
#cd /opt/mlops

# Upload files next
