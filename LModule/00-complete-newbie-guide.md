# Complete Newbie Guide: Lambda Function with Terraform

## Overview
This comprehensive guide walks you through creating a Lambda function for IoT data processing from scratch. No prior experience with Lambda or Terraform is assumed.

## What You'll Build
A complete IoT data processing pipeline component that:
- Processes IoT sensor data from Kinesis Data Firehose
- Stores processed data in a MySQL database
- Handles errors gracefully
- Provides monitoring through CloudWatch

## Prerequisites Checklist

### System Requirements
- [ ] Computer with Windows, macOS, or Linux
- [ ] Internet connection
- [ ] Text editor (VS Code recommended)
- [ ] Terminal/Command Prompt access

### Software Installation
- [ ] Python 3.9 or higher
- [ ] AWS CLI installed and configured
- [ ] Terraform installed (v1.12+)
- [ ] Git (optional but recommended)

### AWS Account Setup
- [ ] AWS account with appropriate permissions
- [ ] AWS CLI configured with access keys
- [ ] Basic understanding of AWS services

## Part 1: Understanding the Architecture

### 1.1 Component Overview
```
IoT Devices → IoT Core → Firehose → Lambda Function → MySQL Database
                    ↓                      ↓
                  S3 Bucket          CloudWatch Logs
```

### 1.2 Lambda Function Role
Your Lambda function is the **brain** of the pipeline:
- **Input**: Receives data from Kinesis Data Firehose
- **Processing**: Decodes, validates, and transforms data
- **Output**: Stores data in MySQL database
- **Feedback**: Tells Firehose if processing succeeded or failed

### 1.3 Why Use Terraform?
- **Infrastructure as Code**: Define AWS resources in code
- **Version Control**: Track changes to infrastructure
- **Reproducibility**: Create identical environments
- **Automation**: Deploy with single command

## Part 2: Setting Up Your Development Environment

### 2.1 Create Project Directory
```bash
# Create main project directory
mkdir iot-lambda-project
cd iot-lambda-project

# Create subdirectories for organization
mkdir docs
mkdir terraform
mkdir src
```

### 2.2 Python Virtual Environment Setup

#### What is a Virtual Environment?
A virtual environment is an isolated Python environment that:
- Keeps project dependencies separate
- Prevents conflicts between different projects
- Ensures consistent package versions

#### Create Virtual Environment
```bash
# Create virtual environment
python -m venv .venv

# Activate virtual environment
# On Windows:
.venv\Scripts\activate

# On macOS/Linux:
source .venv/bin/activate

# Verify activation (should show (.venv) in prompt)
which python
```

#### Install Required Packages
```bash
# Create requirements.txt file
cat > requirements.txt << EOF
pymysql==1.0.2
boto3==1.26.137
botocore==1.29.137
EOF

# Install packages
pip install -r requirements.txt

# Verify installation
pip list
```

## Part 3: Creating the Lambda Function

### 3.1 Understanding Lambda Function Structure

#### Basic Lambda Function Template
```python
def lambda_handler(event, context):
    """
    This is the main function that AWS Lambda calls
    
    Args:
        event: Input data from the trigger (Firehose in our case)
        context: Runtime information from Lambda
    
    Returns:
        Response in format expected by the trigger
    """
    # Your code here
    return {"statusCode": 200, "body": "Success"}
```

### 3.2 Create Lambda Function Code

Create `src/lambda_function.py`:

```python
import base64
import json
import pymysql
import logging
import os

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Database configuration
# Note: In production, use AWS Secrets Manager instead of hardcoded values
DB_HOST = '3.101.111.137'  # Replace with your database host
DB_NAME = 'db_iot_smart_buildings'
DB_USER = 'usr_iot_admin'
DB_PASSWORD = 'dew4DL'  # Replace with your password

def lambda_handler(event, context):
    """
    Main Lambda handler function
    Processes IoT data from Kinesis Data Firehose
    
    Args:
        event: Contains 'records' array from Firehose
        context: Lambda runtime information
    
    Returns:
        dict: Response with processed records status
    """
    logger.info("Lambda function started")
    logger.info(f"Received {len(event.get('records', []))} records")
    
    output = []
    
    try:
        # Step 1: Connect to MySQL database
        logger.info("Connecting to database...")
        conn = pymysql.connect(
            host=DB_HOST,
            user=DB_USER,
            passwd=DB_PASSWORD,
            db=DB_NAME,
            connect_timeout=5,
            charset='utf8mb4'
        )
        logger.info("Database connection successful")
        
        # Step 2: Process each record from Firehose
        for record in event['records']:
            try:
                # Step 2a: Decode the base64-encoded data
                encoded_data = record['data']
                decoded_data = base64.b64decode(encoded_data).decode('utf-8')
                logger.info(f"Decoded data: {decoded_data}")
                
                # Step 2b: Parse JSON data
                json_data = json.loads(decoded_data)
                logger.info(f"Parsed JSON: {json_data}")
                
                # Step 2c: Validate required fields
                required_fields = ['device_id', 'ts', 'latitude', 'longitude', 'motion_detected', 'device_status']
                for field in required_fields:
                    if field not in json_data:
                        raise ValueError(f"Missing required field: {field}")
                
                # Step 2d: Insert into database
                with conn.cursor() as cursor:
                    sql = """
                    INSERT INTO tbl_smart_motion_model_x 
                    (device_id, ts, latitude, longitude, motion_detected, device_status) 
                    VALUES (%s, %s, %s, %s, %s, %s)
                    """
                    cursor.execute(sql, (
                        json_data['device_id'],
                        json_data['ts'],
                        json_data['latitude'],
                        json_data['longitude'],
                        json_data['motion_detected'],
                        json_data['device_status']
                    ))
                
                # Commit the transaction
                conn.commit()
                logger.info(f"Successfully processed record for device: {json_data['device_id']}")
                
                # Step 2e: Mark record as successfully processed
                output.append({
                    'recordId': record['recordId'],
                    'result': 'Ok',
                    'data': record['data']
                })
                
            except Exception as e:
                logger.error(f"Error processing record {record['recordId']}: {str(e)}")
                # Mark record as failed
                output.append({
                    'recordId': record['recordId'],
                    'result': 'ProcessingFailed',
                    'data': record['data']
                })
        
        # Step 3: Close database connection
        conn.close()
        logger.info("Database connection closed")
        
        # Step 4: Return results to Firehose
        logger.info(f"Processed {len(output)} records")
        return {'records': output}
        
    except Exception as e:
        logger.error(f"Critical error in lambda_handler: {str(e)}")
        
        # Return all records as failed if we can't process any
        return {
            'records': [
                {
                    'recordId': record['recordId'],
                    'result': 'ProcessingFailed',
                    'data': record['data']
                }
                for record in event.get('records', [])
            ]
        }
```

### 3.3 Understanding the Code

#### Key Concepts:
1. **Base64 Decoding**: Firehose sends data encoded in base64
2. **JSON Parsing**: IoT data is in JSON format
3. **Database Transaction**: Changes are committed only if successful
4. **Error Handling**: Failed records are marked for retry/dead letter queue
5. **Logging**: CloudWatch logs help with debugging

## Part 4: Creating the Deployment Package

### 4.1 Why Do We Need a Deployment Package?
Lambda functions run in a managed environment without our local dependencies. We need to package our code with its dependencies.

### 4.2 Create Deployment Package
```bash
# Create package directory
mkdir lambda_package

# Copy Lambda function
cp src/lambda_function.py lambda_package/

# Copy dependencies from virtual environment
# Find your Python version first
python --version

# Copy pymysql (adjust path for your Python version)
cp -r .venv/lib/python3.*/site-packages/pymysql lambda_package/

# Verify package structure
ls -la lambda_package/
```

### 4.3 Alternative: Install Dependencies Directly
```bash
# Install dependencies directly to package directory
pip install pymysql -t lambda_package/

# This method is simpler but less controlled
```

## Part 5: Creating Terraform Configuration

### 5.1 Understanding Terraform Structure

#### What is Terraform?
Terraform is a tool that lets you define cloud infrastructure using code. Instead of clicking through AWS console, you write configuration files that describe what you want.

#### Basic Terraform File Structure:
```hcl
# Resource definition
resource "aws_service_resource" "logical_name" {
  # Configuration parameters
  parameter1 = "value1"
  parameter2 = "value2"
}

# Data source (existing resource)
data "aws_service_data" "logical_name" {
  # Query parameters
}

# Output values
output "output_name" {
  value = resource.aws_service_resource.logical_name.attribute
}
```

### 5.2 Create Terraform Configuration

Create `terraform/lambda.tf`:

```hcl
# ============================================
# Lambda Function for IoT Data Processing
# ============================================

# Provider configuration
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-west-1"  # Change to your preferred region
}

# ============================================
# 1. Create deployment package
# ============================================

# This creates a zip file from your Lambda package directory
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "../lambda_package"  # Path to your package directory
  output_path = "lambda_function.zip"
}

# ============================================
# 2. IAM Role for Lambda Function
# ============================================

# Lambda needs permission to assume a role
resource "aws_iam_role" "lambda_role" {
  name = "iot-lambda-execution-role"

  # Trust policy: who can assume this role
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

  tags = {
    Name = "IoT Lambda Execution Role"
    Purpose = "Lambda function execution"
  }
}

# ============================================
# 3. IAM Policy for Lambda Function
# ============================================

# Define what the Lambda function can do
resource "aws_iam_role_policy" "lambda_policy" {
  name = "iot-lambda-policy"
  role = aws_iam_role.lambda_role.id

  # Permission policy: what this role can do
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # CloudWatch Logs permissions
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        # Secrets Manager permissions (for database credentials)
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = aws_secretsmanager_secret.db_secret.arn
      },
      {
        # VPC permissions (if your Lambda needs to access VPC resources)
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ]
        Resource = "*"
      }
    ]
  })
}

# ============================================
# 4. CloudWatch Log Group
# ============================================

# Create log group for Lambda function
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/iot-data-processor"
  retention_in_days = 14

  tags = {
    Name = "IoT Lambda Logs"
    Purpose = "Lambda function logging"
  }
}

# ============================================
# 5. Secrets Manager (for database credentials)
# ============================================

# Create secret for database credentials
resource "aws_secretsmanager_secret" "db_secret" {
  name                    = "iot-database-credentials"
  description             = "Database credentials for IoT Lambda function"
  recovery_window_in_days = 7

  tags = {
    Name = "IoT Database Credentials"
    Purpose = "Lambda database access"
  }
}

# Store the actual secret values
resource "aws_secretsmanager_secret_version" "db_secret_version" {
  secret_id = aws_secretsmanager_secret.db_secret.id
  secret_string = jsonencode({
    host     = "3.101.111.137"  # Replace with your database host
    username = "usr_iot_admin"
    password = "dew4DL"         # Replace with your password
    database = "db_iot_smart_buildings"
  })
}

# ============================================
# 6. Lambda Function
# ============================================

# Create the actual Lambda function
resource "aws_lambda_function" "iot_data_processor" {
  # Basic configuration
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "iot-data-processor"
  role            = aws_iam_role.lambda_role.arn
  handler         = "lambda_function.lambda_handler"
  runtime         = "python3.9"
  timeout         = 30
  memory_size     = 128

  # This ensures Lambda updates when code changes
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  # Environment variables
  environment {
    variables = {
      DB_SECRET_NAME = aws_secretsmanager_secret.db_secret.name
      AWS_REGION     = "us-west-1"
    }
  }

  # Dependencies (ensures resources are created in correct order)
  depends_on = [
    aws_iam_role_policy.lambda_policy,
    aws_cloudwatch_log_group.lambda_logs
  ]

  tags = {
    Name = "IoT Data Processor"
    Purpose = "Process IoT sensor data"
  }
}

# ============================================
# 7. Outputs (useful information after deployment)
# ============================================

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.iot_data_processor.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.iot_data_processor.arn
}

output "lambda_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_role.arn
}

output "secret_arn" {
  description = "ARN of the database secret"
  value       = aws_secretsmanager_secret.db_secret.arn
}
```

### 5.3 Understanding Each Terraform Resource

#### 1. Data Source (archive_file)
- **Purpose**: Creates a zip file from your code
- **Why needed**: Lambda requires code in zip format
- **What it does**: Packages your code and dependencies

#### 2. IAM Role (aws_iam_role)
- **Purpose**: Defines who can assume this role
- **Why needed**: Lambda needs permission to run
- **What it does**: Creates identity for Lambda service

#### 3. IAM Policy (aws_iam_role_policy)
- **Purpose**: Defines what the role can do
- **Why needed**: Lambda needs specific permissions
- **What it does**: Grants CloudWatch, Secrets Manager, and VPC access

#### 4. CloudWatch Log Group (aws_cloudwatch_log_group)
- **Purpose**: Centralized logging for Lambda
- **Why needed**: Debugging and monitoring
- **What it does**: Stores function logs with retention policy

#### 5. Secrets Manager (aws_secretsmanager_secret)
- **Purpose**: Secure storage for database credentials
- **Why needed**: Security best practice
- **What it does**: Stores encrypted database credentials

#### 6. Lambda Function (aws_lambda_function)
- **Purpose**: The actual serverless function
- **Why needed**: Core component of the pipeline
- **What it does**: Processes IoT data

## Part 6: Deployment Process

### 6.1 Initialize Terraform
```bash
cd terraform

# Initialize Terraform (downloads providers)
terraform init

# Verify initialization
ls -la .terraform/
```

### 6.2 Plan the Deployment
```bash
# See what will be created
terraform plan

# Save plan to file (optional)
terraform plan -out=tfplan
```

### 6.3 Deploy the Infrastructure
```bash
# Deploy everything
terraform apply

# Or apply saved plan
terraform apply tfplan

# Type 'yes' when prompted
```

### 6.4 Verify Deployment
```bash
# Check if Lambda function exists
aws lambda list-functions --query "Functions[?FunctionName=='iot-data-processor']"

# Get function configuration
aws lambda get-function-configuration --function-name iot-data-processor

# Test the function
aws lambda invoke --function-name iot-data-processor --payload '{"records":[]}' response.json
```

## Part 7: Testing Your Lambda Function

### 7.1 Create Test Data
Create `test_data.json`:
```json
{
  "records": [
    {
      "recordId": "test-001",
      "data": "eyJkZXZpY2VfaWQiOiAidGVzdF9kZXZpY2VfMDAxIiwgInRzIjogIjIwMjUtMDctMThUMDY6MDA6MDBaIiwgImxhdGl0dWRlIjogMzcuNzc0OSwgImxvbmdpdHVkZSI6IC0xMjIuNDE5NCwgIm1vdGlvbl9kZXRlY3RlZCI6IHRydWUsICJkZXZpY2Vfc3RhdHVzIjogIm9ubGluZSJ9"
    }
  ]
}
```

### 7.2 Test the Function
```bash
# Test with sample data
aws lambda invoke --function-name iot-data-processor --payload file://test_data.json response.json

# Check response
cat response.json
```

### 7.3 Check Logs
```bash
# Get latest log stream
aws logs describe-log-streams --log-group-name "/aws/lambda/iot-data-processor" --order-by LastEventTime --descending --max-items 1

# View logs (replace LOG_STREAM_NAME with actual value)
aws logs get-log-events --log-group-name "/aws/lambda/iot-data-processor" --log-stream-name "LOG_STREAM_NAME"
```

## Part 8: Troubleshooting Common Issues

### 8.1 Permission Errors
**Error**: `AccessDenied` when deploying
**Solution**:
- Check AWS CLI credentials: `aws sts get-caller-identity`
- Verify IAM permissions for Terraform
- Check region settings

### 8.2 Lambda Function Import Errors
**Error**: `Unable to import module 'lambda_function'`
**Solution**:
- Verify file structure in package directory
- Check Python version compatibility
- Ensure dependencies are included

### 8.3 Database Connection Issues
**Error**: `Connection refused` or timeout
**Solution**:
- Check database is running
- Verify security groups allow Lambda access
- Check VPC configuration if using VPC
- Verify credentials in Secrets Manager

### 8.4 Terraform Errors
**Error**: `Resource already exists`
**Solution**:
- Check if resources exist in AWS console
- Import existing resources: `terraform import`
- Use different resource names

## Part 9: Understanding Resource Dependencies

### 9.1 Dependency Graph
```
Secrets Manager ←─────────────────────┐
      ↓                               │
IAM Role ←─────────────────────────────┼─── Lambda Function
      ↓                               │
IAM Policy ←──────────────────────────┤
      ↓                               │
CloudWatch Log Group ←────────────────┤
      ↓                               │
Archive File (zip) ←──────────────────┘
```

### 9.2 Why Dependencies Matter
- **IAM Role**: Must exist before Lambda function
- **IAM Policy**: Must be attached to role before Lambda function
- **CloudWatch Log Group**: Should exist before Lambda function
- **Archive File**: Must be created before Lambda function
- **Secrets Manager**: Must exist before Lambda function

### 9.3 Terraform Handles Dependencies
- Terraform automatically determines order based on resource references
- Use `depends_on` for explicit dependencies
- Use `terraform graph` to visualize dependencies

## Part 10: Best Practices and Next Steps

### 10.1 Security Best Practices
1. **Use Secrets Manager**: Never hardcode credentials
2. **Least Privilege**: Grant minimal required permissions
3. **Environment Variables**: Use for configuration
4. **VPC**: Consider running Lambda in VPC for database access
5. **Encryption**: Enable encryption at rest and in transit

### 10.2 Monitoring and Logging
1. **CloudWatch Metrics**: Monitor function performance
2. **CloudWatch Alarms**: Set up alerts for errors
3. **Structured Logging**: Use consistent log format
4. **Tracing**: Consider AWS X-Ray for distributed tracing

### 10.3 Performance Optimization
1. **Memory Allocation**: Right-size memory for performance
2. **Timeout Settings**: Set appropriate timeout values
3. **Connection Pooling**: Reuse database connections
4. **Cold Start Optimization**: Keep deployment package small

### 10.4 Cost Optimization
1. **Right-sizing**: Use appropriate memory and timeout
2. **Log Retention**: Set appropriate retention periods
3. **Provisioned Concurrency**: Use only when needed
4. **Monitoring**: Track costs and usage patterns

## Part 11: What You've Accomplished

### 11.1 Skills Learned
- [x] Python virtual environment management
- [x] Lambda function development
- [x] Terraform infrastructure as code
- [x] AWS IAM security model
- [x] CloudWatch monitoring
- [x] Secrets management
- [x] Database connectivity from Lambda

### 11.2 Infrastructure Created
- [x] Lambda function with proper IAM permissions
- [x] CloudWatch log group for monitoring
- [x] Secrets Manager for secure credential storage
- [x] Deployment package with dependencies
- [x] Terraform configuration for reproducible deployments

### 11.3 Next Steps
1. **Connect to Firehose**: Integrate with Kinesis Data Firehose
2. **Add Error Handling**: Implement dead letter queues
3. **Monitor Performance**: Set up CloudWatch dashboards
4. **Implement CI/CD**: Automate deployments
5. **Add Testing**: Unit and integration tests

## Part 12: Cleanup (Important!)

### 12.1 Destroy Resources
```bash
# Destroy all created resources
terraform destroy

# Type 'yes' when prompted
```

### 12.2 Verify Cleanup
```bash
# Check Lambda functions
aws lambda list-functions --query "Functions[?FunctionName=='iot-data-processor']"

# Check IAM roles
aws iam list-roles --query "Roles[?RoleName=='iot-lambda-execution-role']"

# Check Secrets Manager
aws secretsmanager list-secrets --query "SecretList[?Name=='iot-database-credentials']"
```

## Summary

You've successfully created a complete Lambda function deployment pipeline using Terraform. This foundation will serve you well for building more complex serverless applications. The key concepts you've learned - virtual environments, infrastructure as code, IAM security, and monitoring - are fundamental to professional cloud development.

Remember: Always clean up resources when testing to avoid unnecessary charges!