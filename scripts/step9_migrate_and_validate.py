#!/usr/bin/env python3
"""
Step 9: Infrastructure Migration and Validation
Personal MLOps Learning Project - NYC Taxi Trip Duration Prediction

This script handles the transition from Docker Compose to AWS RDS-backed ECS services.
NO traditional data migration - NYC taxi data is publicly available.

Focus Areas:
1. RDS database initialization (Airflow metadata, MLflow tracking)
2. Application connectivity validation 
3. Infrastructure readiness verification
4. End-to-end pipeline testing

Author: Personal Learning Project
Date: 2025-07-24
"""

import os
import sys
import time
import boto3
import psycopg2
import requests
import json
from datetime import datetime
from typing import Dict, List, Optional, Tuple

class MLOpsInfrastructureMigrator:
    """
    Handles infrastructure migration from local Docker Compose to AWS RDS-backed ECS.
    Designed for personal learning with clear, pedagogical approach.
    """
    
    def __init__(self):
        """Initialize migrator with AWS and database connections."""
        self.setup_aws_clients()
        self.setup_database_config()
        self.setup_validation_config()
        
    def setup_aws_clients(self):
        """Initialize AWS service clients."""
        try:
            self.region = os.environ.get('AWS_DEFAULT_REGION', 'eu-north-1')
            self.s3_client = boto3.client('s3', region_name=self.region)
            self.rds_client = boto3.client('rds', region_name=self.region)
            self.ecs_client = boto3.client('ecs', region_name=self.region)
            print("✅ AWS clients initialized successfully")
        except Exception as e:
            print(f"❌ Failed to initialize AWS clients: {e}")
            sys.exit(1)
    
    def setup_database_config(self):
        """Setup database connection parameters."""
        self.db_config = {
            'host': os.environ.get('RDS_ENDPOINT'),
            'port': int(os.environ.get('RDS_PORT', '5432')),
            'username': os.environ.get('DB_USERNAME', 'airflow'),
            'password': os.environ.get('DB_PASSWORD'),
            'region': self.region
        }
        
        # Validate required environment variables
        if not all([self.db_config['host'], self.db_config['password']]):
            print("❌ Missing required environment variables: RDS_ENDPOINT, DB_PASSWORD")
            sys.exit(1)
    
    def setup_validation_config(self):
        """Setup validation and testing configuration."""
        self.project_config = {
            'project_name': os.environ.get('PROJECT_NAME', 'mlops-taxi-prediction'),
            'environment': os.environ.get('ENVIRONMENT', 'dev'),
            'data_bucket': os.environ.get('DATA_STORAGE_BUCKET'),
            'mlflow_bucket': os.environ.get('MLFLOW_BUCKET_NAME'),
            'kinesis_stream': os.environ.get('KINESIS_STREAM_NAME', 'taxi-ride-predictions-stream')
        }
    
    def print_step_header(self, step_number: int, title: str):
        """Print formatted step header for clarity."""
        print(f"\n{'='*60}")
        print(f"STEP {step_number}: {title.upper()}")
        print('='*60)
    
    def check_prerequisites(self) -> bool:
        """
        Check all prerequisites before starting migration.
        Educational: Shows what needs to be in place before migration.
        """
        self.print_step_header(1, "Prerequisites Check")
        
        checks = {}
        
        # AWS Connectivity
        try:
            self.s3_client.list_buckets()
            checks['aws_connectivity'] = True
            print("✅ AWS connectivity confirmed")
        except Exception as e:
            checks['aws_connectivity'] = False
            print(f"❌ AWS connectivity failed: {e}")
        
        # Environment Variables
        required_vars = ['RDS_ENDPOINT', 'DB_PASSWORD', 'AWS_DEFAULT_REGION']
        missing_vars = [var for var in required_vars if not os.environ.get(var)]
        
        if missing_vars:
            checks['environment_vars'] = False
            print(f"❌ Missing environment variables: {missing_vars}")
        else:
            checks['environment_vars'] = True
            print("✅ Required environment variables present")
        
        # S3 Buckets (should exist from infrastructure deployment)
        bucket_checks = {}
        for bucket_type in ['data_bucket', 'mlflow_bucket']:
            bucket_name = self.project_config[bucket_type]
            if bucket_name:
                try:
                    self.s3_client.head_bucket(Bucket=bucket_name)
                    bucket_checks[bucket_type] = True
                    print(f"✅ S3 bucket {bucket_name} accessible")
                except Exception as e:
                    bucket_checks[bucket_type] = False
                    print(f"⚠️  S3 bucket {bucket_name} not accessible: {e}")
            else:
                bucket_checks[bucket_type] = False
                print(f"⚠️  {bucket_type} not configured")
        
        checks['s3_buckets'] = all(bucket_checks.values())
        
        all_checks_passed = all(checks.values())
        
        if all_checks_passed:
            print("\n🎉 All prerequisites satisfied! Ready for migration.")
        else:
            print("\n⚠️  Some prerequisites not met. Please fix before continuing.")
            
        return all_checks_passed
    
    def validate_rds_connectivity(self) -> bool:
        """
        Test RDS PostgreSQL connectivity and basic functionality.
        Educational: Shows how to validate database connections.
        """
        self.print_step_header(2, "RDS Connectivity Validation")
        
        try:
            # Test basic connection
            conn = psycopg2.connect(
                host=self.db_config['host'],
                port=self.db_config['port'],
                database='postgres',  # Default database
                user=self.db_config['username'],
                password=self.db_config['password'],
                connect_timeout=10
            )
            
            with conn.cursor() as cursor:
                # Test basic queries
                cursor.execute("SELECT version();")
                version = cursor.fetchone()[0]
                print(f"✅ PostgreSQL version: {version[:50]}...")
                
                cursor.execute("SELECT current_database(), current_user;")
                db_info = cursor.fetchone()
                print(f"✅ Connected to database: {db_info[0]} as user: {db_info[1]}")
                
                # Check available databases
                cursor.execute("SELECT datname FROM pg_database WHERE datistemplate = false;")
                databases = [row[0] for row in cursor.fetchall()]
                print(f"✅ Available databases: {databases}")
            
            conn.close()
            print("✅ RDS connectivity validation passed")
            return True
            
        except Exception as e:
            print(f"❌ RDS connectivity validation failed: {e}")
            return False
    
    def initialize_application_databases(self) -> Dict[str, bool]:
        """
        Initialize Airflow and MLflow databases.
        Educational: Shows database setup for each application.
        """
        self.print_step_header(3, "Application Database Initialization")
        
        results = {}
        
        # Database configurations
        databases = {
            'airflow': {
                'name': 'airflow',
                'description': 'Airflow metadata database'
            },
            'mlflow': {
                'name': 'mlflow', 
                'description': 'MLflow experiment tracking database'
            }
        }
        
        try:
            # Connect to PostgreSQL server
            conn = psycopg2.connect(
                host=self.db_config['host'],
                port=self.db_config['port'],
                database='postgres',
                user=self.db_config['username'],
                password=self.db_config['password']
            )
            conn.autocommit = True
            
            with conn.cursor() as cursor:
                for db_key, db_info in databases.items():
                    try:
                        # Check if database exists
                        cursor.execute(
                            "SELECT 1 FROM pg_database WHERE datname = %s",
                            (db_info['name'],)
                        )
                        
                        if cursor.fetchone():
                            print(f"✅ Database '{db_info['name']}' already exists")
                        else:
                            # Create database
                            cursor.execute(f"CREATE DATABASE {db_info['name']}")
                            print(f"✅ Created database '{db_info['name']}' for {db_info['description']}")
                        
                        # Test connection to the specific database
                        test_conn = psycopg2.connect(
                            host=self.db_config['host'],
                            port=self.db_config['port'],
                            database=db_info['name'],
                            user=self.db_config['username'],
                            password=self.db_config['password']
                        )
                        
                        with test_conn.cursor() as test_cursor:
                            test_cursor.execute("SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public'")
                            table_count = test_cursor.fetchone()[0]
                            print(f"✅ Database '{db_info['name']}' accessible ({table_count} tables)")
                        
                        test_conn.close()
                        results[db_key] = True
                        
                    except Exception as e:
                        print(f"❌ Failed to initialize {db_info['name']} database: {e}")
                        results[db_key] = False
            
            conn.close()
            
        except Exception as e:
            print(f"❌ Database initialization failed: {e}")
            results = {db: False for db in databases.keys()}
        
        success_count = sum(results.values())
        total_count = len(results)
        print(f"\n📊 Database initialization summary: {success_count}/{total_count} successful")
        
        return results
    
    def validate_s3_data_pipeline(self) -> bool:
        """
        Validate S3 data storage and pipeline readiness.
        Educational: Shows how to verify data infrastructure.
        """
        self.print_step_header(4, "S3 Data Pipeline Validation")
        
        if not self.project_config['data_bucket']:
            print("⚠️  Data storage bucket not configured")
            return False
        
        try:
            bucket_name = self.project_config['data_bucket']
            
            # Check bucket accessibility
            self.s3_client.head_bucket(Bucket=bucket_name)
            print(f"✅ Data bucket '{bucket_name}' accessible")
            
            # List objects in raw-data prefix
            response = self.s3_client.list_objects_v2(
                Bucket=bucket_name,
                Prefix='raw-data/',
                MaxKeys=10
            )
            
            if 'Contents' in response:
                file_count = len(response['Contents'])
                print(f"✅ Found {file_count} files in raw-data/ prefix")
                
                # Show sample files
                for obj in response['Contents'][:3]:
                    size_mb = obj['Size'] / (1024 * 1024)
                    print(f"   - {obj['Key']} ({size_mb:.1f} MB, {obj['LastModified']})")
            else:
                print("ℹ️  No data files found in raw-data/ prefix (expected for new setup)")
            
            # Test write capability with a small test file
            test_key = f"test-data/migration-test-{int(time.time())}.json"
            test_data = {
                'test': True,
                'timestamp': datetime.now().isoformat(),
                'step': 'step9_migration_validation'
            }
            
            self.s3_client.put_object(
                Bucket=bucket_name,
                Key=test_key,
                Body=json.dumps(test_data),
                ContentType='application/json'
            )
            print(f"✅ S3 write test successful: {test_key}")
            
            # Clean up test file
            self.s3_client.delete_object(Bucket=bucket_name, Key=test_key)
            print("✅ Test cleanup completed")
            
            return True
            
        except Exception as e:
            print(f"❌ S3 data pipeline validation failed: {e}")
            return False
    
    def test_infrastructure_readiness(self) -> Dict[str, bool]:
        """
        Test overall infrastructure readiness for ECS deployment.
        Educational: Shows how to validate complete infrastructure.
        """
        self.print_step_header(5, "Infrastructure Readiness Assessment")
        
        checks = {}
        
        # ECS Cluster check
        try:
            cluster_name = f"{self.project_config['project_name']}-cluster-{self.project_config['environment']}"
            response = self.ecs_client.describe_clusters(clusters=[cluster_name])
            
            if response['clusters']:
                cluster = response['clusters'][0]
                print(f"✅ ECS cluster '{cluster_name}' exists")
                print(f"   - Status: {cluster['status']}")
                print(f"   - Active services: {cluster['activeServicesCount']}")
                print(f"   - Running tasks: {cluster['runningTasksCount']}")
                checks['ecs_cluster'] = True
            else:
                print(f"❌ ECS cluster '{cluster_name}' not found")
                checks['ecs_cluster'] = False
                
        except Exception as e:
            print(f"❌ ECS cluster check failed: {e}")
            checks['ecs_cluster'] = False
        
        # RDS instance check
        try:
            db_identifier = f"{self.project_config['project_name']}-airflow-db-{self.project_config['environment']}"
            response = self.rds_client.describe_db_instances(DBInstanceIdentifier=db_identifier)
            
            if response['DBInstances']:
                db_instance = response['DBInstances'][0]
                print(f"✅ RDS instance '{db_identifier}' exists")
                print(f"   - Status: {db_instance['DBInstanceStatus']}")
                print(f"   - Engine: {db_instance['Engine']} {db_instance['EngineVersion']}")
                print(f"   - Instance class: {db_instance['DBInstanceClass']}")
                checks['rds_instance'] = db_instance['DBInstanceStatus'] == 'available'
            else:
                print(f"❌ RDS instance '{db_identifier}' not found")
                checks['rds_instance'] = False
                
        except Exception as e:
            print(f"❌ RDS instance check failed: {e}")
            checks['rds_instance'] = False
        
        # Kinesis stream check
        try:
            stream_name = self.project_config['kinesis_stream']
            response = boto3.client('kinesis', region_name=self.region).describe_stream(
                StreamName=stream_name
            )
            
            stream_info = response['StreamDescription']
            print(f"✅ Kinesis stream '{stream_name}' exists")
            print(f"   - Status: {stream_info['StreamStatus']}")
            print(f"   - Shards: {len(stream_info['Shards'])}")
            checks['kinesis_stream'] = stream_info['StreamStatus'] == 'ACTIVE'
            
        except Exception as e:
            print(f"❌ Kinesis stream check failed: {e}")
            checks['kinesis_stream'] = False
        
        # Summary
        passed_checks = sum(checks.values())
        total_checks = len(checks)
        print(f"\n📊 Infrastructure readiness: {passed_checks}/{total_checks} components ready")
        
        return checks
    
    def simulate_application_migration_test(self) -> bool:
        """
        Simulate application migration by testing database connections with app-like queries.
        Educational: Shows what applications will do in the new environment.
        """
        self.print_step_header(6, "Application Migration Simulation")
        
        try:
            # Test Airflow-like operations
            print("🔄 Testing Airflow database operations...")
            airflow_conn = psycopg2.connect(
                host=self.db_config['host'],
                port=self.db_config['port'],
                database='airflow',
                user=self.db_config['username'],
                password=self.db_config['password']
            )
            
            with airflow_conn.cursor() as cursor:
                # Create a test table (simulating Airflow metadata)
                cursor.execute("""
                    CREATE TABLE IF NOT EXISTS migration_test (
                        id SERIAL PRIMARY KEY,
                        test_name VARCHAR(100),
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                    )
                """)
                
                # Insert test data
                cursor.execute(
                    "INSERT INTO migration_test (test_name) VALUES (%s)",
                    ('step9_migration_validation',)
                )
                
                # Query test data
                cursor.execute("SELECT COUNT(*) FROM migration_test")
                count = cursor.fetchone()[0]
                print(f"✅ Airflow database operations successful (test records: {count})")
                
                # Cleanup
                cursor.execute("DROP TABLE migration_test")
                
            airflow_conn.commit()
            airflow_conn.close()
            
            # Test MLflow-like operations
            print("🔄 Testing MLflow database operations...")
            mlflow_conn = psycopg2.connect(
                host=self.db_config['host'],
                port=self.db_config['port'],
                database='mlflow',
                user=self.db_config['username'],
                password=self.db_config['password']
            )
            
            with mlflow_conn.cursor() as cursor:
                # Test MLflow-like schema operations
                cursor.execute("""
                    CREATE TABLE IF NOT EXISTS experiment_test (
                        experiment_id SERIAL PRIMARY KEY,
                        name VARCHAR(255),
                        lifecycle_stage VARCHAR(32)
                    )
                """)
                
                cursor.execute(
                    "INSERT INTO experiment_test (name, lifecycle_stage) VALUES (%s, %s)",
                    ('step9_test_experiment', 'active')
                )
                
                cursor.execute("SELECT COUNT(*) FROM experiment_test")
                count = cursor.fetchone()[0]
                print(f"✅ MLflow database operations successful (test experiments: {count})")
                
                # Cleanup
                cursor.execute("DROP TABLE experiment_test")
                
            mlflow_conn.commit()
            mlflow_conn.close()
            
            print("✅ Application migration simulation completed successfully")
            return True
            
        except Exception as e:
            print(f"❌ Application migration simulation failed: {e}")
            return False
    
    def generate_migration_report(self, results: Dict[str, any]) -> None:
        """
        Generate comprehensive migration report.
        Educational: Shows how to document migration results.
        """
        self.print_step_header(7, "Migration Report Generation")
        
        # Calculate overall success rate
        all_results = []
        for result in results.values():
            if isinstance(result, bool):
                all_results.append(result)
            elif isinstance(result, dict):
                all_results.extend(result.values())
        
        success_rate = (sum(all_results) / len(all_results)) * 100 if all_results else 0
        
        print(f"""
📋 STEP 9 MIGRATION REPORT
{'='*50}

🎯 Overall Success Rate: {success_rate:.1f}%

📊 Component Status:
""")
        
        for component, result in results.items():
            if isinstance(result, bool):
                status = "✅ PASS" if result else "❌ FAIL"
                print(f"   {component}: {status}")
            elif isinstance(result, dict):
                passed = sum(result.values())
                total = len(result)
                status = f"✅ {passed}/{total}" if passed == total else f"⚠️  {passed}/{total}"
                print(f"   {component}: {status}")
        
        print(f"""
🎓 Learning Outcomes:
   • Infrastructure migration concepts understood
   • Database initialization procedures validated
   • AWS service integration tested
   • Application connectivity patterns verified

🚀 Next Steps:
   1. Deploy ECS services (Airflow + MLflow)
   2. Run initial data setup: python scripts/data_setup.py
   3. Test complete pipeline with real data
   4. Set up monitoring and alerting

💡 Educational Notes:
   • No traditional data migration needed - taxi data is public
   • Focus on application infrastructure transition
   • RDS replaces local PostgreSQL for metadata/tracking
   • S3 handles all data storage requirements

📚 Personal Learning Project Status:
   {'🎉 READY FOR ECS DEPLOYMENT' if success_rate >= 80 else '⚠️  NEEDS ATTENTION BEFORE DEPLOYMENT'}
""")
        
        # Save report to file
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        report_file = f"step9_migration_report_{timestamp}.txt"
        
        with open(report_file, 'w') as f:
            f.write(f"Step 9 Migration Report - {datetime.now().isoformat()}\n")
            f.write("="*60 + "\n")
            f.write(f"Overall Success Rate: {success_rate:.1f}%\n\n")
            
            for component, result in results.items():
                f.write(f"{component}: {result}\n")
        
        print(f"📄 Report saved to: {report_file}")

def main():
    """
    Main execution function for Step 9 migration and validation.
    Educational approach with clear progress tracking.
    """
    print("🚀 Starting Step 9: Infrastructure Migration and Validation")
    print("📚 Personal MLOps Learning Project")
    print("🎯 Focus: Docker Compose → AWS RDS-backed ECS transition")
    print("-" * 60)
    
    migrator = MLOpsInfrastructureMigrator()
    
    # Store results for final report
    results = {}
    
    # Execute migration steps
    results['prerequisites'] = migrator.check_prerequisites()
    if not results['prerequisites']:
        print("\n❌ Prerequisites not met. Please fix environment setup.")
        return 1
    
    results['rds_connectivity'] = migrator.validate_rds_connectivity()
    results['database_initialization'] = migrator.initialize_application_databases()
    results['s3_validation'] = migrator.validate_s3_data_pipeline()
    results['infrastructure_readiness'] = migrator.test_infrastructure_readiness()
    results['application_simulation'] = migrator.simulate_application_migration_test()
    
    # Generate comprehensive report
    migrator.generate_migration_report(results)
    
    # Determine exit code
    critical_checks = [
        results['prerequisites'],
        results['rds_connectivity'], 
        results['s3_validation']
    ]
    
    if all(critical_checks):
        print("\n🎉 Step 9 migration validation completed successfully!")
        return 0
    else:
        print("\n⚠️  Step 9 migration validation completed with issues.")
        return 1

if __name__ == "__main__":
    exit_code = main()
    sys.exit(exit_code)
