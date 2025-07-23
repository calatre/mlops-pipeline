import json
import base64
import pickle
import boto3
import os
import logging
from datetime import datetime

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Global variables for model caching
model = None
dict_vectorizer = None
s3_client = boto3.client('s3')

def load_model():
    """Load combined XGBoost model and vectorizer from S3"""
    global model, dict_vectorizer
    
    if model is not None and dict_vectorizer is not None:
        return model, dict_vectorizer
    
    try:
        # Use environment variables for S3 location
        model_bucket = os.environ.get('DATA_STORAGE_BUCKET', 'mlops-taxi-prediction-data-storage-dev')
        model_key = os.environ.get('MODEL_S3_KEY', 'models/latest/combined_model.pkl')
        
        logger.info(f"Loading model from s3://{model_bucket}/{model_key}")
        
        response = s3_client.get_object(Bucket=model_bucket, Key=model_key)
        model_data = pickle.loads(response['Body'].read())
        
        # Extract model and vectorizer from combined pickle
        model = model_data['model']
        dict_vectorizer = model_data['vectorizer']
            
        logger.info("XGBoost model and DictVectorizer loaded successfully")
        return model, dict_vectorizer
        
    except Exception as e:
        logger.error(f"Error loading model: {str(e)}")
        raise

def preprocess_ride(ride_data):
    """Preprocess ride data to match training features exactly"""
    # Use the same features as in training: PULocationID, DOLocationID, trip_distance
    features = {
        'PULocationID': str(ride_data.get('PULocationID', '1')),
        'DOLocationID': str(ride_data.get('DOLocationID', '1')),
        'trip_distance': float(ride_data.get('trip_distance', 1.0))
    }
    
    return features

def predict_duration(features, model, vectorizer):
    """Make prediction using the loaded model"""
    try:
        # Transform features using DictVectorizer (same as training)
        dicts = [features]  # Single record as list
        X = vectorizer.transform(dicts)
        
        prediction = model.predict(X)
        return float(prediction[0])
        
    except Exception as e:
        logger.error(f"Error making prediction: {str(e)}")
        return 15.0  # Default prediction

def log_prediction(ride_id, features, prediction):
    """Log prediction result to S3"""
    try:
        predictions_bucket = os.environ['PREDICTIONS_S3_BUCKET']
        
        log_entry = {
            'ride_id': ride_id,
            'timestamp': datetime.utcnow().isoformat(),
            'features': features,
            'predicted_duration': prediction
        }
        
        # Create S3 key with date partitioning
        date_str = datetime.utcnow().strftime('%Y/%m/%d')
        s3_key = f"predictions/{date_str}/{ride_id}.json"
        
        s3_client.put_object(
            Bucket=predictions_bucket,
            Key=s3_key,
            Body=json.dumps(log_entry),
            ContentType='application/json'
        )
        
        logger.info(f"Prediction logged to s3://{predictions_bucket}/{s3_key}")
        
    except Exception as e:
        logger.error(f"Error logging prediction: {str(e)}")

def lambda_handler(event, context):
    """Main Lambda handler function"""
    logger.info(f"Processing {len(event['Records'])} records")
    
    try:
        # Load model on cold start
        model, vectorizer = load_model()
        
        processed_count = 0
        
        # Process each Kinesis record
        for record in event['Records']:
            try:
                # Decode the base64 encoded data
                payload = base64.b64decode(record['kinesis']['data'])
                ride_data = json.loads(payload.decode('utf-8'))
                
                logger.info(f"Processing ride: {ride_data}")
                
                # Generate ride ID if not present
                ride_id = ride_data.get('ride_id', f"ride_{datetime.utcnow().strftime('%Y%m%d_%H%M%S_%f')}")
                
                # Preprocess features (same approach as training)
                features = preprocess_ride(ride_data)
                
                # Make prediction
                prediction = predict_duration(features, model, vectorizer)
                
                # Log the prediction
                log_prediction(ride_id, features, prediction)
                
                processed_count += 1
                logger.info(f"Processed ride {ride_id}: predicted duration = {prediction:.2f} minutes")
                
            except Exception as e:
                logger.error(f"Error processing record: {str(e)}")
                continue
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': f'Successfully processed {processed_count} records',
                'processed_count': processed_count
            })
        }
        
    except Exception as e:
        logger.error(f"Error in lambda handler: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e)
            })
        }
