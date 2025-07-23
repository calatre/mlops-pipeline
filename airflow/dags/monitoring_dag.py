from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator, BranchPythonOperator
from airflow.operators.bash import BashOperator
from airflow.operators.email import EmailOperator
from airflow.providers.amazon.aws.sensors.s3 import S3KeySensor
import boto3
import pandas as pd
import json
import numpy as np
from typing import Dict, Any
import os
from evidently import ColumnMapping
from evidently.report import Report
from evidently.metric_preset import DataDriftPreset, RegressionPreset
from evidently.test_suite import TestSuite
from evidently.tests import TestDataDrift, TestShareOfMissingValues

default_args = {
    'owner': 'mlops-team',
    'depends_on_past': False,
    'start_date': datetime(2023, 7, 1),  # Start from July 2023 (data date) 
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

dag = DAG(
    'taxi_model_monitoring',
    default_args=default_args,
    description='Monitor data quality and model performance',
    schedule_interval='@daily',  # Run daily monitoring
    catchup=True,  # Enable catchup for testing with different dates
    tags=['mlops', 'monitoring', 'taxi'],
)

def get_data_date_from_context(**context):
    """Get the data date from Airflow execution context"""
    execution_date = context['execution_date']
    
    # Calculate data file date (execution date minus 2 years for reproducibility)
    data_date = execution_date - timedelta(days=730)  # Approximately 2 years
    year = data_date.year
    month = data_date.month
    
    print(f"Execution date: {execution_date.strftime('%Y-%m-%d')}")
    print(f"Data file date: {year}-{month:02d}")
    
    return year, month, execution_date

def check_data_quality(**context):
    """Check data quality metrics based on mlops-zoomcamp-andre monitoring"""
    s3_client = boto3.client('s3')
    cloudwatch = boto3.client('cloudwatch')
    
    # Get data date from execution context
    year, month, execution_date = get_data_date_from_context(**context)
    
    bucket = os.environ.get('DATA_STORAGE_BUCKET', 'mlops-taxi-prediction-data-storage-dev')
    key = f'raw-data/yellow_tripdata_{year}-{month:02d}.parquet'
    
    try:
        # Check if data file exists
        s3_client.head_object(Bucket=bucket, Key=key)
        
        # Download and analyze data
        temp_file = '/tmp/monitoring_data.parquet'
        s3_client.download_file(bucket, key, temp_file)
        df = pd.read_parquet(temp_file)
        
        # Data quality checks based on chapter 05 monitoring
        quality_metrics = {
            'total_records': len(df),
            'null_pickup_locations': df['PULocationID'].isnull().sum(),
            'null_dropoff_locations': df['DOLocationID'].isnull().sum(),
            'null_trip_distance': df['trip_distance'].isnull().sum(),
            'zero_trip_distance': (df['trip_distance'] == 0).sum(),
            'negative_trip_distance': (df['trip_distance'] < 0).sum(),
            'mean_trip_distance': df['trip_distance'].mean(),
            'std_trip_distance': df['trip_distance'].std(),
        }
        
        # Calculate duration for quality checks
        df['duration'] = df['tpep_dropoff_datetime'] - df['tpep_pickup_datetime']
        df['duration_minutes'] = df.duration.apply(lambda td: td.total_seconds() / 60)
        
        quality_metrics.update({
            'mean_duration': df['duration_minutes'].mean(),
            'std_duration': df['duration_minutes'].std(),
            'outlier_duration_short': (df['duration_minutes'] < 1).sum(),
            'outlier_duration_long': (df['duration_minutes'] > 60).sum(),
            'data_completeness_score': (1 - (quality_metrics['null_pickup_locations'] + 
                                            quality_metrics['null_dropoff_locations'] + 
                                            quality_metrics['null_trip_distance']) / (len(df) * 3)) * 100
        })
        
        # Send metrics to CloudWatch
        for metric_name, value in quality_metrics.items():
            if not np.isnan(value):  # Skip NaN values
                cloudwatch.put_metric_data(
                    Namespace='TaxiMLOps/DataQuality',
                    MetricData=[
                        {
                            'MetricName': metric_name,
                            'Value': float(value),
                            'Unit': 'Count' if 'count' in metric_name or 'records' in metric_name else 'None',
                            'Dimensions': [
                                {
                                    'Name': 'DataDate',
                                    'Value': f'{year}-{month:02d}'
                                }
                            ]
                        }
                    ]
                )
        
        # Save quality report to S3
        quality_report = {
            'execution_date': execution_date.isoformat(),
            'data_date': f'{year}-{month:02d}',
            'quality_metrics': quality_metrics,
            'quality_checks': {
                'data_completeness_passed': quality_metrics['data_completeness_score'] > 95,
                'outlier_percentage_acceptable': (quality_metrics['outlier_duration_short'] + 
                                                quality_metrics['outlier_duration_long']) / len(df) < 0.1,
                'no_negative_distances': quality_metrics['negative_trip_distance'] == 0
            }
        }
        
        # Upload quality report
        report_key = f'monitoring/data-quality/{year}-{month:02d}/{execution_date.strftime("%Y-%m-%d")}.json'
        with open('/tmp/quality_report.json', 'w') as f:
            json.dump(quality_report, f, indent=2, default=str)
        
        s3_client.upload_file('/tmp/quality_report.json', bucket, report_key)
        
        # Clean up
        os.remove(temp_file)
        os.remove('/tmp/quality_report.json')
        
        print(f"Data quality check completed for {year}-{month:02d}")
        print(f"Quality score: {quality_metrics['data_completeness_score']:.2f}%")
        
        return f"Data quality monitored for {year}-{month:02d}. Quality score: {quality_metrics['data_completeness_score']:.2f}%"
        
    except Exception as e:
        print(f"Data quality check failed: {e}")
        
        # Log failure to CloudWatch
        cloudwatch.put_metric_data(
            Namespace='TaxiMLOps/DataQuality',
            MetricData=[
                {
                    'MetricName': 'data_quality_check_failed',
                    'Value': 1,
                    'Unit': 'Count',
                    'Dimensions': [
                        {
                            'Name': 'DataDate',
                            'Value': f'{year}-{month:02d}'
                        }
                    ]
                }
            ]
        )
        raise

def check_model_performance(**context):
    """Monitor model performance and detect drift"""
    s3_client = boto3.client('s3')
    cloudwatch = boto3.client('cloudwatch')
    
    # Get data date from execution context
    year, month, execution_date = get_data_date_from_context(**context)
    
    bucket = os.environ.get('DATA_STORAGE_BUCKET', 'mlops-taxi-prediction-data-storage-dev')
    
    try:
        # Check if we have a trained model for this data date
        model_key = f'models/{year}-{month:02d}/model.pkl'
        
        try:
            s3_client.head_object(Bucket=bucket, Key=model_key)
            model_exists = True
        except:
            model_exists = False
            print(f"No model found for {year}-{month:02d}, skipping performance monitoring")
            return f"Model performance monitoring skipped - no model for {year}-{month:02d}"
        
        if model_exists:
            # Download validation data (we can reuse the preprocessed data)
            preprocessed_key = f'models/{year}-{month:02d}/preprocessed_data.pkl'
            
            try:
                s3_client.download_file(bucket, preprocessed_key, '/tmp/preprocessed_data.pkl')
                
                import pickle
                with open('/tmp/preprocessed_data.pkl', 'rb') as f:
                    data = pickle.load(f)
                
                val_dicts = data['val_dicts']
                y_val = data['y_val']
                
                # Download model and vectorizer
                s3_client.download_file(bucket, model_key, '/tmp/model.pkl')
                s3_client.download_file(bucket, f'models/{year}-{month:02d}/dv.pkl', '/tmp/dv.pkl')
                
                with open('/tmp/model.pkl', 'rb') as f:
                    model = pickle.load(f)
                
                with open('/tmp/dv.pkl', 'rb') as f:
                    dv = pickle.load(f)
                
                # Make predictions
                X_val = dv.transform(val_dicts)
                y_pred = model.predict(X_val)
                
                # Calculate performance metrics
                from sklearn.metrics import mean_squared_error, mean_absolute_error, r2_score
                
                performance_metrics = {
                    'rmse': mean_squared_error(y_val, y_pred, squared=False),
                    'mae': mean_absolute_error(y_val, y_pred),
                    'r2_score': r2_score(y_val, y_pred),
                    'prediction_mean': np.mean(y_pred),
                    'prediction_std': np.std(y_pred),
                    'actual_mean': np.mean(y_val),
                    'actual_std': np.std(y_val)
                }
                
                # Send metrics to CloudWatch
                for metric_name, value in performance_metrics.items():
                    cloudwatch.put_metric_data(
                        Namespace='TaxiMLOps/ModelPerformance',
                        MetricData=[
                            {
                                'MetricName': metric_name,
                                'Value': float(value),
                                'Unit': 'None',
                                'Dimensions': [
                                    {
                                        'Name': 'ModelDataDate',
                                        'Value': f'{year}-{month:02d}'
                                    }
                                ]
                            }
                        ]
                    )
                
                # Save performance report
                performance_report = {
                    'execution_date': execution_date.isoformat(),
                    'model_data_date': f'{year}-{month:02d}',
                    'performance_metrics': performance_metrics,
                    'validation_samples': len(val_dicts)
                }
                
                report_key = f'monitoring/model-performance/{year}-{month:02d}/{execution_date.strftime("%Y-%m-%d")}.json'
                with open('/tmp/performance_report.json', 'w') as f:
                    json.dump(performance_report, f, indent=2, default=str)
                
                s3_client.upload_file('/tmp/performance_report.json', bucket, report_key)
                
                # Clean up
                os.remove('/tmp/preprocessed_data.pkl')
                os.remove('/tmp/model.pkl')
                os.remove('/tmp/dv.pkl')
                os.remove('/tmp/performance_report.json')
                
                print(f"Model performance monitored for {year}-{month:02d}")
                print(f"RMSE: {performance_metrics['rmse']:.4f}, R2: {performance_metrics['r2_score']:.4f}")
                
                return f"Model performance monitored for {year}-{month:02d}. RMSE: {performance_metrics['rmse']:.4f}"
                
            except Exception as e:
                print(f"Error loading model or data: {e}")
                raise
                
    except Exception as e:
        print(f"Model performance monitoring failed: {e}")
        
        # Log failure to CloudWatch  
        cloudwatch.put_metric_data(
            Namespace='TaxiMLOps/ModelPerformance',
            MetricData=[
                {
                    'MetricName': 'performance_monitoring_failed',
                    'Value': 1,
                    'Unit': 'Count',
                    'Dimensions': [
                        {
                            'Name': 'ModelDataDate',
                            'Value': f'{year}-{month:02d}'
                        }
                    ]
                }
            ]
        )
        raise

def check_lambda_health(**context):
    """Check Lambda function health and invocation metrics"""
    cloudwatch = boto3.client('cloudwatch')
    lambda_client = boto3.client('lambda')
    
    # Get data date from execution context  
    year, month, execution_date = get_data_date_from_context(**context)
    
    function_name = os.environ.get('LAMBDA_FUNCTION_NAME', 'taxi-ride-duration-prediction')
    
    try:
        # Get Lambda function configuration
        response = lambda_client.get_function(FunctionName=function_name)
        
        # Check if function is active
        function_status = response['Configuration']['State']
        
        # Get CloudWatch metrics for Lambda function
        end_time = execution_date
        start_time = end_time - timedelta(hours=24)  # Last 24 hours
        
        # Query invocation metrics
        invocations_response = cloudwatch.get_metric_statistics(
            Namespace='AWS/Lambda',
            MetricName='Invocations',
            Dimensions=[
                {
                    'Name': 'FunctionName',
                    'Value': function_name
                }
            ],
            StartTime=start_time,
            EndTime=end_time,
            Period=3600,  # 1 hour periods
            Statistics=['Sum']
        )
        
        # Query error metrics
        errors_response = cloudwatch.get_metric_statistics(
            Namespace='AWS/Lambda',
            MetricName='Errors', 
            Dimensions=[
                {
                    'Name': 'FunctionName',
                    'Value': function_name
                }
            ],
            StartTime=start_time,
            EndTime=end_time,
            Period=3600,
            Statistics=['Sum']
        )
        
        total_invocations = sum([point['Sum'] for point in invocations_response['Datapoints']])
        total_errors = sum([point['Sum'] for point in errors_response['Datapoints']])
        
        error_rate = (total_errors / total_invocations * 100) if total_invocations > 0 else 0
        
        # Create health report
        health_report = {
            'execution_date': execution_date.isoformat(),
            'function_name': function_name,
            'function_status': function_status,
            'total_invocations_24h': total_invocations,
            'total_errors_24h': total_errors,
            'error_rate_percentage': error_rate,
            'health_status': 'healthy' if function_status == 'Active' and error_rate < 5 else 'unhealthy'
        }
        
        # Send custom metrics to CloudWatch
        cloudwatch.put_metric_data(
            Namespace='TaxiMLOps/LambdaHealth',
            MetricData=[
                {
                    'MetricName': 'error_rate_percentage',
                    'Value': error_rate,
                    'Unit': 'Percent',
                    'Dimensions': [
                        {
                            'Name': 'FunctionName',
                            'Value': function_name
                        }
                    ]
                },
                {
                    'MetricName': 'health_check_passed',
                    'Value': 1 if health_report['health_status'] == 'healthy' else 0,
                    'Unit': 'Count',
                    'Dimensions': [
                        {
                            'Name': 'FunctionName',
                            'Value': function_name
                        }
                    ]
                }
            ]
        )
        
        # Save health report
        s3_client = boto3.client('s3')
        bucket = os.environ.get('DATA_STORAGE_BUCKET', 'mlops-taxi-prediction-data-storage-dev')
        report_key = f'monitoring/lambda-health/{execution_date.strftime("%Y-%m-%d")}.json'
        
        with open('/tmp/health_report.json', 'w') as f:
            json.dump(health_report, f, indent=2, default=str)
        
        s3_client.upload_file('/tmp/health_report.json', bucket, report_key)
        os.remove('/tmp/health_report.json')
        
        print(f"Lambda health check completed. Status: {health_report['health_status']}")
        print(f"Error rate: {error_rate:.2f}%, Invocations: {total_invocations}")
        
        return f"Lambda health monitored. Status: {health_report['health_status']}, Error rate: {error_rate:.2f}%"
        
    except Exception as e:
        print(f"Lambda health check failed: {e}")
        raise

def get_monitoring_data(**context):
    """Fetch reference and current data for drift monitoring"""
    s3_client = boto3.client('s3')
    
    # Get data date from execution context
    year, month, execution_date = get_data_date_from_context(**context)
    
    bucket = os.environ.get('DATA_STORAGE_BUCKET', 'mlops-taxi-prediction-data-storage-dev')
    
    try:
        # Get reference data (training data from the model)
        reference_key = f'models/{year}-{month:02d}/preprocessed_data.pkl'
        
        try:
            s3_client.download_file(bucket, reference_key, '/tmp/reference_data.pkl')
            
            import pickle
            with open('/tmp/reference_data.pkl', 'rb') as f:
                reference_data = pickle.load(f)
            
            # Convert reference data to DataFrame
            reference_df = pd.DataFrame(reference_data['val_dicts'])
            reference_df['target'] = reference_data['y_val']
            
        except Exception as e:
            print(f"Could not load reference data: {e}")
            # Use current data as reference if no model data available
            raw_key = f'raw-data/yellow_tripdata_{year}-{month:02d}.parquet'
            s3_client.download_file(bucket, raw_key, '/tmp/raw_data.parquet')
            df = pd.read_parquet('/tmp/raw_data.parquet')
            
            # Apply same preprocessing
            df['duration'] = df['tpep_dropoff_datetime'] - df['tpep_pickup_datetime']
            df['duration'] = df.duration.apply(lambda td: td.total_seconds() / 60)
            df = df[(df.duration >= 1) & (df.duration <= 60)]
            
            categorical = ['PULocationID', 'DOLocationID']
            df[categorical] = df[categorical].astype(str)
            
            features = ['PULocationID', 'DOLocationID', 'trip_distance']
            reference_df = df[features + ['duration']].rename(columns={'duration': 'target'})
            
            os.remove('/tmp/raw_data.parquet')
        
        # Get current data (prediction logs from last 24 hours)
        current_data_list = []
        
        # Look for prediction logs from the last 24 hours
        for hours_back in range(24):
            log_date = execution_date - timedelta(hours=hours_back)
            date_str = log_date.strftime('%Y/%m/%d')
            
            try:
                # List prediction files for this date
                paginator = s3_client.get_paginator('list_objects_v2')
                pages = paginator.paginate(Bucket=bucket, Prefix=f'predictions/{date_str}/')
                
                for page in pages:
                    if 'Contents' in page:
                        for obj in page['Contents']:
                            try:
                                response = s3_client.get_object(Bucket=bucket, Key=obj['Key'])
                                prediction_log = json.loads(response['Body'].read())
                                
                                # Extract features and add to current data
                                features_data = prediction_log['features']
                                features_data['predicted_duration'] = prediction_log['predicted_duration']
                                current_data_list.append(features_data)
                                
                            except Exception as e:
                                print(f"Error reading prediction log {obj['Key']}: {e}")
                                continue
                                
            except Exception as e:
                print(f"No prediction logs found for {date_str}: {e}")
                continue
        
        if current_data_list:
            current_df = pd.DataFrame(current_data_list)
            current_df = current_df.rename(columns={'predicted_duration': 'target'})
        else:
            print("No current prediction data found, using reference data as current")
            current_df = reference_df.copy()
        
        # Save data for drift monitoring
        reference_df.to_pickle('/tmp/reference_data_drift.pkl')
        current_df.to_pickle('/tmp/current_data_drift.pkl')
        
        # Clean up
        if os.path.exists('/tmp/reference_data.pkl'):
            os.remove('/tmp/reference_data.pkl')
        
        print(f"Reference data: {len(reference_df)} samples")
        print(f"Current data: {len(current_df)} samples")
        
        return f"Monitoring data prepared: {len(reference_df)} reference, {len(current_df)} current samples"
        
    except Exception as e:
        print(f"Error getting monitoring data: {e}")
        raise

def run_drift_check(**context):
    """Run Evidently drift check and decide next action"""
    try:
        # Load monitoring data
        reference_df = pd.read_pickle('/tmp/reference_data_drift.pkl')
        current_df = pd.read_pickle('/tmp/current_data_drift.pkl')
        
        # Define column mapping
        column_mapping = ColumnMapping(
            target='target',
            numerical_features=['trip_distance'],
            categorical_features=['PULocationID', 'DOLocationID']
        )
        
        # Create test suite
        test_suite = TestSuite(tests=[
            TestDataDrift(),
            TestShareOfMissingValues()
        ])
        
        # Run tests
        test_suite.run(reference_data=reference_df, current_data=current_df, column_mapping=column_mapping)
        
        # Get test results
        test_results = test_suite.as_dict()
        
        # Check if all tests passed
        all_passed = test_results['summary']['all_passed']
        
        # Save test results
        with open('/tmp/drift_test_results.json', 'w') as f:
            json.dump(test_results, f, indent=2, default=str)
        
        # Upload results to S3
        s3_client = boto3.client('s3')
        bucket = os.environ.get('DATA_STORAGE_BUCKET', 'mlops-taxi-prediction-data-storage-dev')
        
        year, month, execution_date = get_data_date_from_context(**context)
        results_key = f'monitoring/drift-results/{execution_date.strftime("%Y-%m-%d")}.json'
        s3_client.upload_file('/tmp/drift_test_results.json', bucket, results_key)
        
        os.remove('/tmp/drift_test_results.json')
        
        print(f"Drift check completed. All tests passed: {all_passed}")
        
        # Branch based on results
        if all_passed:
            return 'end_task'  # No drift detected
        else:
            return 'trigger_alert'  # Drift detected
            
    except Exception as e:
        print(f"Error running drift check: {e}")
        raise

def generate_drift_report(**context):
    """Generate Evidently drift report"""
    try:
        # Load monitoring data
        reference_df = pd.read_pickle('/tmp/reference_data_drift.pkl')
        current_df = pd.read_pickle('/tmp/current_data_drift.pkl')
        
        # Define column mapping
        column_mapping = ColumnMapping(
            target='target',
            numerical_features=['trip_distance'], 
            categorical_features=['PULocationID', 'DOLocationID']
        )
        
        # Create report
        report = Report(metrics=[
            DataDriftPreset(),
            RegressionPreset()
        ])
        
        # Run report
        report.run(reference_data=reference_df, current_data=current_df, column_mapping=column_mapping)
        
        # Save HTML report
        report.save_html('/tmp/drift_report.html')
        
        # Upload to S3
        s3_client = boto3.client('s3')
        bucket = os.environ.get('MONITORING_REPORTS_BUCKET', 'mlops-taxi-prediction-monitoring-reports-dev')
        
        year, month, execution_date = get_data_date_from_context(**context)
        report_key = f'drift-reports/{execution_date.strftime("%Y-%m-%d")}.html'
        s3_client.upload_file('/tmp/drift_report.html', bucket, report_key)
        
        # Clean up data files
        os.remove('/tmp/reference_data_drift.pkl')
        os.remove('/tmp/current_data_drift.pkl')
        os.remove('/tmp/drift_report.html')
        
        print(f"Drift report generated and uploaded to s3://{bucket}/{report_key}")
        
        return f"Drift report generated: s3://{bucket}/{report_key}"
        
    except Exception as e:
        print(f"Error generating drift report: {e}")
        raise

def trigger_alert(**context):
    """Trigger alert when drift is detected"""
    print("DATA DRIFT DETECTED! Alert should be triggered.")
    # In a real implementation, this would send an email, Slack message, etc.
    return "Drift alert triggered"

def end_task(**context):
    """End task when no drift is detected"""
    print("No drift detected. Monitoring completed successfully.")
    return "Monitoring completed - no drift"

# Define tasks
data_quality_task = PythonOperator(
    task_id='check_data_quality',
    python_callable=check_data_quality,
    dag=dag,
)

model_performance_task = PythonOperator(
    task_id='check_model_performance',
    python_callable=check_model_performance,
    dag=dag,
)

lambda_health_task = PythonOperator(
    task_id='check_lambda_health',
    python_callable=check_lambda_health,
    dag=dag,
)

get_monitoring_data_task = PythonOperator(
    task_id='get_monitoring_data',
    python_callable=get_monitoring_data,
    dag=dag,
)

run_drift_check_task = BranchPythonOperator(
    task_id='run_drift_check',
    python_callable=run_drift_check,
    dag=dag,
)

generate_drift_report_task = PythonOperator(
    task_id='generate_drift_report',
    python_callable=generate_drift_report,
    dag=dag,
)

trigger_alert_task = PythonOperator(
    task_id='trigger_alert',
    python_callable=trigger_alert,
    dag=dag,
)

end_task_operator = PythonOperator(
    task_id='end_task',
    python_callable=end_task,
    dag=dag,
)

# Set task dependencies
# Basic monitoring tasks can run in parallel
[data_quality_task, model_performance_task, lambda_health_task]

# Drift monitoring workflow
get_monitoring_data_task >> run_drift_check_task
get_monitoring_data_task >> generate_drift_report_task  # Runs in parallel with drift check
run_drift_check_task >> [trigger_alert_task, end_task_operator]
