from datetime import datetime, timedelta
from airflow import DAG
from airflow.providers.amazon.aws.operators.s3 import S3CreateBucketOperator
from airflow.providers.amazon.aws.sensors.s3 import S3KeySensor
from airflow.providers.amazon.aws.operators.lambda_function import LambdaInvokeFunctionOperator
from airflow.operators.python import PythonOperator, BranchPythonOperator
from airflow.operators.bash import BashOperator
import boto3
import pandas as pd
import pickle
import numpy as np
from sklearn.feature_extraction import DictVectorizer
from sklearn.metrics import mean_squared_error
import xgboost as xgb
import mlflow
import mlflow.pyfunc
import mlflow.xgboost
from mlflow.tracking import MlflowClient
import os
import math

default_args = {
    'owner': 'mlops-team',
    'depends_on_past': False,
    'start_date': datetime(2023, 7, 1),  # Start from July 2023 (data date)
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

dag = DAG(
    'taxi_model_training',
    default_args=default_args,
    description='Train taxi ride duration prediction model',
    schedule_interval='@weekly',  # Train weekly based on data date
    catchup=True,  # Enable catchup to process past dates for testing
    tags=['mlops', 'training', 'taxi'],
)

def get_data_date_from_context(**context):
    """Get the data date from Airflow execution context"""
    # Use Airflow's execution date (data date) instead of current time
    execution_date = context['execution_date']
    
    # Calculate data file date (execution date minus 2 years for reproducibility)
    data_date = execution_date - timedelta(days=730)  # Approximately 2 years
    year = data_date.year
    month = data_date.month
    
    print(f"Execution date: {execution_date.strftime('%Y-%m-%d')}")
    print(f"Data file date: {year}-{month:02d}")
    
    return year, month

def download_and_prepare_data(**context):
    """Download taxi data from S3 and prepare for training"""
    s3_client = boto3.client('s3')
    
    # Get data date from execution context
    year, month = get_data_date_from_context(**context)
    
    bucket = os.environ.get('DATA_STORAGE_BUCKET', 'mlops-taxi-prediction-data-storage-dev')
    key = f'raw-data/yellow_tripdata_{year}-{month:02d}.parquet'
    
    # Check if data exists
    try:
        s3_client.head_object(Bucket=bucket, Key=key)
        print(f"Data file exists: s3://{bucket}/{key}")
    except:
        print(f"Data file not found: s3://{bucket}/{key}")
        raise FileNotFoundError(f"Training data not available for {year}-{month:02d}")
    
    # Download data
    temp_file = '/tmp/training_data.parquet'
    print(f"Downloading training data from s3://{bucket}/{key}")
    s3_client.download_file(bucket, key, temp_file)
    
    # Load and prepare data
    df = pd.read_parquet(temp_file)
    
    # Clean up temp file
    os.remove(temp_file)
    
    print(f"Loaded {len(df)} records for training from {year}-{month:02d}")
    return f"Training data prepared: {len(df)} records from {year}-{month:02d}"

def preprocess_data(**context):
    """Preprocess data like in mlops-zoomcamp-andre"""
    s3_client = boto3.client('s3')
    
    # Get data date from execution context
    year, month = get_data_date_from_context(**context)
    
    bucket = os.environ.get('DATA_STORAGE_BUCKET', 'mlops-taxi-prediction-data-storage-dev')
    key = f'raw-data/yellow_tripdata_{year}-{month:02d}.parquet'
    
    # Download and load data
    temp_file = '/tmp/training_data.parquet'
    s3_client.download_file(bucket, key, temp_file)
    df = pd.read_parquet(temp_file)
    
    # Same preprocessing as reference project
    df['duration'] = df['tpep_dropoff_datetime'] - df['tpep_pickup_datetime']
    df.duration = df.duration.apply(lambda td: td.total_seconds() / 60)
    
    # Filter outliers
    df = df[(df.duration >= 1) & (df.duration <= 60)]
    
    # Convert categorical columns
    categorical = ['PULocationID', 'DOLocationID']
    df[categorical] = df[categorical].astype(str)
    
    # Prepare features
    features = ['PULocationID', 'DOLocationID', 'trip_distance']
    target = 'duration'
    
    # Split data (80% train, 20% validation)
    split_index = int(0.8 * len(df))
    df_train = df[:split_index]
    df_val = df[split_index:]
    
    # Prepare dictionaries for vectorization
    train_dicts = df_train[features].to_dict(orient='records')
    val_dicts = df_val[features].to_dict(orient='records')
    
    # Store preprocessed data
    preprocessed_data = {
        'train_dicts': train_dicts,
        'val_dicts': val_dicts,
        'y_train': df_train[target].values,
        'y_val': df_val[target].values,
        'data_date': f'{year}-{month:02d}'
    }
    
    # Save to temporary file
    with open('/tmp/preprocessed_data.pkl', 'wb') as f:
        pickle.dump(preprocessed_data, f)
    
    # Upload to S3 with data date in path
    model_key = f'models/{year}-{month:02d}/preprocessed_data.pkl'
    s3_client.upload_file('/tmp/preprocessed_data.pkl', bucket, model_key)
    
    os.remove(temp_file)
    os.remove('/tmp/preprocessed_data.pkl')
    
    print(f"Preprocessed data for {year}-{month:02d}: {len(train_dicts)} training, {len(val_dicts)} validation samples")
    return f"Data preprocessing completed for {year}-{month:02d}"

class TaxiDurationModel(mlflow.pyfunc.PythonModel):
    """MLflow pyfunc model wrapper that includes DictVectorizer and XGBoost model"""
    
    def __init__(self, model, dict_vectorizer):
        self.model = model
        self.dict_vectorizer = dict_vectorizer
    
    def predict(self, context, model_input):
        # Transform input using DictVectorizer
        if isinstance(model_input, pd.DataFrame):
            # Convert DataFrame to list of dicts
            dicts = model_input.to_dict(orient='records')
        else:
            dicts = model_input
        
        X = self.dict_vectorizer.transform(dicts)
        predictions = self.model.predict(X)
        return predictions

def train_model(**context):
    """Train XGBoost model using MLflow tracking with pyfunc wrapper"""
    s3_client = boto3.client('s3')
    bucket = os.environ.get('DATA_STORAGE_BUCKET', 'mlops-taxi-prediction-data-storage-dev')
    
    # Get data date from execution context
    year, month = get_data_date_from_context(**context)
    
    # Download preprocessed data
    model_key = f'models/{year}-{month:02d}/preprocessed_data.pkl'
    s3_client.download_file(bucket, model_key, '/tmp/preprocessed_data.pkl')
    
    with open('/tmp/preprocessed_data.pkl', 'rb') as f:
        data = pickle.load(f)
    
    train_dicts = data['train_dicts']
    val_dicts = data['val_dicts']
    y_train = data['y_train']
    y_val = data['y_val']
    data_date = data['data_date']
    
    # Initialize MLflow (can be configured to use S3 as backend)
    mlflow.set_experiment("taxi-duration-prediction")
    
    with mlflow.start_run():
        # Vectorize features
        dv = DictVectorizer()
        X_train = dv.fit_transform(train_dicts)
        X_val = dv.transform(val_dicts)
        
        # XGBoost hyperparameters
        xgb_params = {
            'max_depth': 6,
            'learning_rate': 0.1,
            'n_estimators': 100,
            'min_child_weight': 1,
            'objective': 'reg:squarederror',
            'random_state': 42
        }
        
        # Train XGBoost model
        model = xgb.XGBRegressor(**xgb_params)
        model.fit(X_train, y_train)
        
        # Make predictions
        y_pred = model.predict(X_val)
        
        # Calculate metrics
        rmse = mean_squared_error(y_val, y_pred, squared=False)
        
        # Log parameters
        mlflow.log_params(xgb_params)
        mlflow.log_param("train_samples", len(train_dicts))
        mlflow.log_param("val_samples", len(val_dicts))
        mlflow.log_param("data_date", data_date)
        mlflow.log_param("execution_date", context['execution_date'].strftime('%Y-%m-%d'))
        
        # Log metrics
        mlflow.log_metric("rmse", rmse)
        
        # Create pyfunc model wrapper
        taxi_model = TaxiDurationModel(model, dv)
        
        # Log the pyfunc model (includes both model and vectorizer)
        mlflow.pyfunc.log_model(
            artifact_path="model",
            python_model=taxi_model,
            registered_model_name="taxi-duration-model"
        )
        
        # Also save individual components for backward compatibility
        with open('/tmp/model.pkl', 'wb') as f:
            pickle.dump(model, f)
        
        with open('/tmp/dv.pkl', 'wb') as f:
            pickle.dump(dv, f)
        
        # Create combined model artifact for Lambda
        combined_model = {
            'model': model,
            'vectorizer': dv
        }
        
        with open('/tmp/combined_model.pkl', 'wb') as f:
            pickle.dump(combined_model, f)
        
        # Upload to S3 with data date path
        model_path = f'models/{year}-{month:02d}/model.pkl'
        dv_path = f'models/{year}-{month:02d}/dv.pkl'
        combined_path = f'models/{year}-{month:02d}/combined_model.pkl'
        
        s3_client.upload_file('/tmp/model.pkl', bucket, model_path)
        s3_client.upload_file('/tmp/dv.pkl', bucket, dv_path)
        s3_client.upload_file('/tmp/combined_model.pkl', bucket, combined_path)
        
        # Also save as latest model for Lambda to use
        s3_client.upload_file('/tmp/combined_model.pkl', bucket, 'models/latest/combined_model.pkl')
        
        # Clean up
        os.remove('/tmp/preprocessed_data.pkl')
        os.remove('/tmp/model.pkl')
        os.remove('/tmp/dv.pkl')
        os.remove('/tmp/combined_model.pkl')
        
        print(f"XGBoost model trained successfully for {data_date}. RMSE: {rmse:.4f}")
        return f"XGBoost model training completed for {data_date}. RMSE: {rmse:.4f}"

def update_lambda_function(**context):
    """Trigger Lambda function update to use new model"""
    lambda_client = boto3.client('lambda')
    
    # Get data date from execution context
    year, month = get_data_date_from_context(**context)
    execution_date = context['execution_date']
    
    function_name = os.environ.get('LAMBDA_FUNCTION_NAME', 'taxi-ride-duration-prediction')
    
    # Update environment variable to trigger model reload
    model_updated_time = execution_date.isoformat()
    
    try:
        response = lambda_client.update_function_configuration(
            FunctionName=function_name,
            Environment={
                'Variables': {
                    'MODEL_UPDATED_AT': model_updated_time,
                    'MODEL_DATA_DATE': f'{year}-{month:02d}',
                    'DATA_STORAGE_BUCKET': os.environ.get('DATA_STORAGE_BUCKET', 'mlops-taxi-prediction-data-storage-dev')
                }
            }
        )
        print(f"Lambda function updated successfully with model from {year}-{month:02d}")
        return f"Lambda function updated with model from {year}-{month:02d}"
    except Exception as e:
        print(f"Error updating Lambda function: {e}")
        raise

# Define tasks
download_data_task = PythonOperator(
    task_id='download_data',
    python_callable=download_and_prepare_data,
    dag=dag,
)

preprocess_data_task = PythonOperator(
    task_id='preprocess_data',
    python_callable=preprocess_data,
    dag=dag,
)

train_model_task = PythonOperator(
    task_id='train_model',
    python_callable=train_model,
    dag=dag,
)

update_lambda_task = PythonOperator(
    task_id='update_lambda',
    python_callable=update_lambda_function,
    dag=dag,
)

# Set task dependencies
download_data_task >> preprocess_data_task >> train_model_task >> update_lambda_task
