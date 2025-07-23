import pandas as pd
import boto3
import os
from datetime import datetime

def get_data_date():
    """Get year and month for data (current month minus 2 years)"""
    current_date = datetime.now()
    year = current_date.year - 2
    month = current_date.month
    return year, month

def read_dataframe(url: str, year: int, month: int):
    """Read and clean taxi data like in mlops-zoomcamp-andre preprocessing with date filtering"""
    print(f"Downloading data from: {url}")
    df = pd.read_parquet(url)
    
    print(f"Original data shape: {df.shape}")
    
    # Same preprocessing as in preprocess_data.py
    df['duration'] = df['tpep_dropoff_datetime'] - df['tpep_pickup_datetime']
    df.duration = df.duration.apply(lambda td: td.total_seconds() / 60)
    
    # Filter out outliers (duration between 1 and 60 minutes)
    df = df[(df.duration >= 1) & (df.duration <= 60)]
    
    # Date filtering - important step from chapter 05
    # Filter to ensure rides are from the correct month/year
    df = df[df['tpep_pickup_datetime'].dt.year == year]
    df = df[df['tpep_pickup_datetime'].dt.month == month]
    
    print(f"After date filtering: {df.shape}")
    
    # Convert categorical columns to strings
    categorical = ['PULocationID', 'DOLocationID']
    df[categorical] = df[categorical].astype(str)
    
    print(f"Final cleaned data shape: {df.shape}")
    return df

def upload_to_s3(df: pd.DataFrame, bucket: str, key: str):
    """Upload dataframe to S3"""
    s3_client = boto3.client('s3')
    
    # Save to temporary file
    temp_file = '/tmp/taxi_data.parquet'
    df.to_parquet(temp_file)
    
    # Upload to S3
    print(f"Uploading to s3://{bucket}/{key}")
    s3_client.upload_file(temp_file, bucket, key)
    
    # Clean up
    os.remove(temp_file)
    print("Upload completed!")

def main():
    # Get data date (current month minus 2 years for reproducibility)
    year, month = get_data_date()
    print(f"Using data from: {year}-{month:02d}")
    
    url = f'https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_{year}-{month:02d}.parquet'
    
    # Read and clean data with date filtering
    df = read_dataframe(url, year, month)
    
    # Get bucket name from terraform output or environment variable
    bucket = os.environ.get('DATA_STORAGE_BUCKET', 'mlops-taxi-prediction-data-storage-dev')
    key = f'raw-data/yellow_tripdata_{year}-{month:02d}.parquet'
    
    # Upload to S3
    upload_to_s3(df, bucket, key)
    
    print(f"Data prepared and uploaded to S3: s3://{bucket}/{key}")
    print(f"Total rides: {len(df)}")

if __name__ == '__main__':
    main()
