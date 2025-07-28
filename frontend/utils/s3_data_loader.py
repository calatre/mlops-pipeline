"""
S3 data loader for loading NYC taxi data from AWS S3
Enhanced with parquet file support and Kinesis-compatible transformations
"""
import boto3
import json
import logging
import pandas as pd
import io
from typing import List, Dict, Any, Optional
from datetime import datetime

logger = logging.getLogger(__name__)

class S3DataLoader:
    """Enhanced S3 data loader for NYC taxi trip data"""
    
    def __init__(self, bucket_name: str, region_name: str = 'us-east-1'):
        """
        Initialize S3 client
        
        Args:
            bucket_name: Name of the S3 bucket
            region_name: AWS region name
        """
        self.bucket_name = bucket_name
        self.s3_client = boto3.client('s3', region_name=region_name)
        
    def list_objects(self, prefix: str = '') -> List[Dict[str, Any]]:
        """
        List objects in S3 bucket
        
        Args:
            prefix: Prefix to filter objects
            
        Returns:
            List of object metadata
        """
        try:
            response = self.s3_client.list_objects_v2(
                Bucket=self.bucket_name,
                Prefix=prefix
            )
            
            objects = []
            if 'Contents' in response:
                for obj in response['Contents']:
                    objects.append({
                        'key': obj['Key'],
                        'size': obj['Size'],
                        'last_modified': obj['LastModified'].isoformat()
                    })
            
            logger.info(f"Listed {len(objects)} objects from S3")
            return objects
            
        except Exception as e:
            logger.error(f"Error listing S3 objects: {str(e)}")
            raise
    
    def list_parquet_files(self, prefix: str = 'raw-data/') -> List[Dict[str, Any]]:
        """
        List available parquet files from S3 bucket
        
        Args:
            prefix: Prefix to filter parquet files (default: 'raw-data/')
            
        Returns:
            List of parquet file metadata
        """
        try:
            all_objects = self.list_objects(prefix)
            parquet_files = [
                obj for obj in all_objects 
                if obj['key'].endswith('.parquet')
            ]
            
            logger.info(f"Found {len(parquet_files)} parquet files in S3")
            return parquet_files
            
        except Exception as e:
            logger.error(f"Error listing parquet files: {str(e)}")
            raise
    
    def read_parquet_file(self, key: str, sample_size: Optional[int] = None) -> pd.DataFrame:
        """
        Read a parquet file from S3
        
        Args:
            key: S3 object key
            sample_size: Optional number of rows to sample
            
        Returns:
            Pandas DataFrame
        """
        try:
            response = self.s3_client.get_object(
                Bucket=self.bucket_name,
                Key=key
            )
            
            # Read parquet from S3 response body
            df = pd.read_parquet(io.BytesIO(response['Body'].read()))
            
            if sample_size and sample_size < len(df):
                df = df.sample(n=sample_size, random_state=42)
                logger.info(f"Sampled {sample_size} rows from {key}")
            else:
                logger.info(f"Loaded {len(df)} rows from {key}")
            
            return df
            
        except Exception as e:
            logger.error(f"Error reading parquet file from S3: {str(e)}")
            raise
    
    def read_single_trip_record(self, key: str, record_index: int = 0) -> Dict[str, Any]:
        """
        Read a single trip record from a parquet file
        
        Args:
            key: S3 object key
            record_index: Index of the record to read (default: 0)
            
        Returns:
            Single trip record as dictionary
        """
        try:
            # Read only the needed row for efficiency
            df = self.read_parquet_file(key, sample_size=record_index + 1)
            
            if len(df) <= record_index:
                raise ValueError(f"Record index {record_index} out of range for file {key}")
            
            # Convert the row to dictionary
            record = df.iloc[record_index].to_dict()
            
            logger.info(f"Read single record from {key} at index {record_index}")
            return record
            
        except Exception as e:
            logger.error(f"Error reading single trip record: {str(e)}")
            raise
    
    def transform_to_kinesis_format(self, trip_record: Dict[str, Any]) -> Dict[str, Any]:
        """
        Transform NYC taxi trip record to Kinesis-compatible JSON format
        
        Args:
            trip_record: Raw trip record from parquet file
            
        Returns:
            Transformed record ready for Kinesis
        """
        try:
            # Convert timestamps to ISO format strings
            for field in ['tpep_pickup_datetime', 'tpep_dropoff_datetime']:
                if field in trip_record and pd.notna(trip_record[field]):
                    if isinstance(trip_record[field], pd.Timestamp):
                        trip_record[field] = trip_record[field].isoformat()
                    elif isinstance(trip_record[field], str):
                        # Already a string, validate it's ISO format
                        datetime.fromisoformat(trip_record[field].replace('Z', '+00:00'))
            
            # Calculate duration if not present
            if 'duration' not in trip_record and all(key in trip_record for key in ['tpep_pickup_datetime', 'tpep_dropoff_datetime']):
                pickup = pd.to_datetime(trip_record['tpep_pickup_datetime'])
                dropoff = pd.to_datetime(trip_record['tpep_dropoff_datetime'])
                duration_minutes = (dropoff - pickup).total_seconds() / 60
                trip_record['duration'] = duration_minutes
            
            # Create Kinesis-compatible format
            kinesis_record = {
                'event_id': f"trip_{datetime.now().timestamp()}_{trip_record.get('PULocationID', 'unknown')}",
                'event_type': 'taxi_trip_request',
                'timestamp': datetime.now().isoformat(),
                'data': {
                    'pickup_datetime': trip_record.get('tpep_pickup_datetime'),
                    'dropoff_datetime': trip_record.get('tpep_dropoff_datetime'),
                    'pickup_location_id': str(trip_record.get('PULocationID', '')),
                    'dropoff_location_id': str(trip_record.get('DOLocationID', '')),
                    'passenger_count': int(trip_record.get('passenger_count', 1)),
                    'trip_distance': float(trip_record.get('trip_distance', 0)),
                    'duration_minutes': float(trip_record.get('duration', 0)),
                    'total_amount': float(trip_record.get('total_amount', 0)),
                    'payment_type': int(trip_record.get('payment_type', 1))
                }
            }
            
            logger.info("Transformed trip record to Kinesis format")
            return kinesis_record
            
        except Exception as e:
            logger.error(f"Error transforming record to Kinesis format: {str(e)}")
            raise
    
    def validate_kinesis_record(self, kinesis_record: Dict[str, Any]) -> bool:
        """
        Validate that a record is ready for Kinesis
        
        Args:
            kinesis_record: Record to validate
            
        Returns:
            True if valid, raises exception if not
        """
        try:
            # Check required top-level fields
            required_fields = ['event_id', 'event_type', 'timestamp', 'data']
            for field in required_fields:
                if field not in kinesis_record:
                    raise ValueError(f"Missing required field: {field}")
            
            # Check data fields
            data = kinesis_record['data']
            required_data_fields = ['pickup_location_id', 'dropoff_location_id']
            for field in required_data_fields:
                if field not in data:
                    raise ValueError(f"Missing required data field: {field}")
            
            # Validate timestamps
            datetime.fromisoformat(kinesis_record['timestamp'].replace('Z', '+00:00'))
            
            # Validate numeric fields
            numeric_fields = ['passenger_count', 'trip_distance', 'duration_minutes', 'total_amount']
            for field in numeric_fields:
                if field in data and data[field] is not None:
                    float(data[field])  # This will raise if not numeric
            
            # Check data can be serialized to JSON
            json.dumps(kinesis_record)
            
            logger.info("Kinesis record validation passed")
            return True
            
        except Exception as e:
            logger.error(f"Kinesis record validation failed: {str(e)}")
            raise
    
    def load_and_transform_trip(self, key: str, record_index: int = 0) -> Dict[str, Any]:
        """
        Complete workflow: load a trip record and transform it for Kinesis
        
        Args:
            key: S3 object key
            record_index: Index of the record to read
            
        Returns:
            Validated Kinesis-ready record
        """
        try:
            # Read single trip record
            trip_record = self.read_single_trip_record(key, record_index)
            
            # Transform to Kinesis format
            kinesis_record = self.transform_to_kinesis_format(trip_record)
            
            # Validate the record
            self.validate_kinesis_record(kinesis_record)
            
            return kinesis_record
            
        except Exception as e:
            logger.error(f"Error in load and transform workflow: {str(e)}")
            raise
    
    def load_json_data(self, key: str) -> Dict[str, Any]:
        """
        Load JSON data from S3 (kept for backward compatibility)
        
        Args:
            key: S3 object key
            
        Returns:
            Parsed JSON data
        """
        try:
            response = self.s3_client.get_object(
                Bucket=self.bucket_name,
                Key=key
            )
            
            data = json.loads(response['Body'].read().decode('utf-8'))
            logger.info(f"Loaded JSON data from S3: {key}")
            return data
            
        except Exception as e:
            logger.error(f"Error loading JSON from S3: {str(e)}")
            raise
    
    def load_text_data(self, key: str) -> str:
        """
        Load text data from S3 (kept for backward compatibility)
        
        Args:
            key: S3 object key
            
        Returns:
            Text content
        """
        try:
            response = self.s3_client.get_object(
                Bucket=self.bucket_name,
                Key=key
            )
            
            content = response['Body'].read().decode('utf-8')
            logger.info(f"Loaded text data from S3: {key}")
            return content
            
        except Exception as e:
            logger.error(f"Error loading text from S3: {str(e)}")
            raise
    
    def upload_data(self, key: str, data: Any, content_type: str = 'application/json') -> Dict[str, Any]:
        """
        Upload data to S3 (kept for backward compatibility)
        
        Args:
            key: S3 object key
            data: Data to upload
            content_type: Content type of the data
            
        Returns:
            Upload response
        """
        try:
            if content_type == 'application/json':
                body = json.dumps(data)
            else:
                body = str(data)
            
            response = self.s3_client.put_object(
                Bucket=self.bucket_name,
                Key=key,
                Body=body,
                ContentType=content_type
            )
            
            logger.info(f"Uploaded data to S3: {key}")
            return response
            
        except Exception as e:
            logger.error(f"Error uploading to S3: {str(e)}")
            raise
