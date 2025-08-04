# MLOps Pipeline Orchestration

This directory manages the orchestration components of the MLOps pipeline, primarily Apache Airflow and MLflow services running in Docker containers.

## 🏗️ Architecture Overview

The orchestration layer consists of multiple containerized services managed by Docker Compose:

- **Apache Airflow 3.0.1**: Workflow orchestration and task scheduling
- **MLflow**: ML experiment tracking and model registry  
- **PostgreSQL**: Database backend for Airflow and MLflow metadata
- **Redis**: Message broker for Airflow's Celery executor

## 📁 Directory Structure

```
orchestration/
├── README.md                    # This file
├── docker-compose.yaml          # Main orchestration configuration
├── mlops-docker-compose.service # Systemd service file
├── status.html                  # Service status monitoring page
├── config/                      # Configuration files
├── dags/                        # Airflow DAGs directory
├── mlflow_data/                 # MLflow data storage
└── install/                     # Installation and setup files
    ├── readme.md               # Install directory documentation
    ├── 1st_run_install.sh      # First-time setup script
    ├── airflow.dockerfile      # Custom Airflow image
    ├── mlflow.dockerfile       # Custom MLflow image
    └── requirements.txt        # Python dependencies
```

## 🚀 Quick Start

### Prerequisites
- Docker and Docker Compose installed
- AWS credentials configured (for S3 integration)
- Sufficient system resources (recommended: 8~12GB+ RAM)

### Initial Setup

1. **First-time installation** (run once):
   ```bash
   cd orchestration/install
   ./1st_run_install.sh
   ```

2. **Start all services**:
   ```bash
   cd orchestration
   docker-compose up -d
   ```

3. **Verify services are healthy**:
   ```bash
   docker-compose ps
   ```

### Access URLs

Once services are running, access them via:
- **Airflow Web UI**: `http://localhost:8080` (admin/admin)
- **MLflow UI**: `http://localhost:5000`
- **Service Status**: `http://localhost:8081` (custom status page)

## 🔧 Services Configuration

### Airflow Services
- **airflow-apiserver**: Web UI and API server (port 8080)
- **airflow-scheduler**: Task scheduling and orchestration
- **airflow-dag-processor**: DAG file processing
- **airflow-worker**: Celery worker for task execution
- **airflow-triggerer**: Handles deferred/async tasks

### Supporting Services
- **postgres**: Database for metadata storage
- **redis**: Message broker for Celery executor
- **mlflow**: ML experiment tracking server (port 5000)

### Environment Variables

Key configuration via environment variables:
- `AIRFLOW_UID`: User ID for Airflow containers (default: 50000)
- `_AIRFLOW_WWW_USER_USERNAME`: Admin username (default: airflow)
- `_AIRFLOW_WWW_USER_PASSWORD`: Admin password (default: airflow)
- `AIRFLOW_PROJ_DIR`: Base directory for volumes (default: .)

## 📊 ML Pipeline Integration

### MLflow Configuration
- **Artifact Storage**: S3 bucket for model artifacts
- **Backend Store**: PostgreSQL for experiment metadata
- **Tracking URI**: `http://localhost:5000` for local development

### Airflow DAGs
Place your DAG files in the `dags/` directory. They will be automatically discovered and loaded by Airflow.

Common DAG patterns:
- **Training Pipeline**: Data ingestion → Feature engineering → Model training → Model validation
- **Monitoring Pipeline**: Data drift detection → Model performance monitoring → Alerting

## 🔍 Monitoring and Troubleshooting

### Health Checks
All services include comprehensive health checks:
```bash
# Check service status
docker-compose ps

# View service logs
docker-compose logs [service-name]

# Check specific service health
curl http://localhost:8080/health  # Airflow
curl http://localhost:5000         # MLflow
```

### Common Issues
1. **Services won't start**: Check Docker daemon and system resources
2. **Database connection errors**: Ensure PostgreSQL is healthy before starting Airflow
3. **Permission issues**: Verify `AIRFLOW_UID` matches your system user
4. **DAG import errors**: Check DAG syntax and dependencies

### Log Locations
- **Airflow logs**: `./logs/` directory
- **Container logs**: `docker-compose logs [service]`
- **MLflow logs**: Check MLflow UI or container logs

## 🛠️ Development

### Custom Images
The setup uses custom Docker images built from:
- `install/airflow.dockerfile`: Extended Airflow image with additional dependencies
- `install/mlflow.dockerfile`: Custom MLflow image for the project

### Adding Dependencies
Update `install/requirements.txt` and rebuild images:
```bash
docker-compose build
docker-compose up -d
```

### DAG Development
1. Place DAG files in `dags/` directory
2. Airflow automatically detects and loads new DAGs
3. Use the Airflow UI to test and monitor DAG execution

## 🔐 Security Notes

⚠️ **Important**: This configuration is optimized for local development and learning. For production use:
- Change default passwords
- Enable authentication and authorization
- Use secrets management
- Configure HTTPS/TLS
- Implement proper network security

## 📝 Service Management

### Systemd Service (Linux)
A systemd service file is provided for automatic startup:
```bash
# Install the service
sudo cp mlops-docker-compose.service /etc/systemd/system/
sudo systemctl enable mlops-docker-compose.service

# Control the service
sudo systemctl start mlops-docker-compose
sudo systemctl stop mlops-docker-compose
sudo systemctl status mlops-docker-compose
```

### Manual Control
```bash
# Start services
docker-compose up -d

# Stop services
docker-compose down

# Restart specific service
docker-compose restart [service-name]

# View logs
docker-compose logs -f [service-name]
```
