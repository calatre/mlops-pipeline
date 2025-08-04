# MLOps Pipeline Scripts

Collection of utility scripts for data setup, testing, deployment, and simulation within the MLOps pipeline.

## 🛠️ Build & Deployment Scripts

### build-images.sh
Builds Docker images for the MLOps pipeline components and pushes them to AWS ECR.

**Usage:**
```bash
./build-images.sh
```

**Features:**
- Builds Airflow and MLflow custom images
- Tags images with timestamps and git commits
- Pushes to AWS ECR repositories
- Handles multi-platform builds (linux/amd64)

### build_lambda.sh
Packages the Lambda function as a Docker container and deploys it to AWS ECR for Lambda container deployment.

**Usage:**
```bash
./build_lambda.sh
```

**Features:**
- Builds Lambda function Docker container
- Optimized for AWS Lambda runtime
- Pushes to ECR with proper tagging
- Supports 10GB package size limit

## 📊 Data Management Scripts

### data_setup.py
Downloads, processes, and uploads NYC taxi dataset to S3 for ML pipeline use.

**Usage:**
```bash
python data_setup.py
```

**Features:**
- Downloads NYC taxi data from official source
- Applies data cleaning and filtering (1-60 minute duration)
- Converts categorical columns to strings
- Uploads processed data to S3 in Parquet format
- Uses current date minus 2 years for reproducible datasets

**Environment Variables:**
- `DATA_STORAGE_BUCKET`: S3 bucket for data storage (default: mlops-taxi-prediction-data-storage-dev)

## 🧪 Testing & Simulation Scripts

### event_simulation.py
Simulates streaming taxi ride events to Kinesis for testing the real-time pipeline.

**Usage:**
```bash
# Basic simulation
python event_simulation.py

# Custom parameters
python event_simulation.py --interval 2.0 --max-events 100 --stream my-stream
```

**Parameters:**
- `--interval`: Time between events in seconds (default: 1.0)
- `--max-events`: Maximum number of events to send (default: unlimited)
- `--bucket`: S3 bucket name for data source
- `--stream`: Kinesis stream name

**Features:**
- Loads real taxi data from S3
- Creates realistic ride events with timestamps
- Sends events to Kinesis stream with configurable intervals
- Supports keyboard interrupt for graceful stopping

### test_consumer.py
Performs comprehensive end-to-end testing of the entire prediction pipeline.

**Usage:**
```bash
# Full end-to-end test
python test_consumer.py

# List recent predictions
python test_consumer.py --list-recent

# Custom wait time and region
python test_consumer.py --wait 120 --region eu-north-1
```

**Parameters:**
- `--stream`: Kinesis stream name
- `--bucket`: S3 bucket for predictions
- `--wait`: Max seconds to wait for prediction result (default: 60)
- `--list-recent`: List recent predictions instead of running test
- `--region`: AWS region (default: us-east-1)

**Test Flow:**
1. Creates a synthetic test ride
2. Sends ride to Kinesis stream
3. Waits for Lambda to process and predict
4. Checks S3 for prediction results
5. Reports success/failure with detailed diagnostics

## 🏗️ Data Structures

### ride.py
Defines the `Ride` data class and utilities for taxi trip data handling.

**Usage:**
```python
from ride import Ride, create_sample_ride

# Create a sample ride
ride = create_sample_ride()

# Convert to JSON
json_data = ride.to_json()

# Create from JSON
ride_from_json = Ride.from_json(json_data)
```

**Features:**
- `Ride` dataclass with proper typing
- JSON serialization/deserialization
- Sample ride generation for testing
- Validation for NYC taxi zone IDs (1-265)

## 🔧 Environment Setup

Most scripts use environment variables for configuration:

```bash
# AWS Configuration
export AWS_DEFAULT_REGION=eu-north-1
export DATA_STORAGE_BUCKET=mlops-taxi-prediction-data-storage-dev
export KINESIS_STREAM_NAME=taxi-ride-predictions-stream
export LAMBDA_FUNCTION_NAME=taxi-trip-duration-predictor
```

## 📋 Prerequisites

- Python 3.11+
- AWS CLI configured with appropriate permissions
- Docker (for build scripts)
- Required Python packages:
  - boto3
  - pandas
  - argparse

## 🎯 Common Workflows

### Initial Data Setup
```bash
# 1. Download and prepare data
python data_setup.py

# 2. Test the pipeline
python test_consumer.py
```

### Development Testing
```bash
# 1. Build and deploy Lambda
./build_lambda.sh

# 2. Simulate events
python event_simulation.py --max-events 10 --interval 2

# 3. Verify predictions
python test_consumer.py --list-recent
```

### Pipeline Validation
```bash
# Full end-to-end test
python test_consumer.py --wait 120
```

These scripts provide a complete toolkit for managing, testing, and validating the MLOps pipeline.
