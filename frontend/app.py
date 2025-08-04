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
import logging
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

# Initialize logger
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize our utilities
s3_loader = S3DataLoader(DATA_BUCKET, region_name=AWS_REGION)
kinesis_helper = KinesisClient(KINESIS_STREAM_NAME, region_name=AWS_REGION)
event_gen = EventGenerator()

@app.route('/')
def index():
    """Render the main dashboard"""
    # Get orchestration IP from environment variable
    orchestration_ip = os.environ.get('ORCHESTRATION_IP', 'localhost')
    
    return render_template('index.html', 
                         current_time=datetime.now().strftime('%H:%M:%S'),
                         orchestration_ip=orchestration_ip)

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

@app.route('/api/files', methods=['GET'])
def list_files():
    """List files available in S3 bucket"""
    try:
        files = s3_loader.list_objects()
        return jsonify({'status': 'success', 'files': files}), 200
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/api/data/download', methods=['POST'])
def download_data():
    """Download and process data from S3"""
    try:
        data = request.get_json()
        s3_key = data.get('s3_key')
        download_type = data.get('type', 'parquet')  # parquet, json, or text
        sample_size = data.get('sample_size', None)
        
        if not s3_key:
            return jsonify({'status': 'error', 'message': 'S3 key required'}), 400

        logger.info(f"Download triggered for {s3_key} (type: {download_type})")
        
        # Download based on type
        if download_type == 'parquet':
            df = s3_loader.read_parquet_file(s3_key, sample_size)
            result = {
                'status': 'success',
                'message': f'Downloaded parquet file: {s3_key}',
                'rows': len(df),
                'columns': list(df.columns),
                'sample_data': df.head(5).to_dict('records') if len(df) > 0 else []
            }
        elif download_type == 'json':
            json_data = s3_loader.load_json_data(s3_key)
            result = {
                'status': 'success',
                'message': f'Downloaded JSON file: {s3_key}',
                'data': json_data
            }
        elif download_type == 'text':
            text_data = s3_loader.load_text_data(s3_key)
            result = {
                'status': 'success',
                'message': f'Downloaded text file: {s3_key}',
                'content': text_data[:1000] + '...' if len(text_data) > 1000 else text_data,
                'full_length': len(text_data)
            }
        else:
            return jsonify({'status': 'error', 'message': 'Unsupported download type'}), 400
        
        return jsonify(result), 200
        
    except Exception as e:
        logger.error(f"Error downloading data: {str(e)}")
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/api/events/batch', methods=['POST'])
def submit_batch_events():
    """Submit multiple events to Kinesis stream"""
    try:
        data = request.get_json()
        batch_size = data.get('batch_size', 10)
        event_type = data.get('type', 'synthetic')
        
        logger.info(f"Generating batch of {batch_size} events of type {event_type}")
        
        events = []
        if event_type == 'synthetic':
            # Generate synthetic events
            for i in range(batch_size):
                event_data = generate_synthetic_taxi_event(data.get('data', {}))
                events.append(event_data)
        else:
            # Load from S3 parquet - multiple records
            s3_key = data.get('data', {}).get('s3_key')
            start_index = data.get('data', {}).get('start_index', 0)
            
            if not s3_key:
                return jsonify({
                    'status': 'error',
                    'message': 'S3 key is required for S3 data loading'
                }), 400
            
            for i in range(batch_size):
                try:
                    event_data = s3_loader.load_and_transform_trip(s3_key, start_index + i)
                    events.append(event_data)
                except Exception as e:
                    logger.warning(f"Could not load record {start_index + i}: {str(e)}")
                    break
        
        # Send batch to Kinesis
        response = kinesis_helper.send_batch_events(events)
        
        success_count = len([r for r in response.get('Records', []) if 'SequenceNumber' in r])
        failed_count = response.get('FailedRecordCount', 0)
        
        return jsonify({
            'status': 'success',
            'message': f'Batch submitted: {success_count} successful, {failed_count} failed',
            'events_sent': success_count,
            'events_failed': failed_count,
            'total_requested': len(events)
        }), 201
        
    except Exception as e:
        logger.error(f"Error submitting batch events: {str(e)}")
        return jsonify({
            'status': 'error',
            'message': str(e)
        }), 500

@app.route('/api/events/control', methods=['POST'])
def control_events():
    """Control the event generation process"""
    try:
        data = request.get_json()
        action = data.get('action')
        params = data.get('params', {})
        
        if action == 'start_automated':
            # Start automated continuous event generation
            interval = params.get('interval_seconds', 60)
            event_count = params.get('events_per_interval', 5)
            duration = params.get('duration_minutes', 10)
            
            logger.info(f"Starting automated event generation: {event_count} events every {interval}s for {duration} minutes")
            
            # In a real implementation, this would start a background task
            # For now, we'll just log the configuration
            result = {
                'status': 'success',
                'message': 'Automated event generation configured',
                'config': {
                    'interval_seconds': interval,
                    'events_per_interval': event_count,
                    'duration_minutes': duration,
                    'total_events_planned': (duration * 60 // interval) * event_count
                }
            }
            
        elif action == 'stop_automated':
            logger.info("Stopping automated event generation")
            result = {'status': 'success', 'message': 'Automated event generation stopped'}
            
        elif action == 'generate_historical':
            # Generate historical events for testing
            days_back = params.get('days_back', 7)
            events_per_day = params.get('events_per_day', 100)
            
            logger.info(f"Generating historical events: {events_per_day} events per day for {days_back} days")
            
            historical_events = event_gen.generate_historical_events(days_back, events_per_day)
            
            # Send historical events in batches
            batch_size = 25
            total_sent = 0
            for i in range(0, len(historical_events), batch_size):
                batch = historical_events[i:i + batch_size]
                kinesis_helper.send_batch_events(batch)
                total_sent += len(batch)
            
            result = {
                'status': 'success',
                'message': f'Historical events generated and sent',
                'events_generated': len(historical_events),
                'events_sent': total_sent
            }
            
        else:
            return jsonify({'status': 'error', 'message': 'Invalid action. Use: start_automated, stop_automated, or generate_historical'}), 400

        return jsonify(result), 200
        
    except Exception as e:
        logger.error(f"Error controlling events: {str(e)}")
        return jsonify({'status': 'error', 'message': str(e)}), 500

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
