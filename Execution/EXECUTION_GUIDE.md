# IoT Motion Detection Data Processing - Execution Guide

## Project Overview
This project demonstrates a complete IoT data pipeline architecture using AWS CDK (Python) and Terraform. The system captures motion sensor data from IoT devices, processes it through AWS services, and stores it in both S3 and MySQL database.

## Architecture Components
- **IoT Rule**: Captures data from topic `/iot-o2-arena-motion`
- **Kinesis Firehose**: Delivers data to S3 with Lambda transformation
- **Lambda Function**: Processes data and writes to MySQL database
- **S3 Bucket**: Stores processed data with GZIP compression
- **EC2 Instance**: Runs MariaDB database
- **Secrets Manager**: Stores database credentials securely

## Prerequisites
- AWS Account with appropriate permissions
- Python 3.9+ installed
- Node.js installed (for CDK)
- Git installed
- Basic knowledge of AWS services (IoT Core, Lambda, S3, Kinesis Firehose)

## Execution Steps

### Task 1: Set up AWS CLI and configure credentials
**Status**: Pending  
**Priority**: High  

**Actions**:
1. Install AWS CLI v2:
   ```bash
   # For macOS
   curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
   sudo installer -pkg AWSCLIV2.pkg -target /
   
   # For Linux
   curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
   unzip awscliv2.zip
   sudo ./aws/install
   ```

2. Configure AWS credentials:
   ```bash
   aws configure
   ```
   - AWS Access Key ID: [Your access key]
   - AWS Secret Access Key: [Your secret key]
   - Default region name: `us-west-1`
   - Default output format: `json`

3. Set AWS account ID to `443370692694` (as defined in project)

4. Test connection:
   ```bash
   aws sts get-caller-identity
   ```

### Task 2: Install and configure AWS CDK
**Status**: Pending  
**Priority**: High  

**Actions**:
1. Install Node.js (required for CDK):
   ```bash
   # For macOS
   brew install node
   
   # For Linux/Windows - download from nodejs.org
   ```

2. Install AWS CDK:
   ```bash
   npm install -g aws-cdk
   ```

3. Verify installation:
   ```bash
   cdk --version
   ```

4. Bootstrap CDK in your AWS account:
   ```bash
   cdk bootstrap aws://443370692694/us-west-1
   ```

### Task 3: Install and configure Terraform
**Status**: Pending  
**Priority**: High  

**Actions**:
1. Install Terraform:
   ```bash
   # For macOS
   brew install terraform
   
   # For Linux - download from terraform.io
   wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
   unzip terraform_1.6.0_linux_amd64.zip
   sudo mv terraform /usr/local/bin/
   ```

2. Verify installation:
   ```bash
   terraform --version
   ```

3. Initialize Terraform in project directory:
   ```bash
   cd /Users/swaroop/Documents/AWS-IOT/Aws-CDK-project
   terraform init
   ```

### Task 4: Set up Python virtual environment and install dependencies
**Status**: Pending  
**Priority**: High  

**Actions**:
1. Navigate to project directory:
   ```bash
   cd /Users/swaroop/Documents/AWS-IOT/Aws-CDK-project
   ```

2. Create virtual environment:
   ```bash
   python3 -m venv .venv
   ```

3. Activate virtual environment:
   ```bash
   # For macOS/Linux
   source .venv/bin/activate
   
   # For Windows
   .venv\Scripts\activate.bat
   ```

4. Install CDK dependencies:
   ```bash
   pip install -r requirements.txt
   pip install -r requirements-dev.txt
   ```

5. Install additional CDK constructs:
   ```bash
   pip install aws-cdk-lib constructs
   ```

### Task 5: Deploy infrastructure using Terraform (VPC, EC2, Database, Secrets)
**Status**: Pending  
**Priority**: High  

**Actions**:
1. Navigate to project directory:
   ```bash
   cd /Users/swaroop/Documents/AWS-IOT/Aws-CDK-project
   ```

2. Run Terraform plan:
   ```bash
   terraform plan
   ```

3. Deploy infrastructure:
   ```bash
   terraform apply
   ```
   Type `yes` when prompted.

4. Verify deployment:
   - Check EC2 instance is running in AWS Console
   - Verify MariaDB is installed and running
   - Check Secrets Manager for database credentials
   - Note down the public IP of EC2 instance

5. Wait for EC2 user data script to complete (approximately 5-10 minutes)

### Task 6: Fix CDK stack structure and organize code properly
**Status**: Pending  
**Priority**: Medium  

**Actions**:
1. Create proper directory structure:
   ```bash
   mkdir -p s3_stack
   mkdir -p lambda_firehose_stack
   ```

2. Move files to appropriate directories:
   ```bash
   mv o2_arena_cdk_s3_stack.py s3_stack/
   mv o2_arena_cdk_lambda_firehose_stack.py lambda_firehose_stack/
   mv lambda_function.py lambda_firehose_stack/
   ```

3. Update import paths in `app.py` to match new structure

4. Remove unused files:
   ```bash
   rm 13_cdk_project_v1_stack.py
   ```

### Task 7: Deploy CDK stacks (S3, Lambda, Firehose, IoT Rule)
**Status**: Pending  
**Priority**: High  

**Actions**:
1. Synthesize CDK stacks:
   ```bash
   cdk synth
   ```

2. Deploy S3 stack first:
   ```bash
   cdk deploy o2-arena-s3-stack
   ```

3. Deploy Lambda/Firehose stack:
   ```bash
   cdk deploy o2-arena-lambda-firehose-stack
   ```

4. Verify resources in AWS Console:
   - S3 bucket created
   - Lambda function deployed
   - Kinesis Firehose delivery stream created
   - IoT Core rule created for topic `/iot-o2-arena-motion`

### Task 8: Test IoT data ingestion pipeline
**Status**: Pending  
**Priority**: Medium  

**Actions**:
1. Prepare test data message:
   ```json
   {
     "device_id": "DEV001",
     "ts": "2024-01-15 10:30:00",
     "latitude": 37.7749,
     "longitude": -122.4194,
     "motion_detected": 1,
     "device_status": "active"
   }
   ```

2. Publish to IoT topic using AWS CLI:
   ```bash
   aws iot-data publish --topic "/iot-o2-arena-motion" --payload '{"device_id":"DEV001","ts":"2024-01-15 10:30:00","latitude":37.7749,"longitude":-122.4194,"motion_detected":1,"device_status":"active"}'
   ```

3. Monitor CloudWatch logs:
   - Check Lambda function execution logs
   - Monitor Kinesis Firehose delivery stream metrics

4. Alternative testing using AWS IoT Device Simulator:
   - Navigate to AWS IoT Device Simulator in AWS Console
   - Create a virtual device
   - Configure it to publish to `/iot-o2-arena-motion` topic

### Task 9: Verify data flow from IoT to S3 and Database
**Status**: Pending  
**Priority**: Medium  

**Actions**:
1. Check S3 bucket for data files:
   ```bash
   aws s3 ls s3://[your-bucket-name]/o2-arena-motion/ --recursive
   ```

2. Connect to MariaDB database:
   ```bash
   # Get database credentials from Secrets Manager
   aws secretsmanager get-secret-value --secret-id db_credentials_11
   
   # Connect to database (replace with actual IP from Terraform output)
   mysql -h [EC2-PUBLIC-IP] -u usr_iot_admin -p
   ```

3. Verify data insertion:
   ```sql
   USE db_iot_smart_buildings;
   SELECT * FROM tbl_smart_motion_model_x ORDER BY ts DESC LIMIT 10;
   ```

4. Check for errors:
   ```bash
   # Check S3 error logs
   aws s3 ls s3://[your-bucket-name]/errors/ --recursive
   
   # Check CloudWatch logs for Lambda errors
   aws logs describe-log-groups --log-group-name-prefix "/aws/lambda"
   ```

### Task 10: Clean up resources after testing
**Status**: Pending  
**Priority**: Low  

**Actions**:
1. Destroy CDK stacks:
   ```bash
   cdk destroy o2-arena-lambda-firehose-stack
   cdk destroy o2-arena-s3-stack
   ```

2. Destroy Terraform infrastructure:
   ```bash
   terraform destroy
   ```
   Type `yes` when prompted.

3. Deactivate Python virtual environment:
   ```bash
   deactivate
   ```

4. Remove local state files:
   ```bash
   rm -rf .terraform
   rm terraform.tfstate*
   rm cdk.out
   ```

## Expected Data Flow
1. IoT device publishes motion data to AWS IoT Core topic `/iot-o2-arena-motion`
2. IoT Rule captures the data and sends to Kinesis Firehose
3. Firehose processes data through Lambda function
4. Lambda function writes data to MariaDB database
5. Processed data is stored in S3 bucket with GZIP compression
6. Errors are logged to S3 error prefix and CloudWatch

## Troubleshooting
- If CDK deployment fails, check IAM permissions
- If Lambda function fails, check CloudWatch logs
- If database connection fails, verify security group rules
- If IoT messages aren't received, check IoT rule configuration
- For timeout issues, check Lambda function timeout settings

## Security Considerations
- Database credentials are stored in AWS Secrets Manager
- Lambda has appropriate IAM permissions to read secrets
- MySQL is accessible from anywhere (0.0.0.0/0) - consider restricting in production
- Use VPC endpoints for enhanced security in production

## Cost Optimization
- Use appropriate instance types for production workloads
- Consider using RDS instead of EC2-hosted database for production
- Implement data lifecycle policies for S3 storage
- Monitor and optimize Lambda execution time and memory usage