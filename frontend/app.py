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

# Import our utilities
from utils.s3_data_loader import S3DataLoader
from utils.kinesis_client import KinesisClient
from utils.event_generator import EventGenerator

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

# Initialize our utilities
s3_loader = S3DataLoader(DATA_BUCKET, region_name=AWS_REGION)
kinesis_helper = KinesisClient(KINESIS_STREAM_NAME, region_name=AWS_REGION)
event_gen = EventGenerator()

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

@app.route('/api/s3/parquet-files')
def list_parquet_files():
    """List available parquet files in S3"""
    try:
        files = s3_loader.list_parquet_files()
        return jsonify({
            'status': 'success',
            'files': files,
            'count': len(files)
        })
    except Exception as e:
        return jsonify({
            'status': 'error',
            'message': str(e)
        }), 500

@app.route('/api/events', methods=['POST'])
def submit_event():
    """Submit event to Kinesis stream"""
    try:
        data = request.get_json()
        event_type = data.get('type', 'synthetic')
        
        if event_type == 'synthetic':
            # Generate synthetic taxi trip data using event generator
            event_data = generate_synthetic_taxi_event(data.get('data', {}))
        else:
            # Load real trip from S3 parquet file
            s3_key = data.get('data', {}).get('s3_key')
            record_index = data.get('data', {}).get('record_index', 0)
            
            if not s3_key:
                return jsonify({
                    'status': 'error',
                    'message': 'S3 key is required for S3 data loading'
                }), 400
            
            # Load and transform the trip record
            event_data = s3_loader.load_and_transform_trip(s3_key, record_index)
        
        # Send to Kinesis using our helper
        response = kinesis_helper.send_event(event_data)
        
        return jsonify({
            'status': 'success',
            'message': 'Event submitted successfully',
            'event_id': response['SequenceNumber'],
            'shard_id': response['ShardId'],
            'event_type': event_type
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
                    'data': data,
                    'sequence_number': record['SequenceNumber']
                })
            except:
                pass
        
        return jsonify({'records': records})
        
    except Exception as e:
        return jsonify({'error': str(e), 'records': []}), 500

def generate_synthetic_taxi_event(params):
    """Generate synthetic taxi trip event in Kinesis format"""
    # Generate base event using event generator
    base_event = event_gen.generate_event('model_prediction')
    
    # Customize for taxi trip
    trip_duration = params.get('trip_duration', random.randint(5, 45))
    passenger_count = params.get('passenger_count', random.randint(1, 4))
    
    # Create taxi trip event
    taxi_event = {
        'event_id': f"taxi_trip_{datetime.now().timestamp()}",
        'event_type': 'taxi_trip_request',
        'timestamp': datetime.now().isoformat(),
        'data': {
            'pickup_datetime': datetime.now().isoformat(),
            'dropoff_datetime': (datetime.now().replace(minute=datetime.now().minute + trip_duration)).isoformat(),
            'pickup_location_id': str(random.randint(1, 265)),
            'dropoff_location_id': str(random.randint(1, 265)),
            'passenger_count': passenger_count,
            'trip_distance': round(trip_duration * 0.3, 2),  # Rough estimate
            'duration_minutes': trip_duration,
            'total_amount': round(trip_duration * 1.5 + 3.5, 2),  # Basic fare calculation
            'payment_type': random.choice([1, 2]),  # 1=Credit, 2=Cash
            'synthetic': True
        }
    }
    
    return taxi_event

@app.route('/api/data/validate', methods=['POST'])
def validate_data():
    """Validate a taxi trip record"""
    try:
        data = request.get_json()
        
        # Validate using S3 loader
        s3_loader.validate_kinesis_record(data)
        
        return jsonify({
            'status': 'success',
            'message': 'Data validation passed',
            'valid': True
        })
        
    except Exception as e:
        return jsonify({
            'status': 'error',
            'message': str(e),
            'valid': False
        }), 400

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
