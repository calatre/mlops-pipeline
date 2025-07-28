"""
Test script for S3 data loader functionality
"""
import os
import sys
import json
from datetime import datetime
from dotenv import load_dotenv

# Add the current directory to Python path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from utils.s3_data_loader import S3DataLoader
from utils.kinesis_client import KinesisClient

# Load environment variables
load_dotenv()

def test_s3_loader():
    """Test the S3 data loader functionality"""
    
    # Configuration
    AWS_REGION = os.environ.get('AWS_DEFAULT_REGION', 'eu-north-1')
    DATA_BUCKET = os.environ.get('DATA_STORAGE_BUCKET', 'mlops-taxi-prediction-data-storage-dev')
    KINESIS_STREAM_NAME = os.environ.get('KINESIS_STREAM_NAME', 'taxi-ride-predictions-stream')
    
    print(f"Testing S3 Data Loader")
    print(f"Bucket: {DATA_BUCKET}")
    print(f"Region: {AWS_REGION}")
    print("-" * 50)
    
    # Initialize loader
    loader = S3DataLoader(DATA_BUCKET, region_name=AWS_REGION)
    
    # Test 1: List parquet files
    print("\n1. Listing parquet files:")
    try:
        files = loader.list_parquet_files()
        print(f"Found {len(files)} parquet files:")
        for file in files[:3]:  # Show first 3
            print(f"  - {file['key']} ({file['size']} bytes)")
        if len(files) > 3:
            print(f"  ... and {len(files) - 3} more files")
    except Exception as e:
        print(f"Error listing files: {e}")
        return
    
    if not files:
        print("No parquet files found. Please upload data first using data_setup.py")
        return
    
    # Test 2: Read a single trip record
    print("\n2. Reading a single trip record:")
    try:
        first_file = files[0]['key']
        record = loader.read_single_trip_record(first_file, record_index=0)
        print(f"Sample record from {first_file}:")
        # Show first few fields
        for key, value in list(record.items())[:5]:
            print(f"  {key}: {value}")
        print(f"  ... and {len(record) - 5} more fields")
    except Exception as e:
        print(f"Error reading record: {e}")
        return
    
    # Test 3: Transform to Kinesis format
    print("\n3. Transforming to Kinesis format:")
    try:
        kinesis_record = loader.transform_to_kinesis_format(record)
        print("Kinesis-formatted record:")
        print(json.dumps(kinesis_record, indent=2))
    except Exception as e:
        print(f"Error transforming record: {e}")
        return
    
    # Test 4: Validate the record
    print("\n4. Validating Kinesis record:")
    try:
        is_valid = loader.validate_kinesis_record(kinesis_record)
        print(f"Validation result: {'PASSED' if is_valid else 'FAILED'}")
    except Exception as e:
        print(f"Validation error: {e}")
    
    # Test 5: Complete workflow
    print("\n5. Testing complete workflow (load + transform + validate):")
    try:
        complete_record = loader.load_and_transform_trip(first_file, record_index=1)
        print("Successfully loaded, transformed, and validated record:")
        print(f"  Event ID: {complete_record['event_id']}")
        print(f"  Event Type: {complete_record['event_type']}")
        print(f"  Timestamp: {complete_record['timestamp']}")
        print(f"  Data fields: {list(complete_record['data'].keys())}")
    except Exception as e:
        print(f"Workflow error: {e}")
    
    # Optional: Test Kinesis integration
    print("\n6. Testing Kinesis integration (optional):")
    try:
        kinesis = KinesisClient(KINESIS_STREAM_NAME, region_name=AWS_REGION)
        response = kinesis.send_event(complete_record)
        print(f"Successfully sent to Kinesis!")
        print(f"  Sequence Number: {response['SequenceNumber']}")
        print(f"  Shard ID: {response['ShardId']}")
    except Exception as e:
        print(f"Kinesis error (this is expected if Kinesis is not set up): {e}")
    
    print("\n" + "=" * 50)
    print("S3 Data Loader test completed!")

if __name__ == "__main__":
    test_s3_loader()
