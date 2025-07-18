# Module 4: Kinesis Data Firehose Stream

## Overview
This module covers creating a Kinesis Data Firehose delivery stream that serves as the backbone of the IoT data pipeline, buffering and routing data to Lambda and S3.

## Firehose Role in IoT Pipeline
Kinesis Data Firehose acts as the **data highway** in the pipeline:
- Receives real-time IoT data from IoT Core rules
- Buffers incoming data for efficient processing
- Invokes Lambda function for data transformation
- Delivers processed data to S3 for long-term storage
- Provides built-in compression and error handling

## Terraform Configuration Analysis

### 1. Firehose IAM Role
```hcl
resource "aws_iam_role" "firehose_role" {
  name = "o2-arena-firehose-delivery-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "firehose.amazonaws.com"
        }
      }
    ]
  })
}
```

**Trust Relationship:**
- **Service Principal**: `firehose.amazonaws.com`
- **Purpose**: Allows Firehose service to assume this role
- **Scope**: Limited to Firehose operations only

### 2. Firehose IAM Policy
```hcl
resource "aws_iam_role_policy" "firehose_policy" {
  name = "o2-arena-firehose-policy"
  role = aws_iam_role.firehose_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:PutObject"
        ]
        Resource = [
          aws_s3_bucket.o2_arena_bucket.arn,
          "${aws_s3_bucket.o2_arena_bucket.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction",
          "lambda:GetFunctionConfiguration"
        ]
        Resource = aws_lambda_function.iot_data_processor.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}
```

**Permission Breakdown:**
- **S3 Permissions**: Write data to specific bucket
- **Lambda Permissions**: Invoke data processing function
- **CloudWatch Logs**: Write delivery logs
- **Resource-Specific**: Scoped to exact resources needed

### 3. Firehose Delivery Stream
```hcl
resource "aws_kinesis_firehose_delivery_stream" "o2_arena_stream" {
  name        = "o2-arena-motion-stream"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn           = aws_iam_role.firehose_role.arn
    bucket_arn         = aws_s3_bucket.o2_arena_bucket.arn
    prefix             = "o2-arena-motion/"
    error_output_prefix = "errors/"
    compression_format = "GZIP"
    
    buffering_size     = 1
    buffering_interval = 60

    processing_configuration {
      enabled = true

      processors {
        type = "Lambda"

        parameters {
          parameter_name  = "LambdaArn"
          parameter_value = aws_lambda_function.iot_data_processor.arn
        }
      }
    }
  }
}
```

**Configuration Details:**

#### Destination Configuration
- **extended_s3**: Enhanced S3 destination with more features
- **prefix**: Organizes data by source (`o2-arena-motion/`)
- **error_output_prefix**: Separate location for failed records
- **compression_format**: GZIP for storage efficiency

#### Buffering Configuration
- **buffering_size**: 1MB buffer size
- **buffering_interval**: 60 seconds maximum wait time
- **Purpose**: Batches data for efficient processing

#### Processing Configuration
- **enabled**: Activates Lambda data transformation
- **type**: Lambda processor type
- **LambdaArn**: Target Lambda function for processing

### 4. Lambda Permission for Firehose
```hcl
resource "aws_lambda_permission" "firehose_lambda_permission" {
  statement_id  = "AllowExecutionFromFirehose"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.iot_data_processor.function_name
  principal     = "firehose.amazonaws.com"
  source_arn    = aws_kinesis_firehose_delivery_stream.o2_arena_stream.arn
}
```

**Cross-Service Permission:**
- **Allows**: Firehose to invoke Lambda function
- **source_arn**: Specific Firehose stream only
- **Principle of Least Privilege**: Limited to specific stream

## Data Flow Through Firehose

### 1. Data Ingestion
```
IoT Core Rule → Firehose Stream → Buffer
```

### 2. Data Processing
```
Buffer → Lambda Function → Database Storage
                        ↓
                   Return to Firehose
```

### 3. Data Delivery
```
Processed Data → S3 Bucket → Compressed Storage
```

## Step-by-Step Deployment

### 1. Create Firehose Configuration
```bash
# Create firehose.tf with the above configuration
vi firehose.tf
```

### 2. Plan Firehose Deployment
```bash
terraform plan -target=aws_kinesis_firehose_delivery_stream.o2_arena_stream
```

### 3. Deploy Firehose Stream
```bash
terraform apply -target=aws_kinesis_firehose_delivery_stream.o2_arena_stream -auto-approve
```

### 4. Verify Creation
```bash
# List Firehose streams
aws firehose list-delivery-streams

# Get stream details
aws firehose describe-delivery-stream \
  --delivery-stream-name o2-arena-motion-stream
```

## Monitoring and Troubleshooting

### 1. CloudWatch Metrics
Key metrics to monitor:
- `DeliveryToS3.Records`
- `DeliveryToS3.Success`
- `ProcessingToLambda.Records`
- `ProcessingToLambda.Success`

### 2. Error Handling
```bash
# Check error logs
aws logs describe-log-groups \
  --log-group-name-prefix "/aws/kinesis/firehose"

# Monitor Lambda errors
aws logs filter-log-events \
  --log-group-name "/aws/lambda/o2-arena-iot-data-processor" \
  --filter-pattern "ERROR"
```

### 3. Common Issues
1. **Lambda Timeout**: Increase Lambda timeout or optimize code
2. **S3 Access Denied**: Verify IAM permissions
3. **Processing Failures**: Check Lambda function logs

## Performance Optimization

### 1. Buffering Strategy
```hcl
# Optimize for your use case
buffering_size     = 1    # 1MB for small records
buffering_interval = 60   # 60 seconds for near real-time

# For high-throughput:
# buffering_size     = 128  # 128MB
# buffering_interval = 900  # 15 minutes
```

### 2. Compression
- **GZIP**: Good balance of compression and speed
- **Storage Cost**: ~70% reduction in S3 storage costs
- **Processing**: Automatic decompression in analytics tools

### 3. Error Handling
- **Retry Logic**: Built-in retry for transient failures
- **Error Records**: Separate storage for failed records
- **Dead Letter Queue**: Consider for persistent failures

## Security Best Practices

### 1. Encryption
- **In-Transit**: TLS encryption for all data transfers
- **At-Rest**: S3 server-side encryption
- **Key Management**: AWS managed keys (SSE-S3)

### 2. Access Control
- **IAM Roles**: Service-specific roles with minimal permissions
- **Resource Policies**: Bucket policies for additional security
- **VPC Endpoints**: Private connectivity (if needed)

### 3. Monitoring
- **CloudTrail**: Log all API calls
- **CloudWatch**: Monitor performance and errors
- **Alerts**: Set up alerts for failures

## Cost Optimization

### 1. Data Compression
- **GZIP Compression**: Reduces storage costs by ~70%
- **Transfer Costs**: Reduced data transfer charges

### 2. Buffering Optimization
- **Larger Buffers**: Fewer S3 PUT operations
- **Cost Trade-off**: Storage efficiency vs. latency

### 3. Error Management
- **Failed Records**: Monitor and fix to avoid storage costs
- **Processing Efficiency**: Optimize Lambda to reduce invocations

## Next Steps
Proceed to Module 5 to create the IoT Core rule that feeds data into Firehose.