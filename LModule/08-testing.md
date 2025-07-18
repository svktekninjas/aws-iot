# Module 8: Testing and Validation

## Overview
This module provides comprehensive testing procedures to validate that your IoT pipeline is working correctly, including unit tests, integration tests, and end-to-end validation.

## Testing Strategy

### Testing Pyramid
```
                    ┌─────────────────┐
                    │   E2E Tests     │  ← Full pipeline tests
                    │   (Few, Slow)   │
                    └─────────────────┘
                  ┌─────────────────────┐
                  │  Integration Tests  │  ← Service-to-service
                  │  (Some, Medium)     │
                  └─────────────────────┘
                ┌─────────────────────────┐
                │     Unit Tests          │  ← Component tests
                │   (Many, Fast)          │
                └─────────────────────────┘
```

### Test Categories
1. **Unit Tests**: Individual component testing
2. **Integration Tests**: Service interaction testing
3. **End-to-End Tests**: Full pipeline validation
4. **Performance Tests**: Load and stress testing
5. **Security Tests**: Permission and access validation

## Unit Testing

### 1. Lambda Function Testing

#### Test Setup
```python
# test_lambda_function.py
import pytest
import json
import base64
from unittest.mock import Mock, patch
from lambda_function import lambda_handler, get_secret

@pytest.fixture
def sample_event():
    return {
        'records': [
            {
                'recordId': '12345',
                'approximateArrivalTimestamp': 1642248600000,
                'data': base64.b64encode(json.dumps({
                    'device_id': 'test_device_001',
                    'timestamp': '2024-01-15T10:30:00Z',
                    'latitude': 37.7749,
                    'longitude': -122.4194,
                    'motion_detected': True,
                    'device_status': 'online'
                }).encode('utf-8')).decode('utf-8')
            }
        ]
    }
```

#### Test Database Connection
```python
@patch('lambda_function.pymysql.connect')
@patch('lambda_function.get_secret')
def test_database_connection(mock_get_secret, mock_connect, sample_event):
    # Mock secrets manager response
    mock_get_secret.return_value = {
        'mysql_host': 'localhost',
        'mysql_db_name': 'test_db',
        'mysql_db_user': 'test_user',
        'mysql_db_password': 'test_pass'
    }
    
    # Mock database connection
    mock_conn = Mock()
    mock_connect.return_value = mock_conn
    mock_cursor = Mock()
    mock_conn.cursor.return_value.__enter__.return_value = mock_cursor
    
    # Test lambda handler
    result = lambda_handler(sample_event, {})
    
    # Assertions
    assert len(result['records']) == 1
    assert result['records'][0]['result'] == 'Ok'
    mock_cursor.execute.assert_called_once()
    mock_conn.commit.assert_called_once()
```

#### Test Data Validation
```python
def test_invalid_json_handling():
    invalid_event = {
        'records': [
            {
                'recordId': '12345',
                'data': base64.b64encode(b'invalid json').decode('utf-8')
            }
        ]
    }
    
    with pytest.raises(json.JSONDecodeError):
        lambda_handler(invalid_event, {})
```

#### Run Unit Tests
```bash
# Install dependencies
pip install pytest pytest-mock

# Run tests
pytest test_lambda_function.py -v

# Run with coverage
pytest --cov=lambda_function test_lambda_function.py
```

### 2. Terraform Configuration Testing

#### Test Terraform Syntax
```bash
# Validate Terraform syntax
terraform validate

# Check formatting
terraform fmt -check

# Security scanning
tfsec .
```

#### Test Resource Configuration
```bash
# Plan without applying
terraform plan -out=tfplan

# Analyze plan
terraform show -json tfplan | jq '.planned_values'
```

## Integration Testing

### 1. Service-to-Service Testing

#### Test IoT Core to Firehose
```bash
# Publish test message to IoT topic
aws iot-data publish \
  --topic "/iot-o2-arena-motion" \
  --payload '{
    "device_id": "integration_test_001",
    "timestamp": "2024-01-15T10:30:00Z",
    "latitude": 37.7749,
    "longitude": -122.4194,
    "motion_detected": true,
    "device_status": "online"
  }'

# Wait for processing
sleep 10

# Check Firehose metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/Kinesis/Firehose \
  --metric-name DeliveryToS3.Records \
  --dimensions Name=DeliveryStreamName,Value=o2-arena-motion-stream \
  --start-time $(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum
```

#### Test Firehose to Lambda
```bash
# Check Lambda invocations
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Invocations \
  --dimensions Name=FunctionName,Value=o2-arena-iot-data-processor \
  --start-time $(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum

# Check for errors
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Errors \
  --dimensions Name=FunctionName,Value=o2-arena-iot-data-processor \
  --start-time $(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum
```

#### Test Lambda to Database
```bash
# Connect to database and verify data
mysql -h your-ec2-public-ip -u usr_iot_admin -p'dew4DL' -e "
SELECT * FROM db_iot_smart_buildings.tbl_smart_motion_model_x 
WHERE device_id = 'integration_test_001' 
ORDER BY ts DESC LIMIT 5;"
```

### 2. Database Integration Testing

#### Test Database Schema
```sql
-- Verify table structure
DESCRIBE tbl_smart_motion_model_x;

-- Test data insertion
INSERT INTO tbl_smart_motion_model_x 
(device_id, ts, latitude, longitude, motion_detected, device_status) 
VALUES ('test_device', NOW(), 37.7749, -122.4194, 1, 'online');

-- Verify insertion
SELECT * FROM tbl_smart_motion_model_x WHERE device_id = 'test_device';

-- Clean up test data
DELETE FROM tbl_smart_motion_model_x WHERE device_id = 'test_device';
```

#### Test Secrets Manager Integration
```bash
# Test secret retrieval
aws secretsmanager get-secret-value \
  --secret-id db_credentials_iot_project

# Test Lambda can access secret
aws lambda invoke \
  --function-name o2-arena-iot-data-processor \
  --payload '{"test": "secret_access"}' \
  --log-type Tail \
  response.json

# Check logs for secret access
aws logs filter-log-events \
  --log-group-name "/aws/lambda/o2-arena-iot-data-processor" \
  --filter-pattern "secret" \
  --start-time $(date -d '5 minutes ago' +%s)000
```

## End-to-End Testing

### 1. Full Pipeline Test

#### Test Script
```bash
#!/bin/bash
# e2e_test.sh

set -e

echo "Starting end-to-end pipeline test..."

# 1. Publish test message
TEST_DEVICE_ID="e2e_test_$(date +%s)"
echo "Publishing message for device: $TEST_DEVICE_ID"

aws iot-data publish \
  --topic "/iot-o2-arena-motion" \
  --payload "{
    \"device_id\": \"$TEST_DEVICE_ID\",
    \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
    \"latitude\": 37.7749,
    \"longitude\": -122.4194,
    \"motion_detected\": true,
    \"device_status\": \"online\"
  }"

# 2. Wait for processing
echo "Waiting for processing..."
sleep 120

# 3. Check database
echo "Checking database for record..."
RECORD_COUNT=$(mysql -h your-ec2-public-ip -u usr_iot_admin -p'dew4DL' -N -e "
SELECT COUNT(*) FROM db_iot_smart_buildings.tbl_smart_motion_model_x 
WHERE device_id = '$TEST_DEVICE_ID';")

if [ "$RECORD_COUNT" -eq "1" ]; then
    echo "✓ Database record found"
else
    echo "✗ Database record not found"
    exit 1
fi

# 4. Check S3
echo "Checking S3 for data..."
S3_OBJECTS=$(aws s3 ls s3://o2-arena-iot-data-bucket-*/o2-arena-motion/ --recursive | wc -l)

if [ "$S3_OBJECTS" -gt "0" ]; then
    echo "✓ S3 objects found"
else
    echo "✗ No S3 objects found"
    exit 1
fi

# 5. Clean up test data
echo "Cleaning up test data..."
mysql -h your-ec2-public-ip -u usr_iot_admin -p'dew4DL' -e "
DELETE FROM db_iot_smart_buildings.tbl_smart_motion_model_x 
WHERE device_id = '$TEST_DEVICE_ID';"

echo "✓ End-to-end test completed successfully!"
```

#### Run E2E Test
```bash
chmod +x e2e_test.sh
./e2e_test.sh
```

### 2. Data Validation Test

#### Validate Data Integrity
```python
# data_validation.py
import json
import gzip
import boto3
from datetime import datetime, timedelta

def validate_s3_data():
    s3_client = boto3.client('s3')
    bucket_name = 'o2-arena-iot-data-bucket-*'  # Replace with actual bucket
    
    # List recent objects
    response = s3_client.list_objects_v2(
        Bucket=bucket_name,
        Prefix='o2-arena-motion/',
        MaxKeys=10
    )
    
    if 'Contents' not in response:
        print("No objects found in S3")
        return False
    
    # Download and validate latest file
    latest_object = response['Contents'][0]
    print(f"Validating object: {latest_object['Key']}")
    
    # Download object
    obj = s3_client.get_object(Bucket=bucket_name, Key=latest_object['Key'])
    
    # Decompress if gzipped
    if latest_object['Key'].endswith('.gz'):
        content = gzip.decompress(obj['Body'].read()).decode('utf-8')
    else:
        content = obj['Body'].read().decode('utf-8')
    
    # Validate JSON records
    valid_records = 0
    total_records = 0
    
    for line in content.strip().split('\n'):
        if line.strip():
            total_records += 1
            try:
                record = json.loads(line)
                # Validate required fields
                required_fields = ['device_id', 'timestamp', 'motion_detected']
                if all(field in record for field in required_fields):
                    valid_records += 1
            except json.JSONDecodeError:
                print(f"Invalid JSON: {line}")
    
    print(f"Valid records: {valid_records}/{total_records}")
    return valid_records == total_records

if __name__ == '__main__':
    validate_s3_data()
```

## Performance Testing

### 1. Load Testing

#### Generate Load
```python
# load_test.py
import boto3
import json
import threading
import time
from datetime import datetime

def publish_message(device_id, count):
    iot_client = boto3.client('iot-data')
    
    for i in range(count):
        message = {
            'device_id': f'{device_id}_{i}',
            'timestamp': datetime.utcnow().isoformat() + 'Z',
            'latitude': 37.7749 + (i * 0.001),
            'longitude': -122.4194 + (i * 0.001),
            'motion_detected': i % 2 == 0,
            'device_status': 'online'
        }
        
        try:
            iot_client.publish(
                topic='/iot-o2-arena-motion',
                payload=json.dumps(message)
            )
            print(f"Published message {i} for device {device_id}")
            time.sleep(0.1)  # 10 messages per second per thread
        except Exception as e:
            print(f"Error publishing message: {e}")

def run_load_test():
    # Create 10 threads, each publishing 100 messages
    threads = []
    for i in range(10):
        thread = threading.Thread(
            target=publish_message,
            args=(f'load_test_device_{i}', 100)
        )
        threads.append(thread)
        thread.start()
    
    # Wait for all threads to complete
    for thread in threads:
        thread.join()
    
    print("Load test completed")

if __name__ == '__main__':
    run_load_test()
```

#### Monitor Performance
```bash
# Monitor Lambda performance
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Duration \
  --dimensions Name=FunctionName,Value=o2-arena-iot-data-processor \
  --start-time $(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average,Maximum

# Monitor Firehose performance
aws cloudwatch get-metric-statistics \
  --namespace AWS/Kinesis/Firehose \
  --metric-name DeliveryToS3.DataFreshness \
  --dimensions Name=DeliveryStreamName,Value=o2-arena-motion-stream \
  --start-time $(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average,Maximum
```

### 2. Stress Testing

#### Database Stress Test
```python
# db_stress_test.py
import pymysql
import threading
import time
import random

def stress_test_database(thread_id, iterations):
    connection = pymysql.connect(
        host='your-ec2-public-ip',
        user='usr_iot_admin',
        password='dew4DL',
        database='db_iot_smart_buildings'
    )
    
    for i in range(iterations):
        try:
            with connection.cursor() as cursor:
                cursor.execute("""
                    INSERT INTO tbl_smart_motion_model_x 
                    (device_id, ts, latitude, longitude, motion_detected, device_status) 
                    VALUES (%s, %s, %s, %s, %s, %s)
                """, (
                    f'stress_test_{thread_id}_{i}',
                    time.strftime('%Y-%m-%d %H:%M:%S'),
                    random.uniform(37.0, 38.0),
                    random.uniform(-123.0, -122.0),
                    random.choice([True, False]),
                    'online'
                ))
            connection.commit()
            print(f"Thread {thread_id}: Inserted record {i}")
        except Exception as e:
            print(f"Thread {thread_id}: Error inserting record {i}: {e}")
        
        time.sleep(0.01)  # 100 inserts per second per thread
    
    connection.close()

def run_stress_test():
    threads = []
    for i in range(5):  # 5 threads
        thread = threading.Thread(
            target=stress_test_database,
            args=(i, 200)  # 200 iterations per thread
        )
        threads.append(thread)
        thread.start()
    
    for thread in threads:
        thread.join()
    
    print("Stress test completed")

if __name__ == '__main__':
    run_stress_test()
```

## Security Testing

### 1. Permission Testing

#### Test IAM Permissions
```bash
# Test Lambda permissions
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::ACCOUNT:role/o2-arena-lambda-execution-role \
  --action-names secretsmanager:GetSecretValue \
  --resource-arns arn:aws:secretsmanager:us-west-1:ACCOUNT:secret:db_credentials_iot_project-*

# Test Firehose permissions
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::ACCOUNT:role/o2-arena-firehose-delivery-role \
  --action-names s3:PutObject \
  --resource-arns arn:aws:s3:::o2-arena-iot-data-bucket-*/o2-arena-motion/*

# Test IoT rule permissions
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::ACCOUNT:role/o2-arena-iot-rule-role \
  --action-names firehose:PutRecord \
  --resource-arns arn:aws:firehose:us-west-1:ACCOUNT:deliverystream/o2-arena-motion-stream
```

### 2. Network Security Testing

#### Test Encryption
```bash
# Check S3 encryption
aws s3api get-bucket-encryption \
  --bucket o2-arena-iot-data-bucket-*

# Check Lambda environment variables encryption
aws lambda get-function-configuration \
  --function-name o2-arena-iot-data-processor \
  --query 'KMSKeyArn'
```

#### Test Access Controls
```bash
# Test S3 public access
aws s3api get-public-access-block \
  --bucket o2-arena-iot-data-bucket-*

# Test unauthorized access
aws s3 ls s3://o2-arena-iot-data-bucket-*/ --profile unauthorized-profile
```

## Monitoring and Alerting Testing

### 1. CloudWatch Alarms

#### Create Test Alarms
```bash
# Create Lambda error alarm
aws cloudwatch put-metric-alarm \
  --alarm-name "Lambda-Errors-o2-arena-iot-data-processor" \
  --alarm-description "Alert when Lambda function has errors" \
  --metric-name Errors \
  --namespace AWS/Lambda \
  --statistic Sum \
  --period 300 \
  --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --dimensions Name=FunctionName,Value=o2-arena-iot-data-processor \
  --evaluation-periods 1

# Create Firehose delivery failure alarm
aws cloudwatch put-metric-alarm \
  --alarm-name "Firehose-Delivery-Failures" \
  --alarm-description "Alert when Firehose delivery fails" \
  --metric-name DeliveryToS3.Success \
  --namespace AWS/Kinesis/Firehose \
  --statistic Average \
  --period 300 \
  --threshold 0.95 \
  --comparison-operator LessThanThreshold \
  --dimensions Name=DeliveryStreamName,Value=o2-arena-motion-stream \
  --evaluation-periods 2
```

### 2. Log Analysis

#### Test Log Aggregation
```bash
# Check Lambda logs
aws logs describe-log-groups \
  --log-group-name-prefix "/aws/lambda/o2-arena-iot-data-processor"

# Check IoT rule logs
aws logs describe-log-groups \
  --log-group-name-prefix "/aws/iot/rules"

# Search for error patterns
aws logs filter-log-events \
  --log-group-name "/aws/lambda/o2-arena-iot-data-processor" \
  --filter-pattern "ERROR" \
  --start-time $(date -d '1 hour ago' +%s)000
```

## Test Automation

### 1. CI/CD Pipeline Testing

#### GitHub Actions Workflow
```yaml
# .github/workflows/test.yml
name: IoT Pipeline Tests

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v2
    
    - name: Setup Python
      uses: actions/setup-python@v2
      with:
        python-version: 3.9
    
    - name: Install dependencies
      run: |
        pip install pytest pytest-mock boto3 pymysql
    
    - name: Run unit tests
      run: |
        pytest test_lambda_function.py -v
    
    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v1
      with:
        terraform_version: 1.12.2
    
    - name: Terraform validate
      run: |
        terraform init
        terraform validate
    
    - name: Run integration tests
      env:
        AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
        AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
      run: |
        ./e2e_test.sh
```

### 2. Test Results Reporting

#### Generate Test Report
```python
# generate_test_report.py
import json
import boto3
from datetime import datetime, timedelta

def generate_test_report():
    cloudwatch = boto3.client('cloudwatch')
    
    # Get metrics for last 24 hours
    end_time = datetime.utcnow()
    start_time = end_time - timedelta(days=1)
    
    report = {
        'timestamp': end_time.isoformat(),
        'metrics': {}
    }
    
    # Lambda metrics
    lambda_metrics = cloudwatch.get_metric_statistics(
        Namespace='AWS/Lambda',
        MetricName='Invocations',
        Dimensions=[
            {'Name': 'FunctionName', 'Value': 'o2-arena-iot-data-processor'}
        ],
        StartTime=start_time,
        EndTime=end_time,
        Period=3600,
        Statistics=['Sum']
    )
    
    report['metrics']['lambda_invocations'] = sum(
        point['Sum'] for point in lambda_metrics['Datapoints']
    )
    
    # Firehose metrics
    firehose_metrics = cloudwatch.get_metric_statistics(
        Namespace='AWS/Kinesis/Firehose',
        MetricName='DeliveryToS3.Records',
        Dimensions=[
            {'Name': 'DeliveryStreamName', 'Value': 'o2-arena-motion-stream'}
        ],
        StartTime=start_time,
        EndTime=end_time,
        Period=3600,
        Statistics=['Sum']
    )
    
    report['metrics']['firehose_records'] = sum(
        point['Sum'] for point in firehose_metrics['Datapoints']
    )
    
    # Save report
    with open('test_report.json', 'w') as f:
        json.dump(report, f, indent=2)
    
    print("Test report generated: test_report.json")

if __name__ == '__main__':
    generate_test_report()
```

## Troubleshooting Guide

### Common Issues and Solutions

#### 1. Lambda Function Errors
```bash
# Check Lambda logs
aws logs filter-log-events \
  --log-group-name "/aws/lambda/o2-arena-iot-data-processor" \
  --filter-pattern "ERROR" \
  --start-time $(date -d '1 hour ago' +%s)000

# Common fixes:
# - Check database connectivity
# - Verify Secrets Manager permissions
# - Check memory and timeout settings
```

#### 2. Firehose Delivery Failures
```bash
# Check Firehose errors
aws logs filter-log-events \
  --log-group-name "/aws/kinesis/firehose/o2-arena-motion-stream" \
  --filter-pattern "ERROR" \
  --start-time $(date -d '1 hour ago' +%s)000

# Common fixes:
# - Verify S3 bucket permissions
# - Check Lambda function configuration
# - Verify IAM roles
```

#### 3. IoT Rule Not Triggering
```bash
# Check IoT rule status
aws iot get-topic-rule --rule-name O2ArenaMotionRule

# Test topic publishing
aws iot-data publish \
  --topic "/iot-o2-arena-motion" \
  --payload '{"test": true}'

# Common fixes:
# - Verify topic name matches rule
# - Check rule SQL syntax
# - Verify IoT rule IAM permissions
```

## Conclusion

This comprehensive testing module ensures your IoT pipeline is robust, secure, and performant. Regular testing helps maintain system reliability and catch issues before they impact production workloads.

### Testing Checklist
- [ ] Unit tests for Lambda function
- [ ] Integration tests for service connectivity
- [ ] End-to-end pipeline validation
- [ ] Performance and load testing
- [ ] Security and permission testing
- [ ] Monitoring and alerting validation
- [ ] Error handling and recovery testing
- [ ] Data integrity validation

Continue monitoring your pipeline and adjust testing strategies based on actual usage patterns and requirements.