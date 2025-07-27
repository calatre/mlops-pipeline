FROM python:3.11-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create mlflow user and directory
RUN useradd -m -s /bin/bash mlflow
USER mlflow
WORKDIR /home/mlflow

# Install MLflow and dependencies
COPY --chown=mlflow:mlflow requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt

# Add user pip install directory to PATH
ENV PATH="/home/mlflow/.local/bin:${PATH}"

# Create directory for MLflow data
RUN mkdir -p /home/mlflow/mlflow_data

# Expose MLflow UI port
EXPOSE 5000

# Start MLflow server
# Using SQLite for metadata store and S3 for artifact store
# AWS credentials should be provided at runtime via ECS task role or environment variables
CMD ["mlflow", "server", \
    "--backend-store-uri", "sqlite:///home/mlflow/mlflow_data/mlflow.db", \
    "--default-artifact-root", "s3://mlops-taxi-prediction-mlflow-artifacts-dev/", \
    "--host", "0.0.0.0", \
    "--port", "5000", \
    "--serve-artifacts"]
