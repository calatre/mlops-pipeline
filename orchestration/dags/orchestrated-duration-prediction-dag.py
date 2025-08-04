#!/usr/bin/env python
# coding: utf-8

"""
This script defines an Airflow DAG for orchestrating the training of a simple machine learning model to predict NYC taxi trip durations.
It includes tasks for setting up the environment, loading and preparing data, feature engineering, training the model with XGBoost, and validating the model performance using MLflow for experiment tracking.

Used Claude Sonnet 4 for first draft and cleaned and corrected until having a PoC 
"""

from datetime import datetime, timedelta
from dateutil.relativedelta import relativedelta #to calculate relative dates
import pickle
from pathlib import Path

import pandas as pd
import xgboost as xgb
from sklearn.feature_extraction import DictVectorizer
from sklearn.metrics import root_mean_squared_error
import mlflow
import boto3
import io

from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.operators.bash import BashOperator
from airflow.models import Variable


# Default arguments for the DAG
default_args = {
    'owner': 'andre',
    'depends_on_past': False,
    'start_date': datetime(2023, 1, 1),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

# Create the DAG
dag = DAG(
    'nyc_taxi_duration_prediction',
    default_args=default_args,
    description='Train ML model to predict NYC taxi trip duration',
    schedule='@monthly',  # Run monthly
    catchup=False,
    max_active_runs=1,
    tags=['ml', 'xgboost', 'mlflow', 'taxi'],
)

#Trying to make these variables global
mlflow.set_tracking_uri("http://mlops-mlflow-1:5000") #docker container here
mlflow.set_experiment("nyc-taxi-experiment")
# Model storage now uses S3 bucket instead of local directory
s3_models_bucket = 'mlops-taxi-prediction-mlflow-artifacts-dev'
s3_data_bucket = 'mlops-taxi-prediction-data-storage-dev'  # Data storage bucket
models_folder = Path('/tmp/models')  # Temporary local folder for processing
models_folder.mkdir(exist_ok=True)

#Maybe not needed, but keeping for clarity
def setup_environment(**context): 
    """Setup MLflow and create necessary directories"""
    #mlflow.set_tracking_uri("http://localhost:5000") #default non containerized 
    mlflow.set_tracking_uri("http://mlops-mlflow-1:5000") #the docker container here
    mlflow.set_experiment("nyc-taxi-experiment")
    
    # Model storage now uses S3 bucket instead of local directory
    s3_models_bucket = 'mlops-taxi-prediction-mlflow-artifacts-dev'
    models_folder = Path('/tmp/models')  # Temporary local folder for processing
    models_folder.mkdir(exist_ok=True)
    
    print(f"Environment setup completed. Using S3 bucket: {s3_models_bucket}")


def check_s3_dataset_exists(year, month, bucket_name=None):
    """Check if dataset exists in S3 bucket"""
    if bucket_name is None:
        bucket_name = s3_data_bucket
    
    s3_key = f'raw-data/yellow_tripdata_{year}-{month:02d}.parquet'
    
    try:
        s3_client = boto3.client('s3')
        s3_client.head_object(Bucket=bucket_name, Key=s3_key)
        print(f"Dataset found in S3: s3://{bucket_name}/{s3_key}")
        return True, s3_key
    except s3_client.exceptions.NoSuchKey:
        print(f"Dataset not found in S3: s3://{bucket_name}/{s3_key}")
        return False, s3_key
    except Exception as e:
        print(f"Error checking S3 dataset: {e}")
        return False, s3_key


def read_dataframe_from_s3(year, month, bucket_name=None):
    """Read and preprocess taxi data from S3"""
    if bucket_name is None:
        bucket_name = s3_data_bucket
    
    s3_key = f'raw-data/yellow_tripdata_{year}-{month:02d}.parquet'
    
    try:
        s3_client = boto3.client('s3')
        response = s3_client.get_object(Bucket=bucket_name, Key=s3_key)
        df = pd.read_parquet(io.BytesIO(response['Body'].read()))
        print(f"Successfully loaded data from S3: s3://{bucket_name}/{s3_key}")
        return df
    except Exception as e:
        print(f"Error reading from S3: {e}")
        raise


def read_dataframe(year, month, prefer_s3=True):
    """Read and preprocess taxi data - checks S3 first if prefer_s3=True"""
    original_shape = None
    
    # Check S3 first if preference is set
    if prefer_s3:
        exists, s3_key = check_s3_dataset_exists(year, month)
        if exists:
            try:
                df = read_dataframe_from_s3(year, month)
                original_shape = df.shape
                print(f"Using S3 data. Original shape: {df.shape}")
            except Exception as e:
                print(f"Failed to read from S3, falling back to URL download: {e}")
                # Fall through to URL download
            else:
                # S3 read successful, skip URL download
                pass
    
    # Download from URL if S3 not preferred or S3 read failed
    if original_shape is None:
        url = f'https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_{year}-{month:02d}.parquet'
        print(f"Downloading from URL: {url}")
        df = pd.read_parquet(url)
        original_shape = df.shape
        print(f"Downloaded from URL. Original shape: {df.shape}")
        
        # Optionally upload to S3 for future use
        try:
            upload_dataframe_to_s3(df, year, month)
        except Exception as e:
            print(f"Warning: Failed to upload to S3: {e}")

    # Data preprocessing
    df['duration'] = df.tpep_dropoff_datetime - df.tpep_pickup_datetime
    df.duration = df.duration.apply(lambda td: td.total_seconds() / 60)

    df = df[(df.duration >= 1) & (df.duration <= 60)]

    categorical = ['PULocationID', 'DOLocationID']
    df[categorical] = df[categorical].astype(str)

    df['PU_DO'] = df['PULocationID'] + '_' + df['DOLocationID']

    return df, original_shape


def upload_dataframe_to_s3(df, year, month, bucket_name=None):
    """Upload dataframe to S3 for future use"""
    if bucket_name is None:
        bucket_name = s3_data_bucket
    
    s3_key = f'raw-data/yellow_tripdata_{year}-{month:02d}.parquet'
    
    try:
        s3_client = boto3.client('s3')
        
        # Convert dataframe to parquet bytes
        parquet_buffer = io.BytesIO()
        df.to_parquet(parquet_buffer, index=False)
        parquet_buffer.seek(0)
        
        # Upload to S3
        s3_client.put_object(
            Bucket=bucket_name,
            Key=s3_key,
            Body=parquet_buffer.getvalue(),
            ContentType='application/octet-stream'
        )
        
        print(f"Successfully uploaded dataset to S3: s3://{bucket_name}/{s3_key}")
    except Exception as e:
        print(f"Error uploading to S3: {e}")
        raise


def get_training_dates(**context):
    """Calculate training and validation dates based on current execution date"""
    #logical_date = context.get('logical_date')#, datetime.now())
    logical_date = context['logical_date']
    
    # Training data: 4 months ago, because 2 months ago isn't available yet
    train_date = logical_date - relativedelta(months=4)
    train_year = train_date.year
    train_month = train_date.month
    
    # Validation data: 3 months ago  
    val_date = logical_date - relativedelta(months=3)
    val_year = val_date.year
    val_month = val_date.month
    
    print(f"Execution date: {logical_date.strftime('%Y-%m')}")
    print(f"Training data: {train_year}-{train_month:02d}")
    print(f"Validation data: {val_year}-{val_month:02d}")
    
    return {
        'train_year': train_year,
        'train_month': train_month,
        'val_year': val_year,
        'val_month': val_month
    }


def check_datasets_availability(**context):
    """Check if required datasets are available in S3"""
    task_instance = context['task_instance']
    dates = task_instance.xcom_pull(task_ids='calculate_dates')
    
    if not dates:
        print("Warning: No dates found from calculate_dates task")
        return {'status': 'no_dates'}
    
    train_year = dates['train_year']
    train_month = dates['train_month']
    val_year = dates['val_year']
    val_month = dates['val_month']
    
    print(f"Checking dataset availability for training: {train_year}-{train_month:02d}")
    print(f"Checking dataset availability for validation: {val_year}-{val_month:02d}")
    
    # Check if both datasets exist in S3
    train_exists, train_key = check_s3_dataset_exists(train_year, train_month)
    val_exists, val_key = check_s3_dataset_exists(val_year, val_month)
    
    availability_status = {
        'train_in_s3': train_exists,
        'train_key': train_key,
        'val_in_s3': val_exists,
        'val_key': val_key,
        'both_available': train_exists and val_exists
    }
    
    if availability_status['both_available']:
        print("✅ Both training and validation datasets found in S3")
    else:
        missing = []
        if not train_exists:
            missing.append(f"training ({train_year}-{train_month:02d})")
        if not val_exists:
            missing.append(f"validation ({val_year}-{val_month:02d})")
        print(f"⚠️  Missing datasets in S3: {', '.join(missing)}")
        print("Will download from public URL and optionally cache in S3")
    
    return availability_status


def load_and_prepare_data(**context):
    """Load training and validation data - uses S3 if available, otherwise downloads"""
    # Get dates from previous task or calculate dynamically
    task_instance = context['task_instance']
    dates = task_instance.xcom_pull(task_ids='calculate_dates')
    availability = task_instance.xcom_pull(task_ids='check_datasets')
    
    # Fallback to manual variables if needed
    if not dates:
        train_year = int(Variable.get("training_year", default_var=datetime.now().year))
        train_month = int(Variable.get("training_month", default_var=datetime.now().month))
        val_year = train_year if train_month < 12 else train_year + 1
        val_month = train_month + 1 if train_month < 12 else 1
    else:
        train_year = dates['train_year']
        train_month = dates['train_month']
        val_year = dates['val_year']
        val_month = dates['val_month']
    
    print(f"Loading training data for: {train_year}-{train_month:02d}")
    print(f"Loading validation data for: {val_year}-{val_month:02d}")
    
    # Determine data loading strategy based on availability check
    prefer_s3 = True  # Default to preferring S3
    if availability:
        if availability.get('both_available', False):
            print("📦 Using datasets from S3 (both available)")
        else:
            print("🌐 Will download from URL (datasets not in S3)")
    
    # Load training and validation data with S3 preference
    df_train, original_train_shape = read_dataframe(year=train_year, month=train_month, prefer_s3=prefer_s3)
    df_val, original_val_shape = read_dataframe(year=val_year, month=val_month, prefer_s3=prefer_s3)
    
    
    # Save dataframes for next tasks
    df_train.to_parquet('/tmp/df_train.parquet')
    df_val.to_parquet('/tmp/df_val.parquet')
    
    print(f"Training data shape: {df_train.shape}, from raw {original_train_shape} ")
    print(f"Validation data shape: {df_val.shape}, from raw {original_val_shape} ")
    
    return {"train_shape": df_train.shape, "val_shape": df_val.shape}


def create_X(df, dv=None):
    """Create feature matrix"""
    categorical = ['PU_DO']
    numerical = ['trip_distance']
    dicts = df[categorical + numerical].to_dict(orient='records')

    if dv is None:
        dv = DictVectorizer(sparse=True)
        X = dv.fit_transform(dicts)
    else:
        X = dv.transform(dicts)

    return X, dv


def prepare_features(**context):
    """Prepare features for training"""
    # Load dataframes
    df_train = pd.read_parquet('/tmp/df_train.parquet')
    df_val = pd.read_parquet('/tmp/df_val.parquet')
    
    # Create feature matrices
    X_train, dv = create_X(df_train)
    X_val, _ = create_X(df_val, dv)
    
    # Prepare target variables
    target = 'duration'
    y_train = df_train[target].values
    y_val = df_val[target].values
    
    # Save preprocessed data
    with open('/tmp/X_train.pkl', 'wb') as f:
        pickle.dump(X_train, f)
    with open('/tmp/X_val.pkl', 'wb') as f:
        pickle.dump(X_val, f)
    with open('/tmp/y_train.pkl', 'wb') as f:
        pickle.dump(y_train, f)
    with open('/tmp/y_val.pkl', 'wb') as f:
        pickle.dump(y_val, f)
    with open('/tmp/dv.pkl', 'wb') as f:
        pickle.dump(dv, f)
    
    print(f"Feature preparation completed")
    print(f"X_train shape: {X_train.shape}")
    print(f"X_val shape: {X_val.shape}")


def train_model(**context):
    """Train XGBoost model with MLflow tracking"""
    # Load preprocessed data
    with open('/tmp/X_train.pkl', 'rb') as f:
        X_train = pickle.load(f)
    with open('/tmp/X_val.pkl', 'rb') as f:
        X_val = pickle.load(f)
    with open('/tmp/y_train.pkl', 'rb') as f:
        y_train = pickle.load(f)
    with open('/tmp/y_val.pkl', 'rb') as f:
        y_val = pickle.load(f)
    with open('/tmp/dv.pkl', 'rb') as f:
        dv = pickle.load(f)
    
    with mlflow.start_run() as run:
        train = xgb.DMatrix(X_train, label=y_train)
        valid = xgb.DMatrix(X_val, label=y_val)

        best_params = {
            'learning_rate': 0.09585355369315604,
            'max_depth': 30,
            'min_child_weight': 1.060597050922164,
            'objective': 'reg:linear',
            'reg_alpha': 0.018060244040060163,
            'reg_lambda': 0.011658731377413597,
            'seed': 42
        }

        mlflow.log_params(best_params)

        booster = xgb.train(
            params=best_params,
            dtrain=train,
            num_boost_round=30,
            evals=[(valid, 'validation')],
            early_stopping_rounds=50
        )

        y_pred = booster.predict(valid)
        rmse = root_mean_squared_error(y_val, y_pred)
        mlflow.log_metric("rmse", rmse)

        # Save preprocessor to temporary local folder, then log to MLflow (which stores in S3)
        # MLflow will automatically use S3 bucket: mlops-taxi-prediction-mlflow-artifacts-dev
        models_folder = Path('/tmp/models')
        models_folder.mkdir(exist_ok=True)
        
        with open("/tmp/models/preprocessor.b", "wb") as f_out:
            pickle.dump(dv, f_out)
        mlflow.log_artifact("/tmp/models/preprocessor.b", artifact_path="preprocessor")

        # Log model to MLflow (automatically stored in S3 bucket: mlops-taxi-prediction-mlflow-artifacts-dev)
        mlflow.xgboost.log_model(booster, artifact_path="models_mlflow")
        
        print(f"Model and preprocessor saved to S3 bucket: {s3_models_bucket}")

        run_id = run.info.run_id
        
        # Save run_id for potential downstream tasks
        with open("run_id.txt", "w") as f:
            f.write(run_id)
        
        print(f"MLflow run_id: {run_id}")
        print(f"RMSE: {rmse}")
        
        return run_id


def validate_model(**context):
    """Validate the trained model performance"""
    with open("run_id.txt", "r") as f:
        run_id = f.read().strip()
    
    # You can add model validation logic here
    # For example, checking if RMSE is below a threshold
    print(f"Validating model with run_id: {run_id}")
    
    # Example validation logic
    client = mlflow.tracking.MlflowClient()
    run = client.get_run(run_id)
    rmse = run.data.metrics.get('rmse')
    
    if rmse and rmse < 10.0:  # Example threshold
        print(f"Model validation passed. RMSE: {rmse}")
        return True
    else:
        raise ValueError(f"Model validation failed. RMSE: {rmse}")


def integrate_s3_with_airflow(**context):
    """Configure S3 integration with boto3 for Airflow DAG"""
    try:
        # Get S3 bucket name from task kwargs
        bucket_name = context.get('bucket_name', 'mlops-pipeline-bucket')
        
        # Configure S3 client using Airflow connections or environment variables
        # This will automatically use:
        # 1. Airflow Connection with conn_id='aws_default' if configured
        # 2. Environment variables (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)
        # 3. EC2 instance profile or IAM role if running on AWS
        # 4. AWS credentials file (~/.aws/credentials)
        
        # Option 1: Using Airflow's BaseHook for connection management
        try:
            from airflow.providers.amazon.aws.hooks.base_aws import AwsBaseHook
            aws_hook = AwsBaseHook(aws_conn_id='aws_default')
            s3_client = aws_hook.get_client_type('s3')
            print("S3 client configured using Airflow connection 'aws_default'")
        except Exception as e:
            print(f"Could not use AwsBaseHook: {e}")
            # Fallback to direct boto3 client (uses environment variables or IAM role)
            s3_client = boto3.client('s3')
            print("S3 client configured using environment variables or IAM role")
        
        # Test S3 connection by listing buckets
        try:
            response = s3_client.list_buckets()
            buckets = [bucket['Name'] for bucket in response['Buckets']]
            print(f"S3 connection successful. Available buckets: {buckets}")
            
            # Check if our target bucket exists
            if bucket_name in buckets:
                print(f"Target bucket '{bucket_name}' found")
            else:
                print(f"Warning: Target bucket '{bucket_name}' not found in available buckets")
        except Exception as e:
            print(f"S3 connection test failed: {e}")
            raise
        
        # Store S3 client configuration info for downstream tasks
        context['task_instance'].xcom_push(
            key='s3_config',
            value={
                'bucket_name': bucket_name,
                'client_configured': True,
                'available_buckets': buckets
            }
        )
        
        print(f"S3 integration configured successfully for bucket: {bucket_name}")
        return {'status': 'success', 'bucket': bucket_name}
        
    except Exception as e:
        print(f"Failed to configure S3 integration: {e}")
        raise


# Define tasks
""" 
#Let's ignore this task for now, 
#seems to work better as variables defined in the script than inside a task.
setup_task = PythonOperator(
    task_id='setup_environment',
    python_callable=setup_environment,
    dag=dag,
)
"""

calculate_dates_task = PythonOperator(
    task_id='calculate_dates',
    python_callable=get_training_dates,
    dag=dag,
)

check_datasets_task = PythonOperator(
    task_id='check_datasets',
    python_callable=check_datasets_availability,
    dag=dag,
)

load_data_task = PythonOperator(
    task_id='load_and_prepare_data',
    python_callable=load_and_prepare_data,
    dag=dag,
)
"""
prepare_features_task = PythonOperator(
    task_id='prepare_features',
    python_callable=prepare_features,
    dag=dag,
)

train_model_task = PythonOperator(
    task_id='train_model',
    python_callable=train_model,
    dag=dag,
)
"""
# Also not important at this point. 
# Leaving it so it can be used later if needed.
"""
validate_model_task = PythonOperator(
    task_id='validate_model',
    python_callable=validate_model,
    dag=dag,
)
"""

# Optional but recommended: Clean up temporary files
cleanup_task = BashOperator(
    task_id='cleanup_temp_files',
    bash_command='rm -f /tmp/df_train.parquet /tmp/df_val.parquet /tmp/X_*.pkl /tmp/y_*.pkl /tmp/dv.pkl && rm -rf /tmp/models',
    dag=dag,
)

s3_task = PythonOperator(
    task_id='integrate_s3',
    python_callable=integrate_s3_with_airflow,
    op_kwargs={'bucket_name': 'mlops-taxi-prediction-mlflow-artifacts-dev'},
    dag=dag,
)

# Define task dependencies
calculate_dates_task >> check_datasets_task >> s3_task >> load_data_task >> cleanup_task
#prepare_features_task >> train_model_task >>
