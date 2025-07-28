"""
Kinesis client for sending events to AWS Kinesis Data Streams
"""
import boto3
import json
import logging
from datetime import datetime
from typing import Dict, Any, Optional

logger = logging.getLogger(__name__)

class KinesisClient:
    """Simple Kinesis client for sending events"""
    
    def __init__(self, stream_name: str, region_name: str = 'us-east-1'):
        """
        Initialize Kinesis client
        
        Args:
            stream_name: Name of the Kinesis stream
            region_name: AWS region name
        """
        self.stream_name = stream_name
        self.client = boto3.client('kinesis', region_name=region_name)
        
    def send_event(self, event_data: Dict[str, Any], partition_key: Optional[str] = None) -> Dict[str, Any]:
        """
        Send an event to Kinesis stream
        
        Args:
            event_data: Dictionary containing event data
            partition_key: Optional partition key for the event
            
        Returns:
            Response from Kinesis
        """
        try:
            # Add timestamp if not present
            if 'timestamp' not in event_data:
                event_data['timestamp'] = datetime.now().isoformat()
            
            # Use timestamp as partition key if not provided
            if partition_key is None:
                partition_key = str(datetime.now().timestamp())
            
            # Send to Kinesis
            response = self.client.put_record(
                StreamName=self.stream_name,
                Data=json.dumps(event_data),
                PartitionKey=partition_key
            )
            
            logger.info(f"Event sent to Kinesis: {response['SequenceNumber']}")
            return response
            
        except Exception as e:
            logger.error(f"Error sending event to Kinesis: {str(e)}")
            raise
    
    def send_batch_events(self, events: list[Dict[str, Any]]) -> Dict[str, Any]:
        """
        Send multiple events to Kinesis in a batch
        
        Args:
            events: List of event dictionaries
            
        Returns:
            Response from Kinesis
        """
        try:
            records = []
            for event in events:
                if 'timestamp' not in event:
                    event['timestamp'] = datetime.now().isoformat()
                
                records.append({
                    'Data': json.dumps(event),
                    'PartitionKey': str(datetime.now().timestamp())
                })
            
            response = self.client.put_records(
                StreamName=self.stream_name,
                Records=records
            )
            
            logger.info(f"Batch sent to Kinesis: {len(records)} events")
            return response
            
        except Exception as e:
            logger.error(f"Error sending batch to Kinesis: {str(e)}")
            raise
