# Module 3: Lambda Function for Data Processing

## Overview
This module covers creating a Lambda function that processes IoT data from Firehose and stores it in MySQL database. This is a comprehensive step-by-step guide for beginners.

## Lambda Function Role in IoT Pipeline
The Lambda function serves as the **data processor** in the pipeline:
- Receives batched data from Kinesis Data Firehose
- Decodes base64-encoded IoT messages
- Connects to MySQL database
- Inserts processed data into database tables
- Returns acknowledgment to Firehose for S3 storage

## Prerequisites
- AWS CLI configured with appropriate permissions
- Terraform installed (v1.12+)
- Python 3.9+ installed
- Basic understanding of Python and SQL

## Step 1: Python Virtual Environment Setup

### 1.1 Create Virtual Environment
```bash
# Navigate to your project directory
cd /path/to/your/project

# Create virtual environment
python -m venv .venv

# Activate virtual environment
# On Windows:
.venv\Scripts\activate

# On macOS/Linux:
source .venv/bin/activate
```

### 1.2 Verify Virtual Environment
```bash
# Check Python version
python --version

# Check pip version
pip --version

# Verify you're in virtual environment (should show .venv in path)
which python
```

## Step 2: Install Python Dependencies

### 2.1 Create Requirements File
Create a file named `requirements.txt` in your project directory:
```text
pymysql==1.0.2
boto3==1.26.137
botocore==1.29.137
```

### 2.2 Install Dependencies
```bash
# Install all dependencies
pip install -r requirements.txt

# Install individual packages (alternative method)
pip install pymysql boto3 botocore

# Verify installations
pip list
```

### 2.3 Generate Frozen Requirements (Optional)
```bash
# Generate exact versions for reproducibility
pip freeze > requirements-freeze.txt
```

## Step 3: Create Lambda Function Code

### 3.1 Create Lambda Function File
Create `lambda_function.py` in your project directory:

```python
import base64
import json
import pymysql
import logging
import os

# Logger settings
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Database configuration from environment variables
DB_HOST = '3.101.111.137'  # Replace with your EC2 instance IP
DB_NAME = 'db_iot_smart_buildings'
DB_USER = 'usr_iot_admin'
DB_PASSWORD = 'dew4DL'  # In production, use Secrets Manager

def lambda_handler(event, context):
    """
    Main Lambda handler function
    Processes IoT data from Kinesis Data Firehose
    """
    # Flag to ACK Firehose about successful processing
    output = []
    
    try:
        # Connect to MySQL database
        conn = pymysql.connect(
            host=DB_HOST,
            user=DB_USER,
            passwd=DB_PASSWORD,
            db=DB_NAME,
            connect_timeout=5
        )
        
        logger.info('Connected to database successfully')
        
        # Process each record from Firehose
        for record in event['records']:   
            try:
                # The data blob is base64-encoded when serialized
                payload = base64.b64decode(record['data']).decode('utf-8')
                
                # Parse JSON payload
                row = json.loads(payload)
                
                logger.info(f'Processing record: {row}')
                
                # Insert into database
                with conn.cursor() as cur:
                    # Build and execute DML statement
                    dml_stmt = '''insert into tbl_smart_motion_model_x 
                                 (device_id, ts, latitude, longitude, motion_detected, device_status) 
                                 values(%s, %s, %s, %s, %s, %s)'''
                    cur.execute(dml_stmt, (
                        row['device_id'], 
                        row['ts'], 
                        row['latitude'], 
                        row['longitude'], 
                        row['motion_detected'], 
                        row['device_status']
                    ))
                    
                conn.commit()
                logger.info(f'Successfully inserted record for device: {row["device_id"]}')
                
                # Send success signal back to Firehose
                output_record = {
                    'recordId': record['recordId'],
                    'result': 'Ok',
                    'data': record['data']
                }
                output.append(output_record)
                
            except Exception as e:
                logger.error(f'Error processing individual record: {e}')
                # Return processing failed for this record
                output_record = {
                    'recordId': record['recordId'],
                    'result': 'ProcessingFailed',
                    'data': record['data']
                }
                output.append(output_record)
        
        # Close database connection
        conn.close()
        
        # Return response to Firehose
        logger.info(f'Successfully processed {len(output)} records')
        return {'records': output}
        
    except pymysql.MySQLError as e:
        logger.error(f"Database error: {e}")
        # Return all records as failed
        return {
            'records': [
                {
                    'recordId': record['recordId'],
                    'result': 'ProcessingFailed',
                    'data': record['data']
                }
                for record in event['records']
            ]
        }
        
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        # Return all records as failed
        return {
            'records': [
                {
                    'recordId': record['recordId'],
                    'result': 'ProcessingFailed',
                    'data': record['data']
                }
                for record in event['records']
            ]
        }
```

### 3.2 Understanding the Lambda Function

**Key Components:**
- **Event Parameter**: Contains records from Firehose
- **Context Parameter**: Runtime information from Lambda
- **Base64 Decoding**: Firehose data is base64-encoded
- **Database Connection**: Direct MySQL connection
- **Error Handling**: Comprehensive exception handling
- **Return Format**: Specific format required by Firehose

## Step 4: Create Lambda Deployment Package

### 4.1 Create Minimal Package Directory
```bash
# Create directory for Lambda package
mkdir lambda_package_minimal

# Copy Lambda function
cp lambda_function.py lambda_package_minimal/
```

### 4.2 Copy Dependencies from Virtual Environment
```bash
# Find your virtual environment site-packages
# On Windows:
# .venv\Lib\site-packages\

# On macOS/Linux:
# .venv/lib/python3.x/site-packages/

# Copy pymysql (essential dependency)
cp -r .venv/lib/python3.*/site-packages/pymysql lambda_package_minimal/

# Verify package contents
ls -la lambda_package_minimal/
```

### 4.3 Alternative: Install Dependencies Directly
```bash
# Alternative method: Install directly to package directory
pip install pymysql -t lambda_package_minimal/
```

## Step 5: Create Terraform Configuration

### 5.1 Create lambda.tf File
Create `lambda.tf` with the following content:

```hcl
# --------------------
# Lambda Function for IoT Data Processing  
# --------------------

# Create a zip file for the Lambda function with all dependencies
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "lambda_package_minimal"
  output_path = "lambda_function.zip"
}

# IAM role for Lambda function
resource "aws_iam_role" "lambda_role" {
  name = "o2-arena-lambda-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM policy for Lambda function
resource "aws_iam_role_policy" "lambda_policy" {
  name = "o2-arena-lambda-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = aws_secretsmanager_secret.db_secret.arn
      }
    ]
  })
}

# Lambda function
resource "aws_lambda_function" "iot_data_processor" {
  filename      = "lambda_function.zip"
  function_name = "o2-arena-iot-data-processor"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"
  timeout       = 30

  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      db_secret_name = aws_secretsmanager_secret.db_secret.name
      region_name    = "us-west-1"
    }
  }

  depends_on = [
    aws_iam_role_policy.lambda_policy,
    aws_cloudwatch_log_group.lambda_logs,
  ]
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/o2-arena-iot-data-processor"
  retention_in_days = 14
}

# Secrets Manager for database credentials
resource "aws_secretsmanager_secret" "db_secret" {
  name                    = "db_credentials_iot_project"
  description             = "Database credentials for IoT project"
  recovery_window_in_days = 7
}

# Secret version with actual credentials
resource "aws_secretsmanager_secret_version" "db_secret_version" {
  secret_id = aws_secretsmanager_secret.db_secret.id
  secret_string = jsonencode({
    username = "usr_iot_admin"
    password = "dew4DL"
    host     = "3.101.111.137"
    dbname   = "db_iot_smart_buildings"
  })
}

# Outputs for reference
output "lambda_function_name" {
  value = aws_lambda_function.iot_data_processor.function_name
}

output "lambda_function_arn" {
  value = aws_lambda_function.iot_data_processor.arn
}
```

### 5.2 Understanding Terraform Resources

**Resource Breakdown:**
1. **data "archive_file"**: Creates zip package from source directory
2. **aws_iam_role**: Creates execution role for Lambda
3. **aws_iam_role_policy**: Attaches permissions to the role
4. **aws_lambda_function**: Creates the actual Lambda function
5. **aws_cloudwatch_log_group**: Creates log group for monitoring
6. **aws_secretsmanager_secret**: Stores database credentials securely

## Step 6: Deploy Lambda Function with Terraform

### 6.1 Initialize Terraform
```bash
# Initialize Terraform (first time only)
terraform init

# If you have existing configuration, upgrade providers
terraform init -upgrade
```

### 6.2 Plan the Deployment
```bash
# View what will be created
terraform plan

# Plan specific resources only
terraform plan -target=aws_lambda_function.iot_data_processor
```

### 6.3 Apply the Configuration
```bash
# Deploy all resources
terraform apply

# Deploy Lambda function only
terraform apply -target=aws_lambda_function.iot_data_processor -auto-approve
```

### 6.4 Verify Deployment
```bash
# Check if Lambda function exists
aws lambda list-functions --query "Functions[?FunctionName=='o2-arena-iot-data-processor']"

# Get function details
aws lambda get-function --function-name o2-arena-iot-data-processor
```

## Step 7: Test Lambda Function

### 7.1 Create Test Payload
Create `lambda_test_payload.json`:
```json
{
  "records": [
    {
      "recordId": "test123",
      "data": "eyJkZXZpY2VfaWQiOiAidGVzdF9kZXZpY2VfMDAxIiwgInRzIjogIjIwMjUtMDEtMThUMDQ6NTA6MDBaIiwgImxhdGl0dWRlIjogMzcuNzc0OSwgImxvbmdpdHVkZSI6IC0xMjIuNDE5NCwgIm1vdGlvbl9kZXRlY3RlZCI6IHRydWUsICJkZXZpY2Vfc3RhdHVzIjogIm9ubGluZSJ9"
    }
  ]
}
```

### 7.2 Test the Function
```bash
# Encode test payload
cat lambda_test_payload.json | base64 > lambda_test_payload_b64.txt

# Invoke Lambda function
aws lambda invoke \
  --function-name o2-arena-iot-data-processor \
  --payload file://lambda_test_payload_b64.txt \
  response.json

# Check response
cat response.json
```

### 7.3 Check CloudWatch Logs
```bash
# Get log streams
aws logs describe-log-streams \
  --log-group-name "/aws/lambda/o2-arena-iot-data-processor" \
  --order-by LastEventTime \
  --descending \
  --max-items 1

# Get log events (replace LOG_STREAM_NAME with actual name)
aws logs get-log-events \
  --log-group-name "/aws/lambda/o2-arena-iot-data-processor" \
  --log-stream-name "LOG_STREAM_NAME"
```

## Step 8: Troubleshooting Common Issues

### 8.1 Import Module Errors
**Problem**: `Unable to import module 'lambda_function'`
**Solution**: 
- Verify dependencies are in the package directory
- Check file permissions
- Ensure Python version compatibility

### 8.2 Database Connection Issues
**Problem**: `Connection refused` or `Connection timeout`
**Solution**:
- Verify database is running
- Check security groups allow Lambda access
- Verify database credentials
- Check network connectivity

### 8.3 Package Size Issues
**Problem**: Lambda package too large
**Solution**:
- Use only essential dependencies
- Remove unnecessary files
- Consider Lambda layers for large dependencies

### 8.4 Permission Denied Errors
**Problem**: `AccessDenied` for various AWS services
**Solution**:
- Verify IAM permissions
- Check resource ARNs in policies
- Ensure proper role trust relationships

## Step 9: Best Practices

### 9.1 Code Organization
- Keep Lambda function code modular
- Use environment variables for configuration
- Implement proper error handling
- Add comprehensive logging

### 9.2 Security
- Use Secrets Manager for credentials
- Follow principle of least privilege
- Avoid hardcoded sensitive information
- Regular security audits

### 9.3 Performance
- Optimize package size
- Use connection pooling for databases
- Monitor execution time and memory usage
- Implement appropriate timeout values

### 9.4 Monitoring
- Set up CloudWatch alarms
- Monitor error rates
- Track execution duration
- Implement custom metrics

## Step 10: Understanding Dependencies

### 10.1 Why We Need Each Package
- **pymysql**: MySQL database connector for Python
- **boto3**: AWS SDK for Python (if using Secrets Manager)
- **botocore**: Core functionality for boto3

### 10.2 Package Size Considerations
- Lambda has 50MB zipped package limit
- 250MB unzipped limit
- Keep packages minimal for faster cold starts

### 10.3 Dependency Management
- Use virtual environments for isolation
- Pin specific versions for reproducibility
- Regular dependency updates for security

## Next Steps
After completing this module, you should have:
- A working Python virtual environment
- Lambda function with proper dependencies
- Terraform configuration for deployment
- Understanding of the deployment process

Proceed to Module 4 to create the Kinesis Data Firehose stream that will invoke this Lambda function.

## Additional Resources
- [AWS Lambda Developer Guide](https://docs.aws.amazon.com/lambda/latest/dg/)
- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [PyMySQL Documentation](https://pymysql.readthedocs.io/)
- [Python Virtual Environments Guide](https://docs.python.org/3/tutorial/venv.html)