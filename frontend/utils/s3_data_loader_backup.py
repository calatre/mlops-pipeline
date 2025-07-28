"""
S3 data loader for loading data from AWS S3
"""
import boto3
import json
import logging
from typing import List, Dict, Any, Optional
import io

logger = logging.getLogger(__name__)

class S3DataLoader:
    """Simple S3 data loader for retrieving data"""
    
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
    
    def load_json_data(self, key: str) -> Dict[str, Any]:
        """
        Load JSON data from S3
        
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
        Load text data from S3
        
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
        Upload data to S3
        
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
