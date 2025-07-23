"""
Test consumer script to verify the end-to-end taxi prediction pipeline
"""
import json
import boto3
import time
import random
from datetime import datetime
import os
import argparse
from ride import Ride, create_sample_ride


class PipelineTester:
    """Test the end-to-end taxi prediction pipeline"""
    
    def __init__(self, kinesis_stream: str, s3_bucket: str, region: str = "us-east-1"):
        self.kinesis_stream = kinesis_stream
        self.s3_bucket = s3_bucket
        self.region = region
        
        self.kinesis_client = boto3.client('kinesis', region_name=region)
        self.s3_client = boto3.client('s3', region_name=region)
    
    def create_test_ride(self) -> Ride:
        """Create a test taxi ride event using the Ride class"""
        ride = create_sample_ride()
        ride.ride_id = f"test_ride_{datetime.now().strftime('%Y%m%d_%H%M%S_%f')}"
        return ride
    
    def send_test_ride(self, test_ride: Ride) -> bool:
        """Send a test ride to Kinesis stream"""
        try:
            response = self.kinesis_client.put_record(
                StreamName=self.kinesis_stream,
                Data=test_ride.to_json(),
                PartitionKey=test_ride.ride_id
            )
            
            print(f"✓ Test ride sent successfully!")
            print(f"  Ride ID: {test_ride.ride_id}")
            print(f"  From: {test_ride.PULocationID} to {test_ride.DOLocationID}")
            print(f"  Distance: {test_ride.trip_distance} miles")
            print(f"  Kinesis Shard: {response['ShardId']}")
            print(f"  Sequence Number: {response['SequenceNumber']}")
            
            return True
            
        except Exception as e:
            print(f"✗ Error sending test ride: {e}")
            return False
    
    def check_prediction_result(self, ride_id: str, max_wait_seconds: int = 60) -> dict:
        """Check if prediction result appears in S3"""
        print(f"\nChecking for prediction result (max wait: {max_wait_seconds}s)...")
        
        start_time = time.time()
        check_count = 0
        
        while time.time() - start_time < max_wait_seconds:
            check_count += 1
            print(f"Check #{check_count} - Looking for prediction result...")
            
            # Check today's predictions
            today = datetime.utcnow().strftime('%Y/%m/%d')
            prefix = f"predictions/{today}/"
            
            try:
                # List objects with the predictions prefix
                paginator = self.s3_client.get_paginator('list_objects_v2')
                pages = paginator.paginate(Bucket=self.s3_bucket, Prefix=prefix)
                
                for page in pages:
                    if 'Contents' in page:
                        for obj in page['Contents']:
                            # Check if this file contains our ride_id
                            if ride_id in obj['Key']:
                                # Found a matching file, get the prediction
                                response = self.s3_client.get_object(
                                    Bucket=self.s3_bucket, 
                                    Key=obj['Key']
                                )
                                
                                prediction_data = json.loads(response['Body'].read())
                                
                                print(f"✓ Prediction found!")
                                print(f"  File: s3://{self.s3_bucket}/{obj['Key']}")
                                print(f"  Predicted Duration: {prediction_data['predicted_duration']:.2f} minutes")
                                print(f"  Features: {prediction_data['features']}")
                                print(f"  Timestamp: {prediction_data['timestamp']}")
                                
                                return prediction_data
                
            except Exception as e:
                print(f"Error checking predictions: {e}")
            
            # Wait before next check
            time.sleep(5)
        
        print(f"✗ No prediction result found after {max_wait_seconds} seconds")
        return None
    
    def run_full_test(self, max_wait_seconds: int = 60) -> bool:
        """Run a complete end-to-end test"""
        print("=" * 60)
        print("TAXI PREDICTION PIPELINE - END-TO-END TEST")
        print("=" * 60)
        
        # Step 1: Create test ride
        print("\n1. Creating test ride...")
        test_ride = self.create_test_ride()
        
        # Step 2: Send to Kinesis
        print("\n2. Sending test ride to Kinesis...")
        if not self.send_test_ride(test_ride):
            return False
        
        # Step 3: Wait and check for prediction
        print("\n3. Waiting for Lambda to process and generate prediction...")
        prediction_result = self.check_prediction_result(
            test_ride.ride_id, 
            max_wait_seconds
        )
        
        # Step 4: Report results
        print("\n4. Test Results:")
        if prediction_result:
            print("✓ END-TO-END TEST PASSED!")
            print("  The pipeline successfully:")
            print("  - Received the test ride from Kinesis")
            print("  - Loaded the ML model")
            print("  - Made a prediction")
            print("  - Logged the result to S3")
            return True
        else:
            print("✗ END-TO-END TEST FAILED!")
            print("  The prediction was not found in S3.")
            print("  Possible issues:")
            print("  - Lambda function not working")
            print("  - Model loading issues")  
            print("  - S3 permissions problems")
            print("  - Kinesis-Lambda integration problems")
            return False
    
    def list_recent_predictions(self, hours_back: int = 1):
        """List recent predictions for debugging"""
        print(f"\nListing predictions from the last {hours_back} hour(s)...")
        
        # Check predictions from recent hours
        for hour in range(hours_back):
            check_time = datetime.utcnow()
            if hour > 0:
                from datetime import timedelta
                check_time = check_time - timedelta(hours=hour)
            
            date_str = check_time.strftime('%Y/%m/%d')
            prefix = f"predictions/{date_str}/"
            
            try:
                paginator = self.s3_client.get_paginator('list_objects_v2')
                pages = paginator.paginate(Bucket=self.s3_bucket, Prefix=prefix)
                
                count = 0
                for page in pages:
                    if 'Contents' in page:
                        for obj in page['Contents']:
                            count += 1
                            if count <= 5:  # Show first 5
                                print(f"  {obj['Key']} (Size: {obj['Size']} bytes)")
                
                if count > 5:
                    print(f"  ... and {count - 5} more files")
                elif count == 0:
                    print(f"  No predictions found for {date_str}")
                else:
                    print(f"  Total: {count} prediction files")
                    
            except Exception as e:
                print(f"Error listing predictions for {date_str}: {e}")


def main():
    parser = argparse.ArgumentParser(description='Test the taxi prediction pipeline end-to-end')
    parser.add_argument('--stream', type=str,
                       default=os.environ.get('KINESIS_STREAM_NAME', 'taxi-ride-predictions-stream'),
                       help='Kinesis stream name')
    parser.add_argument('--bucket', type=str,
                       default=os.environ.get('DATA_STORAGE_BUCKET', 'mlops-taxi-prediction-data-storage-dev'),
                       help='S3 bucket name for predictions')
    parser.add_argument('--wait', type=int, default=60,
                       help='Max seconds to wait for prediction result (default: 60)')
    parser.add_argument('--list-recent', action='store_true',
                       help='List recent predictions instead of running test')
    parser.add_argument('--region', type=str, default='us-east-1',
                       help='AWS region (default: us-east-1)')
    
    args = parser.parse_args()
    
    # Create pipeline tester
    tester = PipelineTester(
        kinesis_stream=args.stream,
        s3_bucket=args.bucket,
        region=args.region
    )
    
    if args.list_recent:
        # Just list recent predictions
        tester.list_recent_predictions(hours_back=2)
    else:
        # Run full end-to-end test
        success = tester.run_full_test(max_wait_seconds=args.wait)
        
        if not success:
            print("\nFor debugging, here are recent predictions:")
            tester.list_recent_predictions(hours_back=1)
            return 1
    
    return 0


if __name__ == "__main__":
    exit(main())
