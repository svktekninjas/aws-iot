# Module 9: Complete Pipeline Testing Guide

## Overview
This comprehensive guide walks you through testing your IoT pipeline from start to finish, including data preparation, base64 encoding, and step-by-step data insertion procedures.

## Table of Contents
1. [Understanding Data Flow](#understanding-data-flow)
2. [Preparing Test Data](#preparing-test-data)
3. [Base64 Encoding Process](#base64-encoding-process)
4. [Testing IoT Core Integration](#testing-iot-core-integration)
5. [Testing Firehose Processing](#testing-firehose-processing)
6. [Testing Lambda Function](#testing-lambda-function)
7. [Testing Database Integration](#testing-database-integration)
8. [Testing S3 Storage](#testing-s3-storage)
9. [End-to-End Pipeline Testing](#end-to-end-pipeline-testing)
10. [Monitoring and Verification](#monitoring-and-verification)

## Understanding Data Flow

### Pipeline Architecture
```
IoT Device → IoT Core → Firehose → Lambda → MySQL Database
              ↓           ↓         ↓
         CloudWatch    S3 Bucket  CloudWatch
```

### Data Transformation Points
1. **IoT Device**: Original JSON data
2. **IoT Core**: Forwards data to Firehose
3. **Firehose**: Base64 encodes data before sending to Lambda
4. **Lambda**: Decodes base64, processes, and stores in database
5. **S3**: Stores processed data for archival

## Preparing Test Data

### 1. Understanding the Data Schema

#### IoT Motion Sensor Data Structure
```json
{
  "device_id": "string",        // Unique device identifier
  "ts": "timestamp",            // ISO 8601 timestamp
  "latitude": "number",         // GPS latitude
  "longitude": "number",        // GPS longitude
  "motion_detected": "boolean", // Motion detection status
  "device_status": "string"     // Device operational status
}
```

#### Example Raw Data
```json
{
  "device_id": "motion_sensor_001",
  "ts": "2025-07-18T10:30:00Z",
  "latitude": 37.7749,
  "longitude": -122.4194,
  "motion_detected": true,
  "device_status": "online"
}
```

### 2. Creating Test Data Sets

#### Create Test Data Directory
```bash
mkdir test_data
cd test_data
```

#### Single Device Test Data
Create `single_device_test.json`:
```json
{
  "device_id": "test_device_001",
  "ts": "2025-07-18T10:30:00Z",
  "latitude": 37.7749,
  "longitude": -122.4194,
  "motion_detected": true,
  "device_status": "online"
}
```

#### Multiple Device Test Data
Create `multiple_devices_test.json`:
```json
[
  {
    "device_id": "motion_sensor_001",
    "ts": "2025-07-18T10:30:00Z",
    "latitude": 37.7749,
    "longitude": -122.4194,
    "motion_detected": true,
    "device_status": "online"
  },
  {
    "device_id": "motion_sensor_002",
    "ts": "2025-07-18T10:31:00Z",
    "latitude": 37.7849,
    "longitude": -122.4094,
    "motion_detected": false,
    "device_status": "online"
  },
  {
    "device_id": "motion_sensor_003",
    "ts": "2025-07-18T10:32:00Z",
    "latitude": 37.7949,
    "longitude": -122.3994,
    "motion_detected": true,
    "device_status": "maintenance"
  }
]
```

#### Invalid Data Test Cases
Create `invalid_data_tests.json`:
```json
[
  {
    "test_name": "missing_device_id",
    "data": {
      "ts": "2025-07-18T10:30:00Z",
      "latitude": 37.7749,
      "longitude": -122.4194,
      "motion_detected": true,
      "device_status": "online"
    }
  },
  {
    "test_name": "invalid_timestamp",
    "data": {
      "device_id": "test_device_001",
      "ts": "invalid-timestamp",
      "latitude": 37.7749,
      "longitude": -122.4194,
      "motion_detected": true,
      "device_status": "online"
    }
  },
  {
    "test_name": "missing_coordinates",
    "data": {
      "device_id": "test_device_001",
      "ts": "2025-07-18T10:30:00Z",
      "motion_detected": true,
      "device_status": "online"
    }
  }
]
```

## Base64 Encoding Process

### 1. Understanding Base64 Encoding

#### Why Base64 Encoding?
- **Firehose Requirement**: Kinesis Data Firehose automatically base64 encodes data
- **Binary Safety**: Ensures data integrity during transmission
- **Lambda Processing**: Lambda receives base64 encoded data from Firehose

#### Manual Base64 Encoding/Decoding

##### Command Line Tools
```bash
# Encode JSON to base64
echo '{"device_id": "test_device_001", "ts": "2025-07-18T10:30:00Z", "latitude": 37.7749, "longitude": -122.4194, "motion_detected": true, "device_status": "online"}' | base64

# Decode base64 to JSON
echo "eyJkZXZpY2VfaWQiOiAidGVzdF9kZXZpY2VfMDAxIiwgInRzIjogIjIwMjUtMDctMThUMTA6MzA6MDBaIiwgImxhdGl0dWRlIjogMzcuNzc0OSwgImxvbmdpdHVkZSI6IC0xMjIuNDE5NCwgIm1vdGlvbl9kZXRlY3RlZCI6IHRydWUsICJkZXZpY2Vfc3RhdHVzIjogIm9ubGluZSJ9" | base64 -d
```

### 2. Python Base64 Encoding Script

#### Create Base64 Encoder
Create `base64_encoder.py`:
```python
import base64
import json
import sys

def encode_json_to_base64(json_data):
    """
    Encode JSON data to base64 string
    
    Args:
        json_data: Dictionary or string containing JSON data
    
    Returns:
        str: Base64 encoded string
    """
    if isinstance(json_data, dict):
        json_string = json.dumps(json_data)
    else:
        json_string = json_data
    
    # Encode to bytes then to base64
    encoded_bytes = base64.b64encode(json_string.encode('utf-8'))
    return encoded_bytes.decode('utf-8')

def decode_base64_to_json(base64_string):
    """
    Decode base64 string to JSON
    
    Args:
        base64_string: Base64 encoded string
    
    Returns:
        dict: Decoded JSON data
    """
    # Decode from base64 to bytes then to string
    decoded_bytes = base64.b64decode(base64_string)
    json_string = decoded_bytes.decode('utf-8')
    return json.loads(json_string)

def main():
    if len(sys.argv) < 3:
        print("Usage: python base64_encoder.py <encode|decode> <input_file>")
        sys.exit(1)
    
    operation = sys.argv[1]
    input_file = sys.argv[2]
    
    try:
        with open(input_file, 'r') as f:
            content = f.read().strip()
        
        if operation == 'encode':
            # Assume input is JSON
            json_data = json.loads(content)
            encoded = encode_json_to_base64(json_data)
            print(f"Base64 encoded: {encoded}")
            
            # Save to file
            output_file = input_file.replace('.json', '_encoded.txt')
            with open(output_file, 'w') as f:
                f.write(encoded)
            print(f"Saved to: {output_file}")
        
        elif operation == 'decode':
            # Assume input is base64
            decoded = decode_base64_to_json(content)
            print(f"Decoded JSON: {json.dumps(decoded, indent=2)}")
            
            # Save to file
            output_file = input_file.replace('.txt', '_decoded.json')
            with open(output_file, 'w') as f:
                json.dump(decoded, f, indent=2)
            print(f"Saved to: {output_file}")
        
        else:
            print("Invalid operation. Use 'encode' or 'decode'")
            sys.exit(1)
    
    except FileNotFoundError:
        print(f"Error: File '{input_file}' not found")
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON - {e}")
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()
```

#### Usage Examples
```bash
# Encode JSON to base64
python base64_encoder.py encode single_device_test.json

# Decode base64 to JSON
python base64_encoder.py decode single_device_test_encoded.txt
```

### 3. Batch Base64 Encoding

#### Create Batch Encoder
Create `batch_encoder.py`:
```python
import json
import base64
import os

def encode_test_data_batch():
    """
    Encode all test JSON files to base64 format
    """
    test_files = [
        'single_device_test.json',
        'multiple_devices_test.json'
    ]
    
    for file_name in test_files:
        if os.path.exists(file_name):
            print(f"Processing {file_name}...")
            
            with open(file_name, 'r') as f:
                data = json.load(f)
            
            # Handle both single objects and arrays
            if isinstance(data, list):
                encoded_data = []
                for item in data:
                    json_string = json.dumps(item)
                    encoded = base64.b64encode(json_string.encode('utf-8')).decode('utf-8')
                    encoded_data.append({
                        'original': item,
                        'encoded': encoded
                    })
            else:
                json_string = json.dumps(data)
                encoded = base64.b64encode(json_string.encode('utf-8')).decode('utf-8')
                encoded_data = {
                    'original': data,
                    'encoded': encoded
                }
            
            # Save encoded data
            output_file = file_name.replace('.json', '_with_encoding.json')
            with open(output_file, 'w') as f:
                json.dump(encoded_data, f, indent=2)
            
            print(f"Encoded data saved to: {output_file}")
        else:
            print(f"File not found: {file_name}")

if __name__ == '__main__':
    encode_test_data_batch()
```

## Testing IoT Core Integration

### 1. Direct IoT Core Testing

#### Test Message Publishing
```bash
# Test 1: Single message
aws iot-data publish \
  --topic "device/motion_sensor/data" \
  --payload file://single_device_test.json \
  --region us-west-1

# Test 2: Multiple messages
for i in {1..5}; do
  aws iot-data publish \
    --topic "device/motion_sensor/data" \
    --payload "{\"device_id\": \"batch_test_${i}\", \"ts\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\", \"latitude\": 37.7749, \"longitude\": -122.4194, \"motion_detected\": true, \"device_status\": \"online\"}" \
    --region us-west-1
  echo "Published message $i"
  sleep 2
done
```

#### Verify IoT Rule Execution
```bash
# Check IoT rule metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/IoT \
  --metric-name RuleMessageMatched \
  --dimensions Name=RuleName,Value=O2ArenaMotionRule \
  --start-time $(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum \
  --region us-west-1

# Check for rule errors
aws logs filter-log-events \
  --log-group-name "/aws/iot/rule/O2ArenaMotionRule" \
  --start-time $(date -d '5 minutes ago' +%s)000 \
  --region us-west-1
```

### 2. IoT Core Testing Script

#### Create IoT Test Script
Create `test_iot_core.py`:
```python
import boto3
import json
import time
from datetime import datetime, timezone

def test_iot_publishing():
    """
    Test IoT Core message publishing with various scenarios
    """
    iot_client = boto3.client('iot-data', region_name='us-west-1')
    topic = 'device/motion_sensor/data'
    
    test_cases = [
        {
            'name': 'valid_message',
            'payload': {
                'device_id': 'test_device_001',
                'ts': datetime.now(timezone.utc).isoformat(),
                'latitude': 37.7749,
                'longitude': -122.4194,
                'motion_detected': True,
                'device_status': 'online'
            }
        },
        {
            'name': 'edge_coordinates',
            'payload': {
                'device_id': 'test_device_002',
                'ts': datetime.now(timezone.utc).isoformat(),
                'latitude': 90.0,  # Edge case: North pole
                'longitude': -180.0,  # Edge case: International date line
                'motion_detected': False,
                'device_status': 'online'
            }
        },
        {
            'name': 'maintenance_status',
            'payload': {
                'device_id': 'test_device_003',
                'ts': datetime.now(timezone.utc).isoformat(),
                'latitude': 37.7849,
                'longitude': -122.4094,
                'motion_detected': True,
                'device_status': 'maintenance'
            }
        }
    ]
    
    results = []
    
    for test_case in test_cases:
        print(f"Testing: {test_case['name']}")
        
        try:
            response = iot_client.publish(
                topic=topic,
                payload=json.dumps(test_case['payload'])
            )
            
            results.append({
                'test_name': test_case['name'],
                'status': 'SUCCESS',
                'response': response
            })
            
            print(f"  ✓ Success: {response['ResponseMetadata']['HTTPStatusCode']}")
            
        except Exception as e:
            results.append({
                'test_name': test_case['name'],
                'status': 'FAILED',
                'error': str(e)
            })
            
            print(f"  ✗ Failed: {e}")
        
        # Wait between tests
        time.sleep(1)
    
    return results

def main():
    print("Starting IoT Core Publishing Tests...")
    results = test_iot_publishing()
    
    # Summary
    print("\n" + "="*50)
    print("TEST SUMMARY")
    print("="*50)
    
    success_count = sum(1 for r in results if r['status'] == 'SUCCESS')
    total_count = len(results)
    
    print(f"Total Tests: {total_count}")
    print(f"Successful: {success_count}")
    print(f"Failed: {total_count - success_count}")
    
    # Save results
    with open('iot_test_results.json', 'w') as f:
        json.dump(results, f, indent=2, default=str)
    
    print("\nResults saved to: iot_test_results.json")

if __name__ == '__main__':
    main()
```

## Testing Firehose Processing

### 1. Firehose Direct Testing

#### Create Firehose Test Payload
Create `firehose_test_payload.json`:
```json
{
  "records": [
    {
      "recordId": "test-record-1",
      "data": "eyJkZXZpY2VfaWQiOiAidGVzdF9kZXZpY2VfMDAxIiwgInRzIjogIjIwMjUtMDctMThUMTA6MzA6MDBaIiwgImxhdGl0dWRlIjogMzcuNzc0OSwgImxvbmdpdHVkZSI6IC0xMjIuNDE5NCwgIm1vdGlvbl9kZXRlY3RlZCI6IHRydWUsICJkZXZpY2Vfc3RhdHVzIjogIm9ubGluZSJ9"
    }
  ]
}
```

#### Test Firehose Delivery
```bash
# Put record directly to Firehose
aws firehose put-record \
  --delivery-stream-name o2-arena-motion-stream \
  --record Data="eyJkZXZpY2VfaWQiOiAidGVzdF9kZXZpY2VfMDAxIiwgInRzIjogIjIwMjUtMDctMThUMTA6MzA6MDBaIiwgImxhdGl0dWRlIjogMzcuNzc0OSwgImxvbmdpdHVkZSI6IC0xMjIuNDE5NCwgIm1vdGlvbl9kZXRlY3RlZCI6IHRydWUsICJkZXZpY2Vfc3RhdHVzIjogIm9ubGluZSJ9" \
  --region us-west-1

# Put batch records
aws firehose put-record-batch \
  --delivery-stream-name o2-arena-motion-stream \
  --records '[
    {
      "Data": "eyJkZXZpY2VfaWQiOiAidGVzdF9kZXZpY2VfMDAxIiwgInRzIjogIjIwMjUtMDctMThUMTA6MzA6MDBaIiwgImxhdGl0dWRlIjogMzcuNzc0OSwgImxvbmdpdHVkZSI6IC0xMjIuNDE5NCwgIm1vdGlvbl9kZXRlY3RlZCI6IHRydWUsICJkZXZpY2Vfc3RhdHVzIjogIm9ubGluZSJ9"
    },
    {
      "Data": "eyJkZXZpY2VfaWQiOiAidGVzdF9kZXZpY2VfMDAyIiwgInRzIjogIjIwMjUtMDctMThUMTA6MzE6MDBaIiwgImxhdGl0dWRlIjogMzcuNzg0OSwgImxvbmdpdHVkZSI6IC0xMjIuNDA5NCwgIm1vdGlvbl9kZXRlY3RlZCI6IGZhbHNlLCAiZGV2aWNlX3N0YXR1cyI6ICJvbmxpbmUifQ=="
    }
  ]' \
  --region us-west-1
```

### 2. Firehose Testing Script

#### Create Firehose Test Script
Create `test_firehose.py`:
```python
import boto3
import json
import base64
import time
from datetime import datetime, timezone

def create_test_records():
    """
    Create test records with base64 encoded data
    """
    test_data = [
        {
            'device_id': 'firehose_test_001',
            'ts': datetime.now(timezone.utc).isoformat(),
            'latitude': 37.7749,
            'longitude': -122.4194,
            'motion_detected': True,
            'device_status': 'online'
        },
        {
            'device_id': 'firehose_test_002',
            'ts': datetime.now(timezone.utc).isoformat(),
            'latitude': 37.7849,
            'longitude': -122.4094,
            'motion_detected': False,
            'device_status': 'online'
        }
    ]
    
    records = []
    for i, data in enumerate(test_data):
        json_string = json.dumps(data)
        encoded_data = base64.b64encode(json_string.encode('utf-8')).decode('utf-8')
        
        records.append({
            'Data': encoded_data
        })
    
    return records

def test_firehose_delivery():
    """
    Test Firehose delivery with multiple scenarios
    """
    firehose_client = boto3.client('firehose', region_name='us-west-1')
    delivery_stream = 'o2-arena-motion-stream'
    
    # Test 1: Single record
    print("Test 1: Single record delivery")
    records = create_test_records()
    
    try:
        response = firehose_client.put_record(
            DeliveryStreamName=delivery_stream,
            Record=records[0]
        )
        print(f"  ✓ Single record delivered: {response['RecordId']}")
    except Exception as e:
        print(f"  ✗ Single record failed: {e}")
    
    time.sleep(2)
    
    # Test 2: Batch records
    print("Test 2: Batch record delivery")
    
    try:
        response = firehose_client.put_record_batch(
            DeliveryStreamName=delivery_stream,
            Records=records
        )
        
        success_count = len([r for r in response['RequestResponses'] if 'RecordId' in r])
        print(f"  ✓ Batch delivered: {success_count}/{len(records)} records")
        
        if response['FailedPutCount'] > 0:
            print(f"  ⚠ Failed records: {response['FailedPutCount']}")
            for i, record_response in enumerate(response['RequestResponses']):
                if 'ErrorCode' in record_response:
                    print(f"    Record {i}: {record_response['ErrorCode']} - {record_response['ErrorMessage']}")
    
    except Exception as e:
        print(f"  ✗ Batch delivery failed: {e}")

def check_firehose_metrics():
    """
    Check Firehose CloudWatch metrics
    """
    cloudwatch = boto3.client('cloudwatch', region_name='us-west-1')
    
    print("Checking Firehose metrics...")
    
    # Check delivery metrics
    metrics = [
        'DeliveryToS3.Records',
        'DeliveryToS3.Success',
        'DeliveryToS3.DataFreshness'
    ]
    
    end_time = datetime.now(timezone.utc)
    start_time = datetime.now(timezone.utc).replace(hour=end_time.hour-1)
    
    for metric in metrics:
        try:
            response = cloudwatch.get_metric_statistics(
                Namespace='AWS/Kinesis/Firehose',
                MetricName=metric,
                Dimensions=[
                    {
                        'Name': 'DeliveryStreamName',
                        'Value': 'o2-arena-motion-stream'
                    }
                ],
                StartTime=start_time,
                EndTime=end_time,
                Period=300,
                Statistics=['Sum', 'Average']
            )
            
            if response['Datapoints']:
                latest = max(response['Datapoints'], key=lambda x: x['Timestamp'])
                print(f"  {metric}: {latest.get('Sum', latest.get('Average', 'N/A'))}")
            else:
                print(f"  {metric}: No data")
                
        except Exception as e:
            print(f"  Error getting {metric}: {e}")

def main():
    print("Starting Firehose Testing...")
    print("="*50)
    
    # Run tests
    test_firehose_delivery()
    
    print("\nWaiting 60 seconds for processing...")
    time.sleep(60)
    
    # Check metrics
    check_firehose_metrics()
    
    print("\nFirehose testing completed!")

if __name__ == '__main__':
    main()
```

## Testing Lambda Function

### 1. Direct Lambda Testing

#### Create Lambda Test Event
Create `lambda_test_event.json`:
```json
{
  "records": [
    {
      "recordId": "49590338271490256608559692626766421738343049771565449218",
      "approximateArrivalTimestamp": 1642248600000,
      "data": "eyJkZXZpY2VfaWQiOiAidGVzdF9kZXZpY2VfMDAxIiwgInRzIjogIjIwMjUtMDctMThUMTA6MzA6MDBaIiwgImxhdGl0dWRlIjogMzcuNzc0OSwgImxvbmdpdHVkZSI6IC0xMjIuNDE5NCwgIm1vdGlvbl9kZXRlY3RlZCI6IHRydWUsICJkZXZpY2Vfc3RhdHVzIjogIm9ubGluZSJ9"
    }
  ]
}
```

#### Test Lambda Function
```bash
# Test Lambda function directly
aws lambda invoke \
  --function-name o2-arena-iot-data-processor \
  --payload file://lambda_test_event.json \
  --response.json \
  --region us-west-1

# Check response
cat response.json

# Test with multiple records
aws lambda invoke \
  --function-name o2-arena-iot-data-processor \
  --payload '{
    "records": [
      {
        "recordId": "test-1",
        "data": "eyJkZXZpY2VfaWQiOiAidGVzdF9kZXZpY2VfMDAxIiwgInRzIjogIjIwMjUtMDctMThUMTA6MzA6MDBaIiwgImxhdGl0dWRlIjogMzcuNzc0OSwgImxvbmdpdHVkZSI6IC0xMjIuNDE5NCwgIm1vdGlvbl9kZXRlY3RlZCI6IHRydWUsICJkZXZpY2Vfc3RhdHVzIjogIm9ubGluZSJ9"
      },
      {
        "recordId": "test-2",
        "data": "eyJkZXZpY2VfaWQiOiAidGVzdF9kZXZpY2VfMDAyIiwgInRzIjogIjIwMjUtMDctMThUMTA6MzE6MDBaIiwgImxhdGl0dWRlIjogMzcuNzg0OSwgImxvbmdpdHVkZSI6IC0xMjIuNDA5NCwgIm1vdGlvbl9kZXRlY3RlZCI6IGZhbHNlLCAiZGV2aWNlX3N0YXR1cyI6ICJvbmxpbmUifQ=="
      }
    ]
  }' \
  --response_multi.json \
  --region us-west-1
```

### 2. Lambda Testing Script

#### Create Lambda Test Script
Create `test_lambda.py`:
```python
import boto3
import json
import base64
import time
from datetime import datetime, timezone

def create_lambda_test_event(test_data_list):
    """
    Create Lambda test event with multiple records
    """
    records = []
    
    for i, data in enumerate(test_data_list):
        json_string = json.dumps(data)
        encoded_data = base64.b64encode(json_string.encode('utf-8')).decode('utf-8')
        
        records.append({
            'recordId': f'test-record-{i+1}',
            'approximateArrivalTimestamp': int(time.time() * 1000),
            'data': encoded_data
        })
    
    return {'records': records}

def test_lambda_function():
    """
    Test Lambda function with various scenarios
    """
    lambda_client = boto3.client('lambda', region_name='us-west-1')
    function_name = 'o2-arena-iot-data-processor'
    
    # Test scenarios
    test_scenarios = [
        {
            'name': 'valid_single_record',
            'data': [{
                'device_id': 'lambda_test_001',
                'ts': datetime.now(timezone.utc).isoformat(),
                'latitude': 37.7749,
                'longitude': -122.4194,
                'motion_detected': True,
                'device_status': 'online'
            }]
        },
        {
            'name': 'multiple_records',
            'data': [
                {
                    'device_id': 'lambda_test_002',
                    'ts': datetime.now(timezone.utc).isoformat(),
                    'latitude': 37.7749,
                    'longitude': -122.4194,
                    'motion_detected': True,
                    'device_status': 'online'
                },
                {
                    'device_id': 'lambda_test_003',
                    'ts': datetime.now(timezone.utc).isoformat(),
                    'latitude': 37.7849,
                    'longitude': -122.4094,
                    'motion_detected': False,
                    'device_status': 'maintenance'
                }
            ]
        }
    ]
    
    results = []
    
    for scenario in test_scenarios:
        print(f"Testing scenario: {scenario['name']}")
        
        # Create test event
        test_event = create_lambda_test_event(scenario['data'])
        
        try:
            response = lambda_client.invoke(
                FunctionName=function_name,
                Payload=json.dumps(test_event)
            )
            
            # Read response
            response_payload = response['Payload'].read()
            response_data = json.loads(response_payload.decode('utf-8'))
            
            # Check for errors
            if 'errorMessage' in response_data:
                print(f"  ✗ Error: {response_data['errorMessage']}")
                results.append({
                    'scenario': scenario['name'],
                    'status': 'ERROR',
                    'error': response_data['errorMessage']
                })
            else:
                processed_records = response_data.get('records', [])
                success_count = len([r for r in processed_records if r['result'] == 'Ok'])
                
                print(f"  ✓ Success: {success_count}/{len(processed_records)} records processed")
                results.append({
                    'scenario': scenario['name'],
                    'status': 'SUCCESS',
                    'processed_count': success_count,
                    'total_count': len(processed_records)
                })
            
        except Exception as e:
            print(f"  ✗ Exception: {e}")
            results.append({
                'scenario': scenario['name'],
                'status': 'EXCEPTION',
                'error': str(e)
            })
        
        time.sleep(2)
    
    return results

def check_lambda_logs():
    """
    Check Lambda CloudWatch logs
    """
    logs_client = boto3.client('logs', region_name='us-west-1')
    log_group = '/aws/lambda/o2-arena-iot-data-processor'
    
    print("Checking Lambda logs...")
    
    try:
        # Get latest log stream
        response = logs_client.describe_log_streams(
            logGroupName=log_group,
            orderBy='LastEventTime',
            descending=True,
            limit=1
        )
        
        if response['logStreams']:
            log_stream = response['logStreams'][0]['logStreamName']
            print(f"Latest log stream: {log_stream}")
            
            # Get recent log events
            events_response = logs_client.get_log_events(
                logGroupName=log_group,
                logStreamName=log_stream,
                startTime=int((time.time() - 300) * 1000),  # Last 5 minutes
                limit=10
            )
            
            print("Recent log events:")
            for event in events_response['events']:
                timestamp = datetime.fromtimestamp(event['timestamp'] / 1000)
                print(f"  {timestamp}: {event['message']}")
        else:
            print("No log streams found")
            
    except Exception as e:
        print(f"Error checking logs: {e}")

def main():
    print("Starting Lambda Function Testing...")
    print("="*50)
    
    # Run tests
    results = test_lambda_function()
    
    # Check logs
    print("\n" + "="*50)
    check_lambda_logs()
    
    # Summary
    print("\n" + "="*50)
    print("TEST SUMMARY")
    print("="*50)
    
    success_count = len([r for r in results if r['status'] == 'SUCCESS'])
    total_count = len(results)
    
    print(f"Total Tests: {total_count}")
    print(f"Successful: {success_count}")
    print(f"Failed: {total_count - success_count}")
    
    # Save results
    with open('lambda_test_results.json', 'w') as f:
        json.dump(results, f, indent=2, default=str)
    
    print("\nResults saved to: lambda_test_results.json")

if __name__ == '__main__':
    main()
```

## Testing Database Integration

### 1. Database Connection Testing

#### Test Database Connectivity
```bash
# Test database connection
mysql -h 3.101.111.137 -u usr_iot_admin -p'dew4DL' -e "SELECT 1"

# Check database and table
mysql -h 3.101.111.137 -u usr_iot_admin -p'dew4DL' -e "
USE db_iot_smart_buildings;
SHOW TABLES;
DESCRIBE tbl_smart_motion_model_x;
"
```

#### Test Data Insertion
```bash
# Insert test record
mysql -h 3.101.111.137 -u usr_iot_admin -p'dew4DL' -e "
USE db_iot_smart_buildings;
INSERT INTO tbl_smart_motion_model_x 
(device_id, ts, latitude, longitude, motion_detected, device_status) 
VALUES ('manual_test_001', NOW(), 37.7749, -122.4194, 1, 'online');
"

# Verify insertion
mysql -h 3.101.111.137 -u usr_iot_admin -p'dew4DL' -e "
USE db_iot_smart_buildings;
SELECT * FROM tbl_smart_motion_model_x 
WHERE device_id = 'manual_test_001';
"

# Clean up
mysql -h 3.101.111.137 -u usr_iot_admin -p'dew4DL' -e "
USE db_iot_smart_buildings;
DELETE FROM tbl_smart_motion_model_x 
WHERE device_id = 'manual_test_001';
"
```

### 2. Database Testing Script

#### Create Database Test Script
Create `test_database.py`:
```python
import pymysql
import json
import time
from datetime import datetime, timezone

def test_database_connection():
    """
    Test database connection and basic operations
    """
    config = {
        'host': '3.101.111.137',
        'user': 'usr_iot_admin',
        'password': 'dew4DL',
        'database': 'db_iot_smart_buildings',
        'charset': 'utf8mb4'
    }
    
    try:
        # Test connection
        connection = pymysql.connect(**config)
        print("✓ Database connection successful")
        
        # Test table access
        with connection.cursor() as cursor:
            cursor.execute("SELECT COUNT(*) FROM tbl_smart_motion_model_x")
            count = cursor.fetchone()[0]
            print(f"✓ Table access successful - {count} records exist")
        
        # Test insertion
        test_data = {
            'device_id': f'db_test_{int(time.time())}',
            'ts': datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S'),
            'latitude': 37.7749,
            'longitude': -122.4194,
            'motion_detected': True,
            'device_status': 'online'
        }
        
        with connection.cursor() as cursor:
            sql = """
            INSERT INTO tbl_smart_motion_model_x 
            (device_id, ts, latitude, longitude, motion_detected, device_status) 
            VALUES (%s, %s, %s, %s, %s, %s)
            """
            cursor.execute(sql, (
                test_data['device_id'],
                test_data['ts'],
                test_data['latitude'],
                test_data['longitude'],
                test_data['motion_detected'],
                test_data['device_status']
            ))
        
        connection.commit()
        print(f"✓ Data insertion successful - device_id: {test_data['device_id']}")
        
        # Test retrieval
        with connection.cursor() as cursor:
            cursor.execute(
                "SELECT * FROM tbl_smart_motion_model_x WHERE device_id = %s",
                (test_data['device_id'],)
            )
            result = cursor.fetchone()
            if result:
                print("✓ Data retrieval successful")
            else:
                print("✗ Data retrieval failed")
        
        # Clean up test data
        with connection.cursor() as cursor:
            cursor.execute(
                "DELETE FROM tbl_smart_motion_model_x WHERE device_id = %s",
                (test_data['device_id'],)
            )
        connection.commit()
        print("✓ Test data cleaned up")
        
        connection.close()
        return True
        
    except Exception as e:
        print(f"✗ Database test failed: {e}")
        return False

def verify_pipeline_data():
    """
    Verify that pipeline data is being inserted correctly
    """
    config = {
        'host': '3.101.111.137',
        'user': 'usr_iot_admin',
        'password': 'dew4DL',
        'database': 'db_iot_smart_buildings',
        'charset': 'utf8mb4'
    }
    
    try:
        connection = pymysql.connect(**config)
        print("Checking pipeline data...")
        
        with connection.cursor() as cursor:
            # Check recent records
            cursor.execute("""
                SELECT device_id, ts, latitude, longitude, motion_detected, device_status 
                FROM tbl_smart_motion_model_x 
                ORDER BY ts DESC 
                LIMIT 10
            """)
            
            results = cursor.fetchall()
            
            if results:
                print(f"✓ Found {len(results)} recent records:")
                for row in results:
                    print(f"  Device: {row[0]}, Time: {row[1]}, Location: ({row[2]}, {row[3]})")
            else:
                print("✗ No recent records found")
        
        connection.close()
        
    except Exception as e:
        print(f"✗ Pipeline data verification failed: {e}")

def main():
    print("Starting Database Testing...")
    print("="*50)
    
    # Test database connection
    if test_database_connection():
        print("\n" + "="*50)
        # Verify pipeline data
        verify_pipeline_data()
    
    print("\nDatabase testing completed!")

if __name__ == '__main__':
    main()
```

## Testing S3 Storage

### 1. S3 Testing Commands

#### Check S3 Bucket Contents
```bash
# List all objects in bucket
aws s3 ls s3://o2-arena-iot-data-bucket-9eby42ws --recursive --region us-west-1

# List objects by prefix
aws s3 ls s3://o2-arena-iot-data-bucket-9eby42ws/o2-arena-motion/ --recursive --region us-west-1

# Check error files
aws s3 ls s3://o2-arena-iot-data-bucket-9eby42ws/errors/ --recursive --region us-west-1

# Download and examine a file
aws s3 cp s3://o2-arena-iot-data-bucket-9eby42ws/o2-arena-motion/2025/07/18/06/filename.gz ./temp_file.gz --region us-west-1
gunzip temp_file.gz
cat temp_file
```

### 2. S3 Testing Script

#### Create S3 Test Script
Create `test_s3.py`:
```python
import boto3
import json
import gzip
from datetime import datetime, timezone, timedelta

def test_s3_access():
    """
    Test S3 bucket access and file operations
    """
    s3_client = boto3.client('s3', region_name='us-west-1')
    bucket_name = 'o2-arena-iot-data-bucket-9eby42ws'  # Replace with your bucket
    
    try:
        # Test bucket access
        response = s3_client.head_bucket(Bucket=bucket_name)
        print("✓ S3 bucket access successful")
        
        # List recent objects
        response = s3_client.list_objects_v2(
            Bucket=bucket_name,
            Prefix='o2-arena-motion/',
            MaxKeys=10
        )
        
        if 'Contents' in response:
            print(f"✓ Found {len(response['Contents'])} objects")
            
            # Download and examine latest file
            if response['Contents']:
                latest_object = max(response['Contents'], key=lambda x: x['LastModified'])
                print(f"Latest file: {latest_object['Key']}")
                
                # Download file
                obj = s3_client.get_object(Bucket=bucket_name, Key=latest_object['Key'])
                content = obj['Body'].read()
                
                # Decompress if gzipped
                if latest_object['Key'].endswith('.gz'):
                    content = gzip.decompress(content)
                
                # Parse and validate content
                content_str = content.decode('utf-8')
                lines = content_str.strip().split('\n')
                
                print(f"✓ File contains {len(lines)} records")
                
                # Validate first few records
                valid_records = 0
                for i, line in enumerate(lines[:5]):
                    if line.strip():
                        try:
                            record = json.loads(line)
                            if 'device_id' in record and 'ts' in record:
                                valid_records += 1
                                print(f"  Record {i+1}: {record['device_id']} at {record['ts']}")
                        except json.JSONDecodeError:
                            print(f"  Record {i+1}: Invalid JSON")
                
                print(f"✓ Valid records: {valid_records}/5")
        else:
            print("✗ No objects found in bucket")
        
        # Check error files
        error_response = s3_client.list_objects_v2(
            Bucket=bucket_name,
            Prefix='errors/',
            MaxKeys=10
        )
        
        if 'Contents' in error_response:
            print(f"⚠ Found {len(error_response['Contents'])} error files")
            for obj in error_response['Contents']:
                print(f"  Error file: {obj['Key']}")
        else:
            print("✓ No error files found")
        
        return True
        
    except Exception as e:
        print(f"✗ S3 test failed: {e}")
        return False

def analyze_data_patterns():
    """
    Analyze patterns in S3 data
    """
    s3_client = boto3.client('s3', region_name='us-west-1')
    bucket_name = 'o2-arena-iot-data-bucket-9eby42ws'
    
    try:
        # Get objects from last 24 hours
        response = s3_client.list_objects_v2(
            Bucket=bucket_name,
            Prefix='o2-arena-motion/'
        )
        
        if 'Contents' not in response:
            print("No data files found")
            return
        
        recent_files = [
            obj for obj in response['Contents']
            if obj['LastModified'] >= datetime.now(timezone.utc) - timedelta(hours=24)
        ]
        
        print(f"Analyzing {len(recent_files)} recent files...")
        
        total_records = 0
        device_ids = set()
        
        for obj in recent_files[:5]:  # Limit to first 5 files
            try:
                # Download and process file
                s3_obj = s3_client.get_object(Bucket=bucket_name, Key=obj['Key'])
                content = s3_obj['Body'].read()
                
                if obj['Key'].endswith('.gz'):
                    content = gzip.decompress(content)
                
                content_str = content.decode('utf-8')
                lines = content_str.strip().split('\n')
                
                for line in lines:
                    if line.strip():
                        try:
                            record = json.loads(line)
                            total_records += 1
                            if 'device_id' in record:
                                device_ids.add(record['device_id'])
                        except json.JSONDecodeError:
                            continue
                            
            except Exception as e:
                print(f"Error processing {obj['Key']}: {e}")
        
        print(f"✓ Total records analyzed: {total_records}")
        print(f"✓ Unique devices: {len(device_ids)}")
        if device_ids:
            print(f"  Device IDs: {', '.join(sorted(device_ids))}")
        
    except Exception as e:
        print(f"✗ Data analysis failed: {e}")

def main():
    print("Starting S3 Testing...")
    print("="*50)
    
    # Test S3 access
    if test_s3_access():
        print("\n" + "="*50)
        # Analyze data patterns
        analyze_data_patterns()
    
    print("\nS3 testing completed!")

if __name__ == '__main__':
    main()
```

## End-to-End Pipeline Testing

### 1. Complete Pipeline Test Script

#### Create End-to-End Test Script
Create `test_pipeline_e2e.py`:
```python
import boto3
import json
import base64
import time
import pymysql
from datetime import datetime, timezone

def run_complete_pipeline_test():
    """
    Run complete end-to-end pipeline test
    """
    # Test configuration
    test_device_id = f'e2e_test_{int(time.time())}'
    test_timestamp = datetime.now(timezone.utc).isoformat()
    
    print(f"Starting E2E test with device: {test_device_id}")
    print("="*60)
    
    # Step 1: Publish to IoT Core
    print("Step 1: Publishing to IoT Core...")
    success = publish_to_iot_core(test_device_id, test_timestamp)
    if not success:
        print("✗ E2E test failed at IoT Core publishing")
        return False
    
    # Step 2: Wait for processing
    print("Step 2: Waiting for pipeline processing...")
    time.sleep(90)  # Wait for Firehose buffering and Lambda processing
    
    # Step 3: Check database
    print("Step 3: Verifying database insertion...")
    db_success = verify_database_record(test_device_id)
    
    # Step 4: Check S3
    print("Step 4: Verifying S3 storage...")
    s3_success = verify_s3_storage(test_device_id)
    
    # Step 5: Check CloudWatch logs
    print("Step 5: Checking CloudWatch logs...")
    logs_success = check_cloudwatch_logs(test_device_id)
    
    # Step 6: Cleanup
    print("Step 6: Cleaning up test data...")
    cleanup_test_data(test_device_id)
    
    # Results
    print("\n" + "="*60)
    print("E2E TEST RESULTS")
    print("="*60)
    print(f"IoT Core Publishing: {'✓' if success else '✗'}")
    print(f"Database Insertion: {'✓' if db_success else '✗'}")
    print(f"S3 Storage: {'✓' if s3_success else '✗'}")
    print(f"CloudWatch Logs: {'✓' if logs_success else '✗'}")
    
    overall_success = success and db_success and s3_success and logs_success
    print(f"\nOverall Test: {'✓ SUCCESS' if overall_success else '✗ FAILED'}")
    
    return overall_success

def publish_to_iot_core(device_id, timestamp):
    """
    Publish test message to IoT Core
    """
    try:
        iot_client = boto3.client('iot-data', region_name='us-west-1')
        
        message = {
            'device_id': device_id,
            'ts': timestamp,
            'latitude': 37.7749,
            'longitude': -122.4194,
            'motion_detected': True,
            'device_status': 'online'
        }
        
        response = iot_client.publish(
            topic='device/motion_sensor/data',
            payload=json.dumps(message)
        )
        
        print(f"  ✓ Message published: {response['ResponseMetadata']['HTTPStatusCode']}")
        return True
        
    except Exception as e:
        print(f"  ✗ Failed to publish: {e}")
        return False

def verify_database_record(device_id):
    """
    Verify record exists in database
    """
    try:
        connection = pymysql.connect(
            host='3.101.111.137',
            user='usr_iot_admin',
            password='dew4DL',
            database='db_iot_smart_buildings',
            charset='utf8mb4'
        )
        
        with connection.cursor() as cursor:
            cursor.execute(
                "SELECT COUNT(*) FROM tbl_smart_motion_model_x WHERE device_id = %s",
                (device_id,)
            )
            count = cursor.fetchone()[0]
            
            if count > 0:
                print(f"  ✓ Record found in database: {count} records")
                return True
            else:
                print(f"  ✗ No records found in database")
                return False
                
        connection.close()
        
    except Exception as e:
        print(f"  ✗ Database verification failed: {e}")
        return False

def verify_s3_storage(device_id):
    """
    Verify data exists in S3
    """
    try:
        s3_client = boto3.client('s3', region_name='us-west-1')
        bucket_name = 'o2-arena-iot-data-bucket-9eby42ws'
        
        # List recent objects
        response = s3_client.list_objects_v2(
            Bucket=bucket_name,
            Prefix='o2-arena-motion/',
            MaxKeys=50
        )
        
        if 'Contents' not in response:
            print("  ✗ No objects found in S3")
            return False
        
        # Search for device_id in recent files
        for obj in response['Contents']:
            try:
                s3_obj = s3_client.get_object(Bucket=bucket_name, Key=obj['Key'])
                content = s3_obj['Body'].read()
                
                if obj['Key'].endswith('.gz'):
                    import gzip
                    content = gzip.decompress(content)
                
                content_str = content.decode('utf-8')
                if device_id in content_str:
                    print(f"  ✓ Device data found in S3: {obj['Key']}")
                    return True
                    
            except Exception as e:
                continue
        
        print(f"  ✗ Device data not found in S3")
        return False
        
    except Exception as e:
        print(f"  ✗ S3 verification failed: {e}")
        return False

def check_cloudwatch_logs(device_id):
    """
    Check CloudWatch logs for processing evidence
    """
    try:
        logs_client = boto3.client('logs', region_name='us-west-1')
        
        # Check Lambda logs
        response = logs_client.filter_log_events(
            logGroupName='/aws/lambda/o2-arena-iot-data-processor',
            startTime=int((time.time() - 300) * 1000),  # Last 5 minutes
            filterPattern=device_id
        )
        
        if response['events']:
            print(f"  ✓ Found {len(response['events'])} log events")
            return True
        else:
            print(f"  ✗ No log events found for device")
            return False
            
    except Exception as e:
        print(f"  ✗ CloudWatch logs check failed: {e}")
        return False

def cleanup_test_data(device_id):
    """
    Clean up test data from database
    """
    try:
        connection = pymysql.connect(
            host='3.101.111.137',
            user='usr_iot_admin',
            password='dew4DL',
            database='db_iot_smart_buildings',
            charset='utf8mb4'
        )
        
        with connection.cursor() as cursor:
            cursor.execute(
                "DELETE FROM tbl_smart_motion_model_x WHERE device_id = %s",
                (device_id,)
            )
        
        connection.commit()
        connection.close()
        
        print(f"  ✓ Test data cleaned up")
        
    except Exception as e:
        print(f"  ✗ Cleanup failed: {e}")

def main():
    print("IoT Pipeline End-to-End Testing")
    print("="*60)
    
    # Run complete pipeline test
    success = run_complete_pipeline_test()
    
    if success:
        print("\n🎉 All tests passed! Pipeline is working correctly.")
    else:
        print("\n❌ Some tests failed. Please check the logs above.")

if __name__ == '__main__':
    main()
```

### 2. Automated Testing Script

#### Create Automated Test Runner
Create `run_all_tests.sh`:
```bash
#!/bin/bash

# IoT Pipeline Automated Test Runner
echo "======================================================"
echo "IoT Pipeline Automated Test Runner"
echo "======================================================"

# Set error handling
set -e

# Test configuration
TEST_DIR="test_results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Create test results directory
mkdir -p $TEST_DIR

echo "Starting automated tests at $(date)"

# Test 1: IoT Core
echo "Running IoT Core tests..."
python test_iot_core.py > $TEST_DIR/iot_core_$TIMESTAMP.log 2>&1
if [ $? -eq 0 ]; then
    echo "✓ IoT Core tests passed"
else
    echo "✗ IoT Core tests failed"
fi

# Test 2: Firehose
echo "Running Firehose tests..."
python test_firehose.py > $TEST_DIR/firehose_$TIMESTAMP.log 2>&1
if [ $? -eq 0 ]; then
    echo "✓ Firehose tests passed"
else
    echo "✗ Firehose tests failed"
fi

# Test 3: Lambda
echo "Running Lambda tests..."
python test_lambda.py > $TEST_DIR/lambda_$TIMESTAMP.log 2>&1
if [ $? -eq 0 ]; then
    echo "✓ Lambda tests passed"
else
    echo "✗ Lambda tests failed"
fi

# Test 4: Database
echo "Running Database tests..."
python test_database.py > $TEST_DIR/database_$TIMESTAMP.log 2>&1
if [ $? -eq 0 ]; then
    echo "✓ Database tests passed"
else
    echo "✗ Database tests failed"
fi

# Test 5: S3
echo "Running S3 tests..."
python test_s3.py > $TEST_DIR/s3_$TIMESTAMP.log 2>&1
if [ $? -eq 0 ]; then
    echo "✓ S3 tests passed"
else
    echo "✗ S3 tests failed"
fi

# Test 6: End-to-End
echo "Running End-to-End tests..."
python test_pipeline_e2e.py > $TEST_DIR/e2e_$TIMESTAMP.log 2>&1
if [ $? -eq 0 ]; then
    echo "✓ End-to-End tests passed"
else
    echo "✗ End-to-End tests failed"
fi

echo "======================================================"
echo "Test run completed at $(date)"
echo "Results saved in: $TEST_DIR/"
echo "======================================================"
```

## Monitoring and Verification

### 1. CloudWatch Dashboard Setup

#### Create Monitoring Dashboard
Create `create_dashboard.py`:
```python
import boto3
import json

def create_pipeline_dashboard():
    """
    Create CloudWatch dashboard for pipeline monitoring
    """
    cloudwatch = boto3.client('cloudwatch', region_name='us-west-1')
    
    dashboard_body = {
        "widgets": [
            {
                "type": "metric",
                "x": 0,
                "y": 0,
                "width": 12,
                "height": 6,
                "properties": {
                    "metrics": [
                        ["AWS/Lambda", "Invocations", "FunctionName", "o2-arena-iot-data-processor"],
                        [".", "Errors", ".", "."],
                        [".", "Duration", ".", "."]
                    ],
                    "period": 300,
                    "stat": "Sum",
                    "region": "us-west-1",
                    "title": "Lambda Metrics"
                }
            },
            {
                "type": "metric",
                "x": 12,
                "y": 0,
                "width": 12,
                "height": 6,
                "properties": {
                    "metrics": [
                        ["AWS/Kinesis/Firehose", "DeliveryToS3.Records", "DeliveryStreamName", "o2-arena-motion-stream"],
                        [".", "DeliveryToS3.Success", ".", "."],
                        [".", "DeliveryToS3.DataFreshness", ".", "."]
                    ],
                    "period": 300,
                    "stat": "Sum",
                    "region": "us-west-1",
                    "title": "Firehose Metrics"
                }
            },
            {
                "type": "log",
                "x": 0,
                "y": 6,
                "width": 24,
                "height": 6,
                "properties": {
                    "query": "SOURCE '/aws/lambda/o2-arena-iot-data-processor'\n| fields @timestamp, @message\n| filter @message like /ERROR/\n| sort @timestamp desc\n| limit 20",
                    "region": "us-west-1",
                    "title": "Lambda Errors"
                }
            }
        ]
    }
    
    try:
        response = cloudwatch.put_dashboard(
            DashboardName='IoT-Pipeline-Monitoring',
            DashboardBody=json.dumps(dashboard_body)
        )
        print("✓ Dashboard created successfully")
        print(f"Dashboard URL: https://console.aws.amazon.com/cloudwatch/home?region=us-west-1#dashboards:name=IoT-Pipeline-Monitoring")
        return True
    except Exception as e:
        print(f"✗ Dashboard creation failed: {e}")
        return False

if __name__ == '__main__':
    create_pipeline_dashboard()
```

### 2. Continuous Monitoring Script

#### Create Monitoring Script
Create `monitor_pipeline.py`:
```python
import boto3
import time
import json
from datetime import datetime, timezone, timedelta

def monitor_pipeline_health():
    """
    Monitor pipeline health and report status
    """
    cloudwatch = boto3.client('cloudwatch', region_name='us-west-1')
    
    # Time range for metrics
    end_time = datetime.now(timezone.utc)
    start_time = end_time - timedelta(minutes=15)
    
    print(f"Pipeline Health Check - {end_time.strftime('%Y-%m-%d %H:%M:%S UTC')}")
    print("="*60)
    
    # Check Lambda metrics
    lambda_health = check_lambda_health(cloudwatch, start_time, end_time)
    
    # Check Firehose metrics
    firehose_health = check_firehose_health(cloudwatch, start_time, end_time)
    
    # Check recent errors
    error_count = check_recent_errors()
    
    # Overall health assessment
    overall_health = lambda_health and firehose_health and error_count == 0
    
    print("\n" + "="*60)
    print("HEALTH SUMMARY")
    print("="*60)
    print(f"Lambda Health: {'✓ HEALTHY' if lambda_health else '✗ UNHEALTHY'}")
    print(f"Firehose Health: {'✓ HEALTHY' if firehose_health else '✗ UNHEALTHY'}")
    print(f"Error Count: {error_count}")
    print(f"Overall Status: {'✓ HEALTHY' if overall_health else '✗ UNHEALTHY'}")
    
    return overall_health

def check_lambda_health(cloudwatch, start_time, end_time):
    """
    Check Lambda function health
    """
    try:
        # Get invocation count
        invocations = cloudwatch.get_metric_statistics(
            Namespace='AWS/Lambda',
            MetricName='Invocations',
            Dimensions=[
                {'Name': 'FunctionName', 'Value': 'o2-arena-iot-data-processor'}
            ],
            StartTime=start_time,
            EndTime=end_time,
            Period=300,
            Statistics=['Sum']
        )
        
        # Get error count
        errors = cloudwatch.get_metric_statistics(
            Namespace='AWS/Lambda',
            MetricName='Errors',
            Dimensions=[
                {'Name': 'FunctionName', 'Value': 'o2-arena-iot-data-processor'}
            ],
            StartTime=start_time,
            EndTime=end_time,
            Period=300,
            Statistics=['Sum']
        )
        
        total_invocations = sum(point['Sum'] for point in invocations['Datapoints'])
        total_errors = sum(point['Sum'] for point in errors['Datapoints'])
        
        error_rate = (total_errors / total_invocations * 100) if total_invocations > 0 else 0
        
        print(f"Lambda Invocations: {total_invocations}")
        print(f"Lambda Errors: {total_errors}")
        print(f"Error Rate: {error_rate:.2f}%")
        
        # Health criteria: less than 5% error rate
        return error_rate < 5.0
        
    except Exception as e:
        print(f"Lambda health check failed: {e}")
        return False

def check_firehose_health(cloudwatch, start_time, end_time):
    """
    Check Firehose delivery health
    """
    try:
        # Get delivery success rate
        success = cloudwatch.get_metric_statistics(
            Namespace='AWS/Kinesis/Firehose',
            MetricName='DeliveryToS3.Success',
            Dimensions=[
                {'Name': 'DeliveryStreamName', 'Value': 'o2-arena-motion-stream'}
            ],
            StartTime=start_time,
            EndTime=end_time,
            Period=300,
            Statistics=['Average']
        )
        
        # Get data freshness
        freshness = cloudwatch.get_metric_statistics(
            Namespace='AWS/Kinesis/Firehose',
            MetricName='DeliveryToS3.DataFreshness',
            Dimensions=[
                {'Name': 'DeliveryStreamName', 'Value': 'o2-arena-motion-stream'}
            ],
            StartTime=start_time,
            EndTime=end_time,
            Period=300,
            Statistics=['Average']
        )
        
        if success['Datapoints']:
            success_rate = max(point['Average'] for point in success['Datapoints'])
        else:
            success_rate = 0
        
        if freshness['Datapoints']:
            avg_freshness = max(point['Average'] for point in freshness['Datapoints'])
        else:
            avg_freshness = 0
        
        print(f"Firehose Success Rate: {success_rate:.2f}")
        print(f"Data Freshness: {avg_freshness:.2f} seconds")
        
        # Health criteria: success rate > 95% and freshness < 900 seconds
        return success_rate > 0.95 and avg_freshness < 900
        
    except Exception as e:
        print(f"Firehose health check failed: {e}")
        return False

def check_recent_errors():
    """
    Check for recent errors in logs
    """
    try:
        logs_client = boto3.client('logs', region_name='us-west-1')
        
        # Check Lambda errors
        response = logs_client.filter_log_events(
            logGroupName='/aws/lambda/o2-arena-iot-data-processor',
            startTime=int((time.time() - 900) * 1000),  # Last 15 minutes
            filterPattern='ERROR'
        )
        
        error_count = len(response['events'])
        
        if error_count > 0:
            print(f"Recent Lambda errors: {error_count}")
            for event in response['events'][:5]:  # Show first 5 errors
                timestamp = datetime.fromtimestamp(event['timestamp'] / 1000)
                print(f"  {timestamp}: {event['message'][:100]}...")
        
        return error_count
        
    except Exception as e:
        print(f"Error log check failed: {e}")
        return 0

def main():
    """
    Main monitoring loop
    """
    while True:
        try:
            monitor_pipeline_health()
            print("\nWaiting 5 minutes for next check...")
            time.sleep(300)  # Check every 5 minutes
        except KeyboardInterrupt:
            print("\nMonitoring stopped by user")
            break
        except Exception as e:
            print(f"Monitoring error: {e}")
            time.sleep(60)  # Wait 1 minute before retrying

if __name__ == '__main__':
    main()
```

## Quick Reference Commands

### Essential Testing Commands
```bash
# Test IoT Core publishing
aws iot-data publish --topic "device/motion_sensor/data" --payload '{"device_id": "test_001", "ts": "2025-07-18T10:30:00Z", "latitude": 37.7749, "longitude": -122.4194, "motion_detected": true, "device_status": "online"}' --region us-west-1

# Test Lambda function
aws lambda invoke --function-name o2-arena-iot-data-processor --payload file://test_payload.json response.json --region us-west-1

# Check CloudWatch logs
aws logs describe-log-streams --log-group-name "/aws/lambda/o2-arena-iot-data-processor" --order-by LastEventTime --descending --max-items 1 --region us-west-1

# Test database connection
mysql -h 3.101.111.137 -u usr_iot_admin -p'dew4DL' -e "SELECT COUNT(*) FROM db_iot_smart_buildings.tbl_smart_motion_model_x"

# Check S3 contents
aws s3 ls s3://o2-arena-iot-data-bucket-9eby42ws --recursive --region us-west-1
```

### Base64 Encoding Commands
```bash
# Encode JSON to base64
echo '{"device_id": "test_001", "ts": "2025-07-18T10:30:00Z", "latitude": 37.7749, "longitude": -122.4194, "motion_detected": true, "device_status": "online"}' | base64

# Decode base64 to JSON
echo "BASE64_STRING" | base64 -d
```

## Conclusion

This comprehensive testing guide provides everything you need to validate your IoT pipeline:

- **Data Preparation**: JSON structure and test data creation
- **Base64 Encoding**: Understanding and implementing encoding/decoding
- **Component Testing**: Individual service testing
- **Integration Testing**: Service-to-service validation
- **End-to-End Testing**: Complete pipeline validation
- **Monitoring**: Continuous health checks and alerting

Use these scripts and procedures to ensure your IoT pipeline is robust, reliable, and ready for production workloads.

### Testing Checklist
- [ ] Test data preparation and base64 encoding
- [ ] IoT Core message publishing
- [ ] Firehose delivery verification
- [ ] Lambda function processing
- [ ] Database connectivity and insertion
- [ ] S3 storage verification
- [ ] End-to-end pipeline validation
- [ ] CloudWatch monitoring setup
- [ ] Error handling and recovery testing
- [ ] Performance and load testing

Follow this guide systematically to ensure comprehensive testing coverage of your IoT data pipeline.