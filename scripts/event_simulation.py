import json
import boto3
import pandas as pd
import time
import random
from datetime import datetime, timedelta
import os
import argparse

class RideEvent:
    def __init__(self, ride_data):
        """Create a ride event from pandas row"""
        self.ride_id = f"ride_{int(time.time() * 1000)}_{random.randint(1000, 9999)}"
        self.pickup_location_id = str(ride_data['PULocationID'])
        self.dropoff_location_id = str(ride_data['DOLocationID'])
        self.trip_distance = float(ride_data['trip_distance'])
        self.pickup_datetime = datetime.now().isoformat()
        
    def to_dict(self):
        """Convert to dictionary for JSON serialization"""
        return {
            'ride_id': self.ride_id,
            'PULocationID': self.pickup_location_id,
            'DOLocationID': self.dropoff_location_id,
            'trip_distance': self.trip_distance,
            'pickup_datetime': self.pickup_datetime
        }

def load_data_from_s3(bucket: str, key: str):
    """Load cleaned taxi data from S3"""
    s3_client = boto3.client('s3')
    
    # Download to temporary file
    temp_file = '/tmp/taxi_data_for_simulation.parquet'
    print(f"Downloading data from s3://{bucket}/{key}")
    s3_client.download_file(bucket, key, temp_file)
    
    # Load dataframe
    df = pd.read_parquet(temp_file)
    
    # Clean up
    os.remove(temp_file)
    
    print(f"Loaded {len(df)} rides for simulation")
    return df

def send_event_to_kinesis(kinesis_client, stream_name: str, ride_event: RideEvent):
    """Send a single ride event to Kinesis"""
    event_data = ride_event.to_dict()
    
    response = kinesis_client.put_record(
        StreamName=stream_name,
        Data=json.dumps(event_data),
        PartitionKey=ride_event.ride_id
    )
    
    return response

def simulate_ride_events(df: pd.DataFrame, stream_name: str, interval_seconds: float = 1.0, max_events: int = None):
    """Simulate ride events by sending data to Kinesis stream"""
    kinesis_client = boto3.client('kinesis')
    
    print(f"Starting event simulation to stream: {stream_name}")
    print(f"Event interval: {interval_seconds} seconds")
    if max_events:
        print(f"Max events: {max_events}")
    
    event_count = 0
    
    try:
        # Sample from dataframe randomly
        for _, ride_data in df.sample(frac=1).iterrows():
            if max_events and event_count >= max_events:
                break
                
            # Create ride event
            ride_event = RideEvent(ride_data)
            
            # Send to Kinesis
            try:
                response = send_event_to_kinesis(kinesis_client, stream_name, ride_event)
                event_count += 1
                
                print(f"Event {event_count}: Sent ride {ride_event.ride_id} "
                      f"from {ride_event.pickup_location_id} to {ride_event.dropoff_location_id} "
                      f"(distance: {ride_event.trip_distance:.2f})")
                
                # Wait before next event
                time.sleep(interval_seconds)
                
            except Exception as e:
                print(f"Error sending event: {e}")
                continue
                
    except KeyboardInterrupt:
        print(f"\nSimulation stopped by user. Sent {event_count} events.")
    
    print(f"Event simulation completed. Total events sent: {event_count}")

def main():
    parser = argparse.ArgumentParser(description='Simulate taxi ride events to Kinesis')
    parser.add_argument('--interval', type=float, default=1.0, 
                       help='Interval between events in seconds (default: 1.0)')
    parser.add_argument('--max-events', type=int, default=None,
                       help='Maximum number of events to send (default: unlimited)')
    parser.add_argument('--bucket', type=str, 
                       default=os.environ.get('DATA_STORAGE_BUCKET', 'mlops-taxi-prediction-data-storage-dev'),
                       help='S3 bucket name')
    parser.add_argument('--stream', type=str,
                       default=os.environ.get('KINESIS_STREAM_NAME', 'taxi-ride-predictions-stream'),
                       help='Kinesis stream name')
    
    args = parser.parse_args()
    
    # Get current year and month minus 2 years for data file
    current_date = datetime.now()
    year = current_date.year - 2
    month = current_date.month
    
    key = f'raw-data/yellow_tripdata_{year}-{month:02d}.parquet'
    
    try:
        # Load data from S3
        df = load_data_from_s3(args.bucket, key)
        
        # Start event simulation
        simulate_ride_events(
            df=df,
            stream_name=args.stream,
            interval_seconds=args.interval,
            max_events=args.max_events
        )
        
    except Exception as e:
        print(f"Error in event simulation: {e}")
        return 1
    
    return 0

if __name__ == '__main__':
    exit(main())
