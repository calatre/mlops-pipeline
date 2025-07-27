# Based on mlops-zoomcamp-andre Airflow Dockerfile
FROM apache/airflow:3.0.3-python3.11

USER root

# Install system dependencies
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
         vim \
         curl \
  && apt-get autoremove -yqq --purge \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

USER airflow

# Copy requirements file
COPY requirements.txt /requirements.txt

# Install Python dependencies
RUN pip install --no-cache-dir -r /requirements.txt

# Set environment variables for Airflow
ENV AIRFLOW_HOME=/opt/airflow

# Create necessary directories
RUN mkdir -p /opt/airflow/dags /opt/airflow/logs /opt/airflow/plugins

# Copy DAGs and other files
COPY dags/ /opt/airflow/dags/
