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
mkdir -p /opt/mlops
cd /opt/mlops

# Create docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  postgres:
    image: postgres:13
    environment:
      POSTGRES_USER: airflow
      POSTGRES_PASSWORD: airflow
      POSTGRES_DB: airflow
    volumes:
      - postgres-db-volume:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD", "pg_isready", "-U", "airflow"]
      interval: 10s
      retries: 5
      start_period: 5s
    restart: always

  redis:
    image: redis:7.2-bookworm
    expose:
      - 6379
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 30s
      retries: 50
      start_period: 30s
    restart: always

  airflow-apiserver:
    build:
      context: .
      dockerfile: airflow.dockerfile
    environment:
      AIRFLOW__CORE__EXECUTOR: CeleryExecutor
      AIRFLOW__CORE__AUTH_MANAGER: airflow.providers.fab.auth_manager.fab_auth_manager.FabAuthManager
      AIRFLOW__DATABASE__SQL_ALCHEMY_CONN: postgresql+psycopg2://airflow:airflow@postgres/airflow
      AIRFLOW__CELERY__RESULT_BACKEND: db+postgresql://airflow:airflow@postgres/airflow
      AIRFLOW__CELERY__BROKER_URL: redis://:@redis:6379/0
      AIRFLOW__CORE__FERNET_KEY: ''
      AIRFLOW__CORE__DAGS_ARE_PAUSED_AT_CREATION: 'true'
      AIRFLOW__CORE__LOAD_EXAMPLES: 'true'
      AIRFLOW__CORE__EXECUTION_API_SERVER_URL: 'http://airflow-apiserver:8080/execution/'
      AIRFLOW__SCHEDULER__ENABLE_HEALTH_CHECK: 'true'
      AWS_DEFAULT_REGION: ${region}
      DATA_STORAGE_BUCKET: ${project_name}-data-storage-${environment}
      KINESIS_STREAM_NAME: taxi-ride-predictions-stream
      MLFLOW_TRACKING_URI: http://mlflow:5000
      MLFLOW_BUCKET_NAME: ${project_name}-mlflow-artifacts-${environment}
      MONITORING_BUCKET_NAME: ${project_name}-monitoring-reports-${environment}
    volumes:
      - ./dags:/opt/airflow/dags
      - ./logs:/opt/airflow/logs
      - ./config:/opt/airflow/config
      - ./plugins:/opt/airflow/plugins
    ports:
      - "8080:8080"
    command: api-server
    healthcheck:
      test: ["CMD", "curl", "--fail", "http://localhost:8080/api/v2/version"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 30s
    restart: always
    depends_on:
      redis:
        condition: service_healthy
      postgres:
        condition: service_healthy
      airflow-init:
        condition: service_completed_successfully

  airflow-scheduler:
    build:
      context: .
      dockerfile: airflow.dockerfile
    environment:
      AIRFLOW__CORE__EXECUTOR: CeleryExecutor
      AIRFLOW__CORE__AUTH_MANAGER: airflow.providers.fab.auth_manager.fab_auth_manager.FabAuthManager
      AIRFLOW__DATABASE__SQL_ALCHEMY_CONN: postgresql+psycopg2://airflow:airflow@postgres/airflow
      AIRFLOW__CELERY__RESULT_BACKEND: db+postgresql://airflow:airflow@postgres/airflow
      AIRFLOW__CELERY__BROKER_URL: redis://:@redis:6379/0
      AIRFLOW__CORE__FERNET_KEY: ''
      AIRFLOW__CORE__DAGS_ARE_PAUSED_AT_CREATION: 'true'
      AIRFLOW__CORE__LOAD_EXAMPLES: 'true'
      AIRFLOW__CORE__EXECUTION_API_SERVER_URL: 'http://airflow-apiserver:8080/execution/'
      AIRFLOW__SCHEDULER__ENABLE_HEALTH_CHECK: 'true'
      AWS_DEFAULT_REGION: ${region}
      DATA_STORAGE_BUCKET: ${project_name}-data-storage-${environment}
      KINESIS_STREAM_NAME: taxi-ride-predictions-stream
      MLFLOW_TRACKING_URI: http://mlflow:5000
      MLFLOW_BUCKET_NAME: ${project_name}-mlflow-artifacts-${environment}
      MONITORING_BUCKET_NAME: ${project_name}-monitoring-reports-${environment}
    volumes:
      - ./dags:/opt/airflow/dags
      - ./logs:/opt/airflow/logs
      - ./config:/opt/airflow/config
      - ./plugins:/opt/airflow/plugins
    command: scheduler
    healthcheck:
      test: ["CMD", "curl", "--fail", "http://localhost:8974/health"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 30s
    restart: always
    depends_on:
      redis:
        condition: service_healthy
      postgres:
        condition: service_healthy
      airflow-init:
        condition: service_completed_successfully

  airflow-worker:
    build:
      context: .
      dockerfile: airflow.dockerfile
    environment:
      AIRFLOW__CORE__EXECUTOR: CeleryExecutor
      AIRFLOW__CORE__AUTH_MANAGER: airflow.providers.fab.auth_manager.fab_auth_manager.FabAuthManager
      AIRFLOW__DATABASE__SQL_ALCHEMY_CONN: postgresql+psycopg2://airflow:airflow@postgres/airflow
      AIRFLOW__CELERY__RESULT_BACKEND: db+postgresql://airflow:airflow@postgres/airflow
      AIRFLOW__CELERY__BROKER_URL: redis://:@redis:6379/0
      AIRFLOW__CORE__FERNET_KEY: ''
      AIRFLOW__CORE__DAGS_ARE_PAUSED_AT_CREATION: 'true'
      AIRFLOW__CORE__LOAD_EXAMPLES: 'true'
      AIRFLOW__CORE__EXECUTION_API_SERVER_URL: 'http://airflow-apiserver:8080/execution/'
      AIRFLOW__SCHEDULER__ENABLE_HEALTH_CHECK: 'true'
      DUMB_INIT_SETSID: "0"
      AWS_DEFAULT_REGION: ${region}
      DATA_STORAGE_BUCKET: ${project_name}-data-storage-${environment}
      KINESIS_STREAM_NAME: taxi-ride-predictions-stream
      MLFLOW_TRACKING_URI: http://mlflow:5000
      MLFLOW_BUCKET_NAME: ${project_name}-mlflow-artifacts-${environment}
      MONITORING_BUCKET_NAME: ${project_name}-monitoring-reports-${environment}
    volumes:
      - ./dags:/opt/airflow/dags
      - ./logs:/opt/airflow/logs
      - ./config:/opt/airflow/config
      - ./plugins:/opt/airflow/plugins
    command: celery worker
    healthcheck:
      test:
        - "CMD-SHELL"
        - 'celery --app airflow.providers.celery.executors.celery_executor.app inspect ping -d "celery@$${HOSTNAME}" || celery --app airflow.executors.celery_executor.app inspect ping -d "celery@$${HOSTNAME}"'
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 30s
    restart: always
    depends_on:
      redis:
        condition: service_healthy
      postgres:
        condition: service_healthy
      airflow-apiserver:
        condition: service_healthy
      airflow-init:
        condition: service_completed_successfully

  airflow-init:
    build:
      context: .
      dockerfile: airflow.dockerfile
    environment:
      AIRFLOW__CORE__EXECUTOR: CeleryExecutor
      AIRFLOW__CORE__AUTH_MANAGER: airflow.providers.fab.auth_manager.fab_auth_manager.FabAuthManager
      AIRFLOW__DATABASE__SQL_ALCHEMY_CONN: postgresql+psycopg2://airflow:airflow@postgres/airflow
      AIRFLOW__CELERY__RESULT_BACKEND: db+postgresql://airflow:airflow@postgres/airflow
      AIRFLOW__CELERY__BROKER_URL: redis://:@redis:6379/0
      AIRFLOW__CORE__FERNET_KEY: ''
      AIRFLOW__CORE__DAGS_ARE_PAUSED_AT_CREATION: 'true'
      AIRFLOW__CORE__LOAD_EXAMPLES: 'true'
      AIRFLOW__CORE__EXECUTION_API_SERVER_URL: 'http://airflow-apiserver:8080/execution/'
      AIRFLOW__SCHEDULER__ENABLE_HEALTH_CHECK: 'true'
      _AIRFLOW_DB_MIGRATE: 'true'
      _AIRFLOW_WWW_USER_CREATE: 'true'
      _AIRFLOW_WWW_USER_USERNAME: airflow
      _AIRFLOW_WWW_USER_PASSWORD: airflow
      AWS_DEFAULT_REGION: ${region}
      DATA_STORAGE_BUCKET: ${project_name}-data-storage-${environment}
      KINESIS_STREAM_NAME: taxi-ride-predictions-stream
      MLFLOW_TRACKING_URI: http://mlflow:5000
      MLFLOW_BUCKET_NAME: ${project_name}-mlflow-artifacts-${environment}
      MONITORING_BUCKET_NAME: ${project_name}-monitoring-reports-${environment}
    volumes:
      - ./dags:/opt/airflow/dags
      - ./logs:/opt/airflow/logs
      - ./config:/opt/airflow/config
      - ./plugins:/opt/airflow/plugins
    entrypoint: /bin/bash
    command:
      - -c
      - |
        mkdir -v -p /opt/airflow/{logs,dags,plugins,config}
        /entrypoint airflow config list >/dev/null
        chown -R "50000:0" /opt/airflow/
        chown -v -R "50000:0" /opt/airflow/{logs,dags,plugins,config}
    user: "0:0"
    depends_on:
      redis:
        condition: service_healthy
      postgres:
        condition: service_healthy

  mlflow:
    build:
      context: .
      dockerfile: mlflow.dockerfile
    ports:
      - "5000:5000"
    environment:
      MLFLOW__BACKEND_STORE_URI: postgresql+psycopg2://airflow:airflow@postgres/mlflow
      MLFLOW__DEFAULT_ARTIFACT_ROOT: s3://${project_name}-mlflow-artifacts-${environment}/artifacts
      AWS_DEFAULT_REGION: ${region}
      MLFLOW_S3_ENDPOINT_URL: https://s3.${region}.amazonaws.com
    command: [
      "mlflow", "server",
      "--backend-store-uri", "postgresql+psycopg2://airflow:airflow@postgres/mlflow",
      "--default-artifact-root", "s3://${project_name}-mlflow-artifacts-${environment}/artifacts",
      "--host", "0.0.0.0",
      "--port", "5000"
    ]
    volumes:
      - ./mlflow_data:/home/mlflow_data/
    restart: always
    depends_on:
      postgres:
        condition: service_healthy

volumes:
  postgres-db-volume:
EOF

# Create Dockerfiles
cat > airflow.dockerfile << 'EOF'
FROM apache/airflow:3.0.3-python3.11

USER root
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

USER airflow
RUN pip install --no-cache-dir \
    boto3 \
    mlflow \
    pandas \
    scikit-learn \
    xgboost \
    evidently
EOF

cat > mlflow.dockerfile << 'EOF'
FROM python:3.11-slim

RUN pip install --no-cache-dir \
    mlflow \
    boto3 \
    psycopg2-binary \
    pandas \
    scikit-learn \
    xgboost

EXPOSE 5000

CMD ["mlflow", "server", "--host", "0.0.0.0", "--port", "5000"]
EOF

# Create directories
mkdir -p dags logs config plugins mlflow_data

# Set permissions
chown -R ec2-user:ec2-user /opt/mlops

# Start services
cd /opt/mlops
docker-compose up -d

# Create systemd service for auto-start
cat > /etc/systemd/system/mlops-docker-compose.service << EOF
[Unit]
Description=MLOps Docker Compose
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/mlops
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

systemctl enable mlops-docker-compose.service

echo "MLOps setup completed successfully!"

# Create a simple status page with service links
cat > /opt/mlops/status.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>MLOps Pipeline Status</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .service { margin: 20px 0; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }
        .service h3 { margin-top: 0; color: #333; }
        .service a { color: #0066cc; text-decoration: none; }
        .service a:hover { text-decoration: underline; }
        .status { font-weight: bold; }
        .running { color: green; }
        .stopped { color: red; }
    </style>
</head>
<body>
    <h1>MLOps Pipeline Status</h1>
    <p>This page shows the status of MLOps orchestration services running on this instance.</p>
    
    <div class="service">
        <h3>Airflow (Workflow Orchestration)</h3>
        <p><span class="status running">● Running</span></p>
        <p><a href="http://localhost:8080" target="_blank">Airflow Web UI</a></p>
        <p>Username: airflow | Password: airflow</p>
    </div>
    
    <div class="service">
        <h3>MLflow (Model Registry)</h3>
        <p><span class="status running">● Running</span></p>
        <p><a href="http://localhost:5000" target="_blank">MLflow UI</a></p>
    </div>
    
    <div class="service">
        <h3>Services Information</h3>
        <p><strong>PostgreSQL:</strong> Running on port 5432</p>
        <p><strong>Redis:</strong> Running on port 6379</p>
        <p><strong>Docker Compose:</strong> Managing all services</p>
    </div>
    
    <div class="service">
        <h3>Quick Commands</h3>
        <p><code>docker-compose ps</code> - View service status</p>
        <p><code>docker-compose logs airflow-apiserver</code> - View Airflow logs</p>
        <p><code>docker-compose logs mlflow</code> - View MLflow logs</p>
    </div>
</body>
</html>
EOF

# Start a simple HTTP server to serve the status page
nohup python3 -m http.server 8081 --directory /opt/mlops > /dev/null 2>&1 & 