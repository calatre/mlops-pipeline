# MLOps Pipeline Frontend Dashboard

A simple, clean web interface for the MLOps taxi trip duration prediction pipeline.

This is intended to be a simple entry point for the full pipeline demo.

This ends up inside a docker container.

## 📃 Features

- **Pipeline Health Status**: Real-time monitoring of Airflow, MLflow, Kinesis, and Lambda services
- **Quick Links**: Direct access to Airflow UI and MLflow UI
- **Test Event Submission**: 
  - Generate synthetic taxi trip events
  - Load real trip data from S3
- **Pipeline Output Monitoring**: View real-time Kinesis stream results
- **Activity Logging**: Track all dashboard activities

## 🛠️ Technology Stack

- **Backend**: Flask 3.0 (Python)
- **Frontend**: Bootstrap 5.3, Vanilla JavaScript
- **AWS Integration**: Boto3 for Kinesis and S3
- **Styling**: Simple, pedagogical design with Bootstrap

## 🚀 Setup

1. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

2. Configure environment variables in `.env` file

3. Run the application:
   ```bash
   ./run.sh
   # or
   python app.py
   ```

4. Access at http://localhost:5000

## 🔧 Configuration

The application uses environment variables for configuration:

- `AWS_DEFAULT_REGION`: AWS region (default: eu-north-1)
- `KINESIS_STREAM_NAME`: Kinesis stream name
- `DATA_STORAGE_BUCKET`: S3 bucket for data storage
- `LAMBDA_FUNCTION_NAME`: Lambda function name

## 🌐 API Endpoints

- `GET /`: Main dashboard
- `GET /api/health`: Application health check
- `GET /api/health/kinesis`: Kinesis stream health
- `GET /api/health/lambda`: Lambda function health
- `POST /api/events`: Submit event to Kinesis
- `GET /api/kinesis/records`: Get recent stream records