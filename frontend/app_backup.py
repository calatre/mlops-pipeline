"""
Flask application for MLOps Pipeline Frontend
"""
from flask import Flask, render_template, jsonify, request
from flask_cors import CORS
import os
import boto3
import json
from datetime import datetime
import random
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

app = Flask(__name__)
CORS(app)

# Configuration
app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', 'dev-secret-key')
app.config['DEBUG'] = os.environ.get('FLASK_DEBUG', 'True').lower() == 'true'

# AWS Configuration
AWS_REGION = os.environ.get('AWS_DEFAULT_REGION', 'eu-north-1')
KINESIS_STREAM_NAME = os.environ.get('KINESIS_STREAM_NAME', 'taxi-ride-predictions-stream')
DATA_BUCKET = os.environ.get('DATA_STORAGE_BUCKET', 'mlops-taxi-prediction-data-storage-dev')

# Initialize AWS clients
kinesis_client = boto3.client('kinesis', region_name=AWS_REGION)
s3_client = boto3.client('s3', region_name=AWS_REGION)
lambda_client = boto3.client('lambda', region_name=AWS_REGION)

@app.route('/')
def index():
    """Render the main dashboard"""
    return render_template('index.html', current_time=datetime.now().strftime('%H:%M:%S'))

@app.route('/api/health')
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now().isoformat(),
        'service': 'mlops-frontend'
    })

@app.route('/api/health/kinesis')
def kinesis_health():
    """Check Kinesis stream health"""
    try:
        response = kinesis_client.describe_stream(StreamName=KINESIS_STREAM_NAME)
        stream_status = response['StreamDescription']['StreamStatus']
        return jsonify({
            'healthy': stream_status == 'ACTIVE',
            'status': stream_status
        })
    except Exception as e:
        return jsonify({'healthy': False, 'error': str(e)})

@app.route('/api/health/lambda')
def lambda_health():
    """Check Lambda function health"""
    try:
        function_name = os.environ.get('LAMBDA_FUNCTION_NAME', 'taxi-trip-duration-predictor')
        response = lambda_client.get_function(FunctionName=function_name)
        return jsonify({
            'healthy': response['Configuration']['State'] == 'Active',
            'status': response['Configuration']['State']
        })
    except Exception as e:
        return jsonify({'healthy': False, 'error': str(e)})

@app.route('/api/events', methods=['POST'])
def submit_event():
    """Submit event to Kinesis stream"""
    try:
        data = request.get_json()
        event_type = data.get('type', 'synthetic')
        
        if event_type == 'synthetic':
            # Generate synthetic taxi trip data
            event_data = generate_synthetic_event(data.get('data', {}))
        else:
            # Load real trip from S3
            s3_key = data.get('data', {}).get('s3_key')
            event_data = load_trip_from_s3(s3_key)
        
        # Send to Kinesis
        response = kinesis_client.put_record(
            StreamName=KINESIS_STREAM_NAME,
            Data=json.dumps(event_data),
            PartitionKey=str(datetime.now().timestamp())
        )
        
        return jsonify({
            'status': 'success',
            'message': 'Event submitted successfully',
            'event_id': response['SequenceNumber'],
            'shard_id': response['ShardId']
        }), 201
        
    except Exception as e:
        return jsonify({
            'status': 'error',
            'message': str(e)
        }), 500

@app.route('/api/kinesis/records')
def get_kinesis_records():
    """Get recent records from Kinesis stream"""
    try:
        # Get stream description
        stream_desc = kinesis_client.describe_stream(StreamName=KINESIS_STREAM_NAME)
        shard_id = stream_desc['StreamDescription']['Shards'][0]['ShardId']
        
        # Get shard iterator
        iterator_response = kinesis_client.get_shard_iterator(
            StreamName=KINESIS_STREAM_NAME,
            ShardId=shard_id,
            ShardIteratorType='LATEST'
        )
        
        # Get records
        records_response = kinesis_client.get_records(
            ShardIterator=iterator_response['ShardIterator'],
            Limit=10
        )
        
        # Parse records
        records = []
        for record in records_response['Records']:
            try:
                data = json.loads(record['Data'])
                records.append({
                    'timestamp': record['ApproximateArrivalTimestamp'].isoformat(),
                    'prediction': data.get('prediction', 0),
                    'model_version': data.get('model_version', 'unknown'),
                    'sequence_number': record['SequenceNumber']
                })
            except:
                pass
        
        return jsonify({'records': records})
        
    except Exception as e:
        return jsonify({'error': str(e), 'records': []}), 500

def generate_synthetic_event(params):
    """Generate synthetic taxi trip event"""
    # NYC taxi trip synthetic data
    return {
        'vendor_id': random.choice([1, 2]),
        'pickup_datetime': datetime.now().isoformat(),
        'dropoff_datetime': datetime.now().isoformat(),
        'passenger_count': params.get('passenger_count', 1),
        'pickup_longitude': -73.98 + random.uniform(-0.1, 0.1),
        'pickup_latitude': 40.75 + random.uniform(-0.1, 0.1),
        'dropoff_longitude': -73.98 + random.uniform(-0.1, 0.1),
        'dropoff_latitude': 40.75 + random.uniform(-0.1, 0.1),
        'store_and_fwd_flag': 'N',
        'trip_duration': params.get('trip_duration', 15) * 60,  # Convert to seconds
        'synthetic': True
    }

def load_trip_from_s3(s3_key):
    """Load trip data from S3"""
    if not s3_key:
        raise ValueError("S3 key is required")
    
    try:
        response = s3_client.get_object(Bucket=DATA_BUCKET, Key=s3_key)
        return json.loads(response['Body'].read())
    except Exception as e:
        raise Exception(f"Failed to load from S3: {str(e)}")

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
