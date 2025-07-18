# Module 5: IoT Core Rule Configuration

## Overview
This module covers creating an IoT Core rule that captures device messages and routes them to the Kinesis Data Firehose stream, completing the data ingestion part of the pipeline.

## IoT Rule Role in Pipeline
The IoT Core rule acts as the **data entry point** for the pipeline:
- Listens for messages on specific MQTT topics
- Filters and processes incoming IoT data
- Routes messages to downstream services (Firehose)
- Provides message routing and transformation capabilities
- Enables device-to-cloud communication

## IoT Core Architecture

### Message Flow
```
IoT Devices → MQTT Broker → IoT Rule → Firehose Stream
                                   ↓
                            Rule Engine Processing
```

### Topic Structure
- **Topic**: `/iot-o2-arena-motion`
- **Message Format**: JSON with device telemetry
- **Frequency**: Real-time device updates

## Terraform Configuration Analysis

### 1. IoT Rule IAM Role
```hcl
resource "aws_iam_role" "iot_rule_role" {
  name = "o2-arena-iot-rule-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "iot.amazonaws.com"
        }
      }
    ]
  })
}
```

**Trust Relationship:**
- **Service Principal**: `iot.amazonaws.com`
- **Purpose**: Allows IoT Core service to assume this role
- **Scope**: Limited to IoT Core operations

### 2. IoT Rule IAM Policy
```hcl
resource "aws_iam_role_policy" "iot_rule_policy" {
  name = "o2-arena-iot-rule-policy"
  role = aws_iam_role.iot_rule_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "firehose:PutRecord",
          "firehose:PutRecordBatch"
        ]
        Resource = aws_kinesis_firehose_delivery_stream.o2_arena_stream.arn
      }
    ]
  })
}
```

**Permission Breakdown:**
- **firehose:PutRecord**: Send individual records to Firehose
- **firehose:PutRecordBatch**: Send multiple records efficiently
- **Resource-Specific**: Limited to our specific Firehose stream
- **Minimal Permissions**: Only what's needed for data delivery

### 3. IoT Topic Rule
```hcl
resource "aws_iot_topic_rule" "o2_arena_motion_rule" {
  name        = "O2ArenaMotionRule"
  description = "Rule to process IoT motion data from O2 Arena devices"
  enabled     = true
  sql         = "SELECT * FROM '/iot-o2-arena-motion'"
  sql_version = "2016-03-23"

  firehose {
    delivery_stream_name = aws_kinesis_firehose_delivery_stream.o2_arena_stream.name
    role_arn            = aws_iam_role.iot_rule_role.arn
    separator           = "\n"
    batch_mode          = false
  }
}
```

**Configuration Details:**

#### Rule Properties
- **name**: Unique identifier for the rule
- **description**: Human-readable rule purpose
- **enabled**: Rule activation status
- **sql**: SQL query to filter messages
- **sql_version**: IoT SQL version for compatibility

#### SQL Query Analysis
```sql
SELECT * FROM '/iot-o2-arena-motion'
```
- **SELECT \***: Pass all message fields
- **FROM**: Listen to specific MQTT topic
- **Topic**: `/iot-o2-arena-motion` for motion sensor data

#### Firehose Action
- **delivery_stream_name**: Target Firehose stream
- **role_arn**: IAM role for permissions
- **separator**: Line separator for records
- **batch_mode**: Individual record processing

## IoT Message Structure

### Expected Message Format
```json
{
  "device_id": "motion_sensor_001",
  "timestamp": "2024-01-15T10:30:00Z",
  "latitude": 37.7749,
  "longitude": -122.4194,
  "motion_detected": true,
  "device_status": "online"
}
```

### Message Processing Flow
1. **Device Publishes**: Message sent to MQTT topic
2. **Rule Engine**: Evaluates SQL query
3. **Action Triggered**: If query matches, execute action
4. **Firehose Delivery**: Message sent to Firehose stream

## Step-by-Step Deployment

### 1. Deploy IoT Rule
```bash
# The IoT rule is part of firehose.tf
terraform apply -auto-approve
```

### 2. Verify Rule Creation
```bash
# List IoT rules
aws iot list-topic-rules

# Get rule details
aws iot get-topic-rule --rule-name O2ArenaMotionRule
```

### 3. Test Rule (Optional)
```bash
# Publish test message
aws iot-data publish \
  --topic "/iot-o2-arena-motion" \
  --payload '{
    "device_id": "test_device_001",
    "timestamp": "2024-01-15T10:30:00Z",
    "latitude": 37.7749,
    "longitude": -122.4194,
    "motion_detected": true,
    "device_status": "online"
  }'
```

## Advanced SQL Queries

### 1. Filtering Messages
```sql
-- Only process motion detected events
SELECT * FROM '/iot-o2-arena-motion' WHERE motion_detected = true

-- Filter by device status
SELECT * FROM '/iot-o2-arena-motion' WHERE device_status = 'online'

-- Time-based filtering
SELECT * FROM '/iot-o2-arena-motion' WHERE timestamp > '2024-01-01T00:00:00Z'
```

### 2. Message Transformation
```sql
-- Add processing timestamp
SELECT *, timestamp() as processed_at FROM '/iot-o2-arena-motion'

-- Extract specific fields
SELECT device_id, motion_detected, timestamp FROM '/iot-o2-arena-motion'

-- Add calculated fields
SELECT *, 
       (latitude + longitude) as geo_sum,
       upper(device_status) as status_upper 
FROM '/iot-o2-arena-motion'
```

### 3. Multiple Topic Patterns
```sql
-- Listen to multiple topics
SELECT * FROM '/iot-o2-arena-motion' 
UNION
SELECT * FROM '/iot-o2-arena-temperature'

-- Wildcard topic matching
SELECT * FROM '/iot-o2-arena/+'
```

## Monitoring and Troubleshooting

### 1. CloudWatch Metrics
Key IoT rule metrics:
- `RuleMessageCount`: Messages processed by rule
- `RuleNotFoundErrorCount`: Messages to non-existent rules
- `ParseErrorCount`: Malformed message errors
- `Success`: Successful rule executions

### 2. Rule Execution Logs
```bash
# Enable rule logging (if not already enabled)
aws logs create-log-group --log-group-name /aws/iot/rules

# Monitor rule execution
aws logs filter-log-events \
  --log-group-name "/aws/iot/rules" \
  --filter-pattern "O2ArenaMotionRule"
```

### 3. Common Issues and Solutions

#### Rule Not Triggering
```bash
# Check rule status
aws iot get-topic-rule --rule-name O2ArenaMotionRule

# Verify topic subscription
aws iot-data publish --topic "/iot-o2-arena-motion" --payload '{"test": true}'
```

#### Permission Errors
```bash
# Check IAM role permissions
aws iam get-role-policy \
  --role-name o2-arena-iot-rule-role \
  --policy-name o2-arena-iot-rule-policy

# Verify Firehose stream exists
aws firehose describe-delivery-stream \
  --delivery-stream-name o2-arena-motion-stream
```

#### Message Format Issues
```bash
# Check Lambda logs for processing errors
aws logs filter-log-events \
  --log-group-name "/aws/lambda/o2-arena-iot-data-processor" \
  --filter-pattern "ERROR"
```

## Security Considerations

### 1. Device Authentication
- **X.509 Certificates**: Authenticate IoT devices
- **AWS IoT Device Defender**: Monitor device behavior
- **Thing Registry**: Manage device identities

### 2. Message Security
- **TLS Encryption**: All MQTT connections encrypted
- **Message Signing**: Verify message integrity
- **Topic Policies**: Control topic access

### 3. Rule Security
- **IAM Roles**: Minimal permissions for rule execution
- **Resource Policies**: Additional access controls
- **Audit Logging**: CloudTrail for rule changes

## Performance Optimization

### 1. SQL Query Optimization
```sql
-- Efficient filtering
SELECT device_id, motion_detected 
FROM '/iot-o2-arena-motion' 
WHERE motion_detected = true

-- Avoid complex transformations in SQL
-- Use Lambda for complex processing instead
```

### 2. Batch Processing
- **batch_mode**: Enable for high-throughput scenarios
- **Trade-off**: Latency vs. throughput
- **Monitoring**: Watch for batch processing delays

### 3. Error Handling
- **Error Actions**: Configure fallback actions
- **Dead Letter Queues**: Handle persistent failures
- **Retry Logic**: Built-in retry mechanisms

## Cost Optimization

### 1. Message Filtering
- **Efficient SQL**: Filter at IoT Core level
- **Reduce Downstream**: Fewer Firehose records
- **Cost Impact**: Reduced Lambda invocations

### 2. Topic Strategy
- **Specific Topics**: Use precise topic patterns
- **Avoid Wildcards**: Unless necessary for functionality
- **Message Size**: Keep messages concise

## Next Steps
Proceed to Module 6 for a comprehensive overview of all IAM policies and roles used in the pipeline.