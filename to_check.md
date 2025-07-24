# Common Issues & Quick Fixes

**Learning project troubleshooting guide** - Simple solutions for common problems.

> 💡 **Remember**: This is a learning project. If something breaks, it's a learning opportunity!

## ⚠️ Critical Failure Points

### 1. **AWS Permissions and IAM Roles**
**Risk Level**: 🔴 High  
**Impact**: Complete pipeline failure  
**Probability**: Medium  

**Failure Scenarios**:
- Incorrectly configured IAM roles limiting access to AWS resources
- Lambda function unable to read from S3 buckets
- Airflow DAGs failing with permission errors
- Kinesis stream access denied

**Symptoms**:
```
AccessDenied: User: arn:aws:sts::123456789012:assumed-role/lambda-role/function-name is not authorized to perform: s3:GetObject on resource: arn:aws:s3:::bucket-name/models/latest/combined_model.pkl
```

**Detection Methods**:
```bash
# Check IAM roles are correctly applied
aws iam get-role --role-name mlops-taxi-prediction-lambda-role-dev

# Test S3 access
aws s3 ls s3://your-data-bucket/ --region us-east-1

# Check CloudWatch logs for permission errors
aws logs describe-log-groups --log-group-name-prefix "/aws/lambda"
```

**Mitigation Strategies**:
1. **Pre-deployment Validation**:
   ```bash
   # Validate Terraform plan before apply
   terraform plan -detailed-exitcode
   
   # Use AWS CLI to verify permissions
   aws iam simulate-principal-policy \
     --policy-source-arn arn:aws:iam::ACCOUNT:role/lambda-role \
     --action-names s3:GetObject \
     --resource-arns arn:aws:s3:::bucket-name/*
   ```

2. **Monitoring**:
   - Set up CloudWatch alarms for AccessDenied errors
   - Monitor Lambda error rates and duration spikes
   - Regular permission audits

3. **Quick Fix**:
   ```bash
   # Re-apply Terraform with proper permissions
   terraform apply -auto-approve
   
   # Force Lambda function update
   aws lambda update-function-configuration \
     --function-name taxi-trip-duration-predictor \
     --environment Variables='{MODEL_UPDATED_AT=2024-01-01T00:00:00Z}'
   ```

### 2. **Lambda Function Resource Limits**
**Risk Level**: 🟡 Medium  
**Impact**: Prediction failures, timeouts  
**Probability**: High during model loading  

**Failure Scenarios**:
- Insufficient memory for model loading (XGBoost + DictVectorizer)
- Timeout during S3 operations or model inference
- Cold start performance issues
- Concurrent execution limits reached

**Symptoms**:
```
Task timed out after 30.00 seconds
Runtime.OutOfMemoryError: Lambda function ran out of memory
```

**Detection Methods**:
```bash
# Monitor Lambda metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Duration \
  --dimensions Name=FunctionName,Value=taxi-trip-duration-predictor \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-01T23:59:59Z \
  --period 3600 \
  --statistics Average,Maximum

# Check memory utilization
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name MemoryUtilization \
  --dimensions Name=FunctionName,Value=taxi-trip-duration-predictor
```

**Mitigation Strategies**:
1. **Resource Optimization**:
   ```hcl
   # In variables.tf - increase resources if needed
   variable "lambda_memory_size" {
     default = 512  # Increase from 256MB
   }
   
   variable "lambda_timeout" {
     default = 60   # Increase from 30s
   }
   ```

2. **Code Optimization**:
   ```python
   # Implement model caching and lazy loading
   import functools
   
   @functools.lru_cache(maxsize=1)
   def load_model_cached():
       # Load model only once and cache
       return load_model()
   ```

3. **Monitoring and Alerting**:
   ```bash
   # Set up CloudWatch alarms
   aws cloudwatch put-metric-alarm \
     --alarm-name "Lambda-High-Duration" \
     --alarm-description "Lambda execution time too high" \
     --metric-name Duration \
     --namespace AWS/Lambda \
     --statistic Average \
     --period 300 \
     --threshold 25000 \
     --comparison-operator GreaterThanThreshold
   ```

### 3. **Data Quality and Pipeline Dependencies**
**Risk Level**: 🟡 Medium  
**Impact**: Model performance degradation, training failures  
**Probability**: Medium  

**Failure Scenarios**:
- Corrupted or missing parquet files from NYC TLC
- Invalid data formats or schema changes
- Network issues during data download
- Insufficient data for training (empty months)

**Symptoms**:
```python
FileNotFoundError: Training data not available for 2023-12
ValueError: Input contains NaN, infinity or a value too large
```

**Detection Methods**:
```python
# Enhanced data validation in data_setup.py
def validate_data_quality(df):
    checks = {
        'required_columns': all(col in df.columns for col in ['PULocationID', 'DOLocationID', 'trip_distance']),
        'data_completeness': df['trip_distance'].notna().sum() > 0.95 * len(df),
        'location_validity': df['PULocationID'].between(1, 265).all(),
        'distance_validity': (df['trip_distance'] >= 0).all(),
        'sufficient_data': len(df) > 10000
    }
    
    failed_checks = [check for check, passed in checks.items() if not passed]
    if failed_checks:
        raise ValueError(f"Data quality checks failed: {failed_checks}")
    
    return checks
```

**Mitigation Strategies**:
1. **Robust Data Pipeline**:
   ```python
   # Add retry logic and fallback data sources
   def download_with_retry(url, max_retries=3):
       for attempt in range(max_retries):
           try:
               return pd.read_parquet(url)
           except Exception as e:
               if attempt == max_retries - 1:
                   # Try alternative data source or previous month
                   return load_fallback_data()
               time.sleep(2 ** attempt)
   ```

2. **Data Quality Monitoring**:
   ```python
   # Implement data quality metrics
   def calculate_data_quality_score(df):
       completeness = df.notna().mean().mean()
       validity = (df['trip_distance'] > 0).mean()
       consistency = (df['duration'] > 0).mean()
       
       return {
           'completeness_score': completeness,
           'validity_score': validity,
           'consistency_score': consistency,
           'overall_score': (completeness + validity + consistency) / 3
       }
   ```

### 4. **Model Drift and Performance Degradation**
**Risk Level**: 🟡 Medium  
**Impact**: Poor prediction accuracy, business impact  
**Probability**: Medium to High over time  

**Failure Scenarios**:
- Significant changes in taxi usage patterns
- Seasonal variations not captured in training data
- External factors (COVID, events, construction)
- Gradual model decay without detection

**Symptoms**:
- Increasing RMSE values over time
- Drift reports showing significant distribution changes
- Business metrics showing prediction accuracy decline

**Detection Methods**:
```python
# Evidently AI drift detection
from evidently.test_suite import TestSuite
from evidently.tests import TestDataDrift

def detect_drift(reference_data, current_data):
    test_suite = TestSuite(tests=[
        TestDataDrift()
    ])
    
    test_suite.run(reference_data=reference_data, current_data=current_data)
    results = test_suite.as_dict()
    
    return results['summary']['all_passed']
```

**Mitigation Strategies**:
1. **Automated Monitoring**:
   - Daily drift reports via Evidently AI
   - Performance threshold alerts
   - Automated retraining triggers

2. **Model Versioning and Rollback**:
   ```python
   # MLflow model promotion with performance validation
   def promote_model_if_better(new_model_rmse, production_model_rmse):
       if new_model_rmse < production_model_rmse * 0.95:  # 5% improvement threshold
           client = MlflowClient()
           client.transition_model_version_stage(
               name="taxi-duration-model",
               version=new_version,
               stage="Production"
           )
   ```

### 5. **Kinesis Stream and Lambda Integration**
**Risk Level**: 🟡 Medium  
**Impact**: Lost events, processing delays  
**Probability**: Low  

**Failure Scenarios**:
- Kinesis shard capacity exceeded
- Lambda concurrent execution limits
- Event source mapping failures
- Dead letter queue overflow

**Detection Methods**:
```bash
# Monitor Kinesis metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/Kinesis \
  --metric-name IncomingRecords \
  --dimensions Name=StreamName,Value=taxi-ride-predictions-stream

# Check Lambda invocation metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Invocations \
  --dimensions Name=FunctionName,Value=taxi-trip-duration-predictor
```

**Mitigation Strategies**:
1. **Scaling Configuration**:
   ```hcl
   # Adjust Kinesis shards based on load
   variable "kinesis_shard_count" {
     default = 2  # Increase if needed
   }
   
   # Configure Lambda reserved concurrency
   resource "aws_lambda_function" "taxi_predictor" {
     reserved_concurrent_executions = 10
   }
   ```

2. **Error Handling**:
   ```python
   # Implement dead letter queue processing
   def lambda_handler(event, context):
       failed_records = []
       
       for record in event['Records']:
           try:
               process_record(record)
           except Exception as e:
               failed_records.append({
                   'record': record,
                   'error': str(e)
               })
       
       if failed_records:
           # Send to DLQ for retry
           send_to_dlq(failed_records)
   ```

## 🟢 Lower Risk Failure Points

### 6. **Docker Resource Constraints**
**Risk Level**: 🟢 Low  
**Impact**: Local development issues  
**Probability**: Medium on resource-constrained systems  

**Mitigation**:
- Document minimum system requirements
- Provide resource optimization guides
- Alternative lightweight development setups

### 7. **Environment Configuration**
**Risk Level**: 🟢 Low  
**Impact**: Service startup failures  
**Probability**: High during initial setup  

**Mitigation**:
- Comprehensive .env.example file
- Validation scripts for environment setup
- Clear error messages for missing variables

### 8. **Network Connectivity Issues**
**Risk Level**: 🟢 Low  
**Impact**: External service dependencies  
**Probability**: Low  

**Mitigation**:
- Retry mechanisms for external calls
- Fallback data sources
- Offline development capabilities

## 🔧 Monitoring and Alerting Strategy

### Key Metrics Dashboard

```python
# CloudWatch custom metrics for comprehensive monitoring
CRITICAL_METRICS = {
    'lambda_errors': 'AWS/Lambda/Errors',
    'lambda_duration': 'AWS/Lambda/Duration',
    'kinesis_incoming_records': 'AWS/Kinesis/IncomingRecords',
    'model_performance': 'TaxiMLOps/ModelPerformance/rmse',
    'data_quality_score': 'TaxiMLOps/DataQuality/data_completeness_score'
}

# Alert thresholds
ALERT_THRESHOLDS = {
    'lambda_error_rate': 0.05,      # 5% error rate
    'lambda_duration': 25000,       # 25 seconds
    'model_rmse': 15.0,            # RMSE threshold
    'data_quality': 0.90           # 90% completeness
}
```

### Automated Recovery Procedures

```bash
#!/bin/bash
# auto_recovery.sh - Automated recovery script

# Function to restart failed services
restart_failed_services() {
    echo "Checking service health..."
    
    # Check Airflow
    if ! curl -f http://localhost:8080/health; then
        echo "Restarting Airflow..."
        docker-compose restart airflow-webserver airflow-scheduler
    fi
    
    # Check MLflow
    if ! curl -f http://localhost:5000; then
        echo "Restarting MLflow..."
        docker-compose restart mlflow
    fi
}

# Function to validate AWS resources
validate_aws_resources() {
    echo "Validating AWS resources..."
    
    # Check Lambda function
    aws lambda get-function --function-name taxi-trip-duration-predictor > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "Lambda function issue detected. Re-applying Terraform..."
        cd infra && terraform apply -auto-approve
    fi
}

# Main recovery routine
main() {
    restart_failed_services
    validate_aws_resources
    
    echo "Recovery procedures completed."
}

main "$@"
```

## 📋 Regular Health Checks

### Daily Checks
- [ ] All services responding (Airflow, MLflow, Lambda)
- [ ] Recent data ingestion successful
- [ ] No critical errors in CloudWatch logs
- [ ] Model performance within acceptable range

### Weekly Checks
- [ ] Review Evidently drift reports
- [ ] Check training DAG success rate
- [ ] Validate model artifacts in S3
- [ ] Review AWS costs and resource utilization

### Monthly Checks
- [ ] Security audit of IAM roles
- [ ] Performance optimization review
- [ ] Dependency updates and patches
- [ ] Backup and disaster recovery testing

---

**Note**: This document should be reviewed and updated regularly as the system evolves. Set up automated reminders to review failure scenarios and update mitigation strategies based on real-world incidents.
