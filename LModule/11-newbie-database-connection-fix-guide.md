# Complete Newbie Guide: Fixing Lambda to EC2 Database Connection Errors

## Overview
This guide will walk you through fixing database connection errors between AWS Lambda and an EC2-hosted MySQL/MariaDB database. No prior experience with databases or AWS troubleshooting is assumed.

## Prerequisites
- AWS CLI installed and configured
- Access to AWS Console
- Basic understanding of terminal/command line
- EC2 instance running Amazon Linux 2023
- Lambda function that needs to connect to database

## Problem Symptoms
If you're seeing errors like:
- `Connection refused`
- `Can't connect to MySQL server`
- `Database error: (2003, "Can't connect to MySQL server")`
- Lambda function returns "ProcessingFailed"

This guide will help you fix these issues.

## Step 1: Database Service Installation

### 1.1 Understanding the Problem
**What's happening**: Your EC2 instance doesn't have a database service running, so Lambda can't connect to anything.

**Why this matters**: Without a database service, your EC2 instance can't accept database connections.

### 1.2 Connect to Your EC2 Instance
We'll use AWS Systems Manager (SSM) to connect to your EC2 instance without SSH.

#### Option A: Using AWS CLI
```bash
# Replace i-0700f0b5c1c9cf4e7 with your actual instance ID
aws ssm start-session --target i-0700f0b5c1c9cf4e7 --region us-west-1
```

#### Option B: Using AWS Console
1. Go to AWS Console → EC2 → Instances
2. Select your instance
3. Click "Connect" → "Session Manager" → "Connect"

### 1.3 Check if Database is Already Installed
```bash
# Check if MySQL/MariaDB is already running
sudo systemctl status mysql
sudo systemctl status mariadb

# Check if any database processes are running
ps aux | grep mysql
ps aux | grep mariadb
```

**Expected Output if NOT installed:**
```
Unit mysql.service could not be found.
Unit mariadb.service could not be found.
```

### 1.4 Install MariaDB Database
MariaDB is MySQL-compatible and easier to install on Amazon Linux.

```bash
# Update system packages
sudo yum update -y

# Install MariaDB server and client
sudo yum install -y mariadb1011-server mariadb1011

# Verify installation
rpm -qa | grep mariadb
```

**Expected Output:**
```
mariadb1011-server-3:10.11.13-1.amzn2023.0.1.x86_64
mariadb1011-3:10.11.13-1.amzn2023.0.1.x86_64
mariadb1011-common-3:10.11.13-1.amzn2023.0.1.x86_64
```

### 1.5 Enable and Start MariaDB Service
```bash
# Enable MariaDB to start automatically on boot
sudo systemctl enable mariadb

# Start MariaDB service
sudo systemctl start mariadb

# Check service status
sudo systemctl status mariadb
```

**Expected Output:**
```
● mariadb.service - MariaDB 10.11 database server
   Loaded: loaded (/usr/lib/systemd/system/mariadb.service; enabled; preset: disabled)
   Active: active (running) since Fri 2025-07-18 07:02:44 UTC; 123ms ago
   Status: "Taking your SQL requests now..."
```

### 1.6 Verify Database Service is Running
```bash
# Check if MariaDB is listening on port 3306
sudo netstat -tlnp | grep 3306

# Alternative check
sudo ss -tlnp | grep 3306
```

**Expected Output:**
```
tcp        0      0 127.0.0.1:3306          0.0.0.0:*               LISTEN      20103/mariadbd
```

## Step 2: Database Configuration

### 2.1 Understanding Database Setup
**What we need to create:**
- Database: A container for our tables
- User: An account Lambda can use to connect
- Table: Structure to store IoT data
- Permissions: Allow the user to access the database

### 2.2 Secure MariaDB Installation (Optional but Recommended)
```bash
# Run MariaDB security script
sudo mysql_secure_installation
```

**Prompts and Recommended Answers:**
- Enter current password for root: `[Press Enter]`
- Set root password? `Y`
- New password: `[Choose a secure password]`
- Remove anonymous users? `Y`
- Disallow root login remotely? `Y`
- Remove test database? `Y`
- Reload privilege tables? `Y`

### 2.3 Create Database and User
```bash
# Connect to MariaDB as root
sudo mysql -u root -p
```

**Execute these SQL commands inside MariaDB:**
```sql
-- Create the database
CREATE DATABASE IF NOT EXISTS db_iot_smart_buildings;

-- Create user that can connect from anywhere (% means any host)
CREATE USER IF NOT EXISTS 'usr_iot_admin'@'%' IDENTIFIED BY 'dew4DL';

-- Grant all privileges on our database to the user
GRANT ALL PRIVILEGES ON db_iot_smart_buildings.* TO 'usr_iot_admin'@'%';

-- Apply the changes
FLUSH PRIVILEGES;

-- Verify the user was created
SELECT user, host FROM mysql.user WHERE user = 'usr_iot_admin';

-- Exit MariaDB
EXIT;
```

**Expected Output:**
```
+---------------+------+
| user          | host |
+---------------+------+
| usr_iot_admin | %    |
+---------------+------+
```

### 2.4 Create IoT Data Table
```bash
# Connect as our new user to test access
mysql -u usr_iot_admin -p'dew4DL'
```

**Execute these SQL commands:**
```sql
-- Use our database
USE db_iot_smart_buildings;

-- Create table for IoT motion sensor data
CREATE TABLE IF NOT EXISTS tbl_smart_motion_model_x (
    id INT AUTO_INCREMENT PRIMARY KEY,
    device_id VARCHAR(255) NOT NULL,
    ts TIMESTAMP NOT NULL,
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),
    motion_detected BOOLEAN,
    device_status VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Verify table was created
DESCRIBE tbl_smart_motion_model_x;

-- Exit MariaDB
EXIT;
```

**Expected Output:**
```
+------------------+---------------+------+-----+-------------------+----------------+
| Field            | Type          | Null | Key | Default           | Extra          |
+------------------+---------------+------+-----+-------------------+----------------+
| id               | int(11)       | NO   | PRI | NULL              | auto_increment |
| device_id        | varchar(255)  | NO   |     | NULL              |                |
| ts               | timestamp     | NO   |     | NULL              |                |
| latitude         | decimal(10,8) | YES  |     | NULL              |                |
| longitude        | decimal(11,8) | YES  |     | NULL              |                |
| motion_detected  | tinyint(1)    | YES  |     | NULL              |                |
| device_status    | varchar(50)   | YES  |     | NULL              |                |
| created_at       | timestamp     | YES  |     | CURRENT_TIMESTAMP |                |
+------------------+---------------+------+-----+-------------------+----------------+
```

### 2.5 Test Database Access
```bash
# Test inserting a record
mysql -u usr_iot_admin -p'dew4DL' -e "
USE db_iot_smart_buildings;
INSERT INTO tbl_smart_motion_model_x 
(device_id, ts, latitude, longitude, motion_detected, device_status) 
VALUES ('test_device_setup', NOW(), 37.7749, -122.4194, 1, 'online');
"

# Verify the record was inserted
mysql -u usr_iot_admin -p'dew4DL' -e "
USE db_iot_smart_buildings;
SELECT * FROM tbl_smart_motion_model_x WHERE device_id = 'test_device_setup';
"
```

## Step 3: Network Security Configuration

### 3.1 Understanding Network Security
**What we need to configure:**
- EC2 Security Group: Firewall rules for your EC2 instance
- MariaDB Configuration: Allow connections from outside localhost
- Test connectivity: Verify everything works

### 3.2 Check Current Security Group
```bash
# Get your instance ID (if you don't know it)
aws ec2 describe-instances --region us-west-1 --query "Reservations[].Instances[].[InstanceId,PublicIpAddress,SecurityGroups[0].GroupId]" --output table

# Check security group rules (replace sg-00c2deae19c80516a with your security group ID)
aws ec2 describe-security-groups --group-ids sg-00c2deae19c80516a --region us-west-1
```

### 3.3 Add MySQL Port to Security Group (if needed)
```bash
# Add MySQL port 3306 to security group (replace sg-00c2deae19c80516a with your security group ID)
aws ec2 authorize-security-group-ingress \
  --group-id sg-00c2deae19c80516a \
  --protocol tcp \
  --port 3306 \
  --cidr 0.0.0.0/0 \
  --region us-west-1
```

**⚠️ Security Note**: `0.0.0.0/0` allows access from anywhere. In production, restrict this to specific IP ranges.

### 3.4 Configure MariaDB for External Connections
By default, MariaDB only accepts connections from localhost. We need to change this.

```bash
# Backup the original configuration
sudo cp /etc/my.cnf.d/mariadb-server.cnf /etc/my.cnf.d/mariadb-server.cnf.backup

# Edit the configuration file
sudo nano /etc/my.cnf.d/mariadb-server.cnf
```

**Find this line:**
```
#bind-address=0.0.0.0
```

**Change it to:**
```
bind-address=0.0.0.0
```

**Or use this command to make the change automatically:**
```bash
sudo sed -i 's/#bind-address=0.0.0.0/bind-address=0.0.0.0/g' /etc/my.cnf.d/mariadb-server.cnf
```

### 3.5 Restart MariaDB Service
```bash
# Restart MariaDB to apply configuration changes
sudo systemctl restart mariadb

# Verify service is still running
sudo systemctl status mariadb

# Check that MariaDB is now listening on all interfaces
sudo netstat -tlnp | grep 3306
```

**Expected Output:**
```
tcp        0      0 0.0.0.0:3306            0.0.0.0:*               LISTEN      38169/mariadbd
```

**Note**: `0.0.0.0:3306` means MariaDB is listening on all network interfaces.

### 3.6 Test External Database Connection
```bash
# From your local machine or another instance, test connection
# Replace 3.101.111.137 with your EC2 instance's public IP
nc -zv 3.101.111.137 3306

# If nc is not available, try telnet
telnet 3.101.111.137 3306
```

**Expected Output:**
```
Connection to 3.101.111.137 port 3306 [tcp/mysql] succeeded!
```

## Step 4: Lambda Function Fixes

### 4.1 Understanding Lambda Function Issues
**Common problems:**
- Incorrect timestamp format
- Missing error handling
- Wrong database credentials
- Missing dependencies

### 4.2 Check Current Lambda Function
```bash
# Get Lambda function configuration
aws lambda get-function-configuration --function-name o2-arena-iot-data-processor --region us-west-1

# Download current function code
aws lambda get-function --function-name o2-arena-iot-data-processor --region us-west-1 --query 'Code.Location'
```

### 4.3 Fix Timestamp Format Issue
The most common issue is timestamp format incompatibility.

**Problem**: Lambda sends `2025-07-18T06:30:00Z` but MySQL expects `2025-07-18 06:30:00`

**Solution**: Update your Lambda function code:

```python
# Original problematic code
cur.execute(dml_stmt, (
    row['device_id'], 
    row['ts'],  # This fails with ISO 8601 format
    row['latitude'], 
    row['longitude'], 
    row['motion_detected'], 
    row['device_status']
))

# Fixed code
# Convert ISO 8601 timestamp to MySQL format
mysql_timestamp = row['ts'].replace('T', ' ').replace('Z', '')

cur.execute(dml_stmt, (
    row['device_id'], 
    mysql_timestamp,  # Now compatible with MySQL
    row['latitude'], 
    row['longitude'], 
    row['motion_detected'], 
    row['device_status']
))
```

### 4.4 Complete Enhanced Lambda Function Code
Create a file called `lambda_function.py` with this content:

```python
import base64
import json
import pymysql
import logging
import os
from datetime import datetime

# Logger settings
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Database configuration
DB_HOST = '3.101.111.137'  # Replace with your EC2 public IP
DB_NAME = 'db_iot_smart_buildings'
DB_USER = 'usr_iot_admin'
DB_PASSWORD = 'dew4DL'

def lambda_handler(event, context):
    """
    Enhanced Lambda handler function
    Processes IoT data from Kinesis Data Firehose
    - Inserts data into MySQL database
    - Returns enhanced data with processing metadata for S3 storage
    """
    logger.info(f"Lambda function started - received {len(event.get('records', []))} records")
    output = []
    
    try:
        # Connect to MySQL database
        conn = pymysql.connect(
            host=DB_HOST,
            user=DB_USER,
            passwd=DB_PASSWORD,
            db=DB_NAME,
            connect_timeout=5,
            charset='utf8mb4'
        )
        logger.info('Connected to database successfully')
        
        # Process each record from Firehose
        for record in event['records']:
            try:
                # Decode base64 data
                payload = base64.b64decode(record['data']).decode('utf-8')
                row = json.loads(payload)
                
                logger.info(f'Processing record: {row}')
                
                # Convert ISO 8601 timestamp to MySQL format
                mysql_timestamp = row['ts'].replace('T', ' ').replace('Z', '')
                
                # Insert into database
                with conn.cursor() as cur:
                    dml_stmt = '''INSERT INTO tbl_smart_motion_model_x 
                                 (device_id, ts, latitude, longitude, motion_detected, device_status) 
                                 VALUES(%s, %s, %s, %s, %s, %s)'''
                    cur.execute(dml_stmt, (
                        row['device_id'], 
                        mysql_timestamp, 
                        row['latitude'], 
                        row['longitude'], 
                        row['motion_detected'], 
                        row['device_status']
                    ))
                
                conn.commit()
                logger.info(f'Successfully inserted record for device: {row["device_id"]}')
                
                # Create enhanced data with processing metadata for S3 storage
                enhanced_data = {
                    **row,  # Original IoT data
                    'processed_at': datetime.utcnow().isoformat() + 'Z',
                    'processing_status': 'success',
                    'database_inserted': True,
                    'lambda_request_id': context.aws_request_id
                }
                
                # Return enhanced JSON data with newline for better S3 storage
                enhanced_json = json.dumps(enhanced_data)
                processed_data = base64.b64encode(f"{enhanced_json}\n".encode('utf-8')).decode('utf-8')
                
                # Mark record as successfully processed
                output.append({
                    'recordId': record['recordId'],
                    'result': 'Ok',
                    'data': processed_data
                })
                
            except Exception as e:
                logger.error(f'Error processing record {record["recordId"]}: {str(e)}')
                
                # Create enhanced error data
                try:
                    error_data = {
                        **row,  # Original IoT data if available
                        'processed_at': datetime.utcnow().isoformat() + 'Z',
                        'processing_status': 'failed',
                        'database_inserted': False,
                        'error_message': str(e),
                        'lambda_request_id': context.aws_request_id
                    }
                    error_json = json.dumps(error_data)
                    processed_error_data = base64.b64encode(f"{error_json}\n".encode('utf-8')).decode('utf-8')
                except:
                    # Fallback to original data if enhancement fails
                    processed_error_data = record['data']
                
                # Mark record as failed
                output.append({
                    'recordId': record['recordId'],
                    'result': 'ProcessingFailed',
                    'data': processed_error_data
                })
        
        # Close database connection
        conn.close()
        logger.info(f'Successfully processed {len(output)} records')
        return {'records': output}
        
    except pymysql.MySQLError as e:
        logger.error(f"Database error: {e}")
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
        
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
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

### 4.5 Enhanced Data Output
The enhanced Lambda function now stores enriched data in S3 with processing metadata:

**Original IoT Data:**
```json
{
  "device_id": "test_device_001",
  "ts": "2025-07-18T08:10:00Z",
  "latitude": 37.7849,
  "longitude": -122.4094,
  "motion_detected": true,
  "device_status": "online"
}
```

**Enhanced S3 Data:**
```json
{
  "device_id": "test_device_001",
  "ts": "2025-07-18T08:10:00Z",
  "latitude": 37.7849,
  "longitude": -122.4094,
  "motion_detected": true,
  "device_status": "online",
  "processed_at": "2025-07-18T08:01:56.484040Z",
  "processing_status": "success",
  "database_inserted": true,
  "lambda_request_id": "a9eb1314-276d-4441-b1e7-aaf4864f647d"
}
```

**Key Enhancements:**
- `processed_at`: Timestamp when Lambda processed the record
- `processing_status`: "success" or "failed" 
- `database_inserted`: Boolean indicating if database insertion succeeded
- `lambda_request_id`: Unique identifier for request tracing

### 4.5 Package and Deploy Lambda Function
```bash
# Create deployment package directory
mkdir lambda_package_minimal
cd lambda_package_minimal

# Copy your Lambda function
cp ../lambda_function.py .

# Install pymysql dependency
pip install pymysql -t .

# Verify package contents
ls -la
```

### 4.6 Deploy Updated Lambda Function
If you're using Terraform:

```bash
# Remove old zip file to force rebuild
rm -f lambda_function.zip

# Deploy with Terraform
terraform apply -target=aws_lambda_function.iot_data_processor -auto-approve
```

If you're using AWS CLI:

```bash
# Create zip file
zip -r lambda_function.zip .

# Update Lambda function
aws lambda update-function-code \
  --function-name o2-arena-iot-data-processor \
  --zip-file fileb://lambda_function.zip \
  --region us-west-1
```

## Step 5: IAM Policies and Roles Configuration

### 5.1 Understanding IAM Requirements
**What Lambda needs permission to do:**
- Write to CloudWatch Logs (for debugging)
- Access Secrets Manager (for database credentials)
- Basic Lambda execution permissions

### 5.2 Check Current IAM Role
```bash
# Get Lambda function's IAM role
aws lambda get-function-configuration --function-name o2-arena-iot-data-processor --region us-west-1 --query 'Role'

# Check what policies are attached to the role
aws iam list-attached-role-policies --role-name o2-arena-lambda-execution-role
```

### 5.3 Create IAM Role (if needed)
```bash
# Create trust policy file
cat > trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create IAM role
aws iam create-role \
  --role-name o2-arena-lambda-execution-role \
  --assume-role-policy-document file://trust-policy.json
```

### 5.4 Create and Attach IAM Policy
```bash
# Create policy document
cat > lambda-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": "arn:aws:secretsmanager:us-west-1:*:secret:db_credentials_iot_project-*"
    }
  ]
}
EOF

# Create policy
aws iam create-policy \
  --policy-name o2-arena-lambda-policy \
  --policy-document file://lambda-policy.json

# Attach policy to role
aws iam attach-role-policy \
  --role-name o2-arena-lambda-execution-role \
  --policy-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/o2-arena-lambda-policy
```

### 5.5 Update Lambda Function Role (if needed)
```bash
# Update Lambda function to use the correct role
aws lambda update-function-configuration \
  --function-name o2-arena-iot-data-processor \
  --role arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/o2-arena-lambda-execution-role \
  --region us-west-1
```

## Step 6: Testing and Verification

### 6.1 Test Database Connection from Lambda
```bash
# Create test payload
cat > test-payload.json << 'EOF'
{
  "records": [
    {
      "recordId": "test123",
      "data": "eyJkZXZpY2VfaWQiOiAidGVzdF9kZXZpY2VfMDAxIiwgInRzIjogIjIwMjUtMDctMThUMDY6MzA6MDBaIiwgImxhdGl0dWRlIjogMzcuNzc0OSwgImxvbmdpdHVkZSI6IC0xMjIuNDE5NCwgIm1vdGlvbl9kZXRlY3RlZCI6IHRydWUsICJkZXZpY2Vfc3RhdHVzIjogIm9ubGluZSJ9"
    }
  ]
}
EOF

# Test Lambda function
aws lambda invoke \
  --function-name o2-arena-iot-data-processor \
  --cli-binary-format raw-in-base64-out \
  --payload file://test-payload.json \
  response.json \
  --region us-west-1

# Check response
cat response.json
```

**Expected Success Response:**
```json
{
  "records": [
    {
      "recordId": "test123",
      "result": "Ok",
      "data": "eyJkZXZpY2VfaWQiOiAidGVzdF9kZXZpY2VfMDAxIiwgInRzIjogIjIwMjUtMDctMThUMDY6MzA6MDBaIiwgImxhdGl0dWRlIjogMzcuNzc0OSwgImxvbmdpdHVkZSI6IC0xMjIuNDE5NCwgIm1vdGlvbl9kZXRlY3RlZCI6IHRydWUsICJkZXZpY2Vfc3RhdHVzIjogIm9ubGluZSJ9"
    }
  ]
}
```

### 6.2 Check Lambda Logs
```bash
# Get latest log stream
aws logs describe-log-streams \
  --log-group-name "/aws/lambda/o2-arena-iot-data-processor" \
  --region us-west-1 \
  --order-by LastEventTime \
  --descending \
  --max-items 1

# Get log events (replace LOG_STREAM_NAME with actual name from above)
aws logs get-log-events \
  --log-group-name "/aws/lambda/o2-arena-iot-data-processor" \
  --log-stream-name "LOG_STREAM_NAME" \
  --region us-west-1
```

**Expected Success Logs:**
```
[INFO] Connected to database successfully
[INFO] Processing record: {'device_id': 'test_device_001', ...}
[INFO] Successfully inserted record for device: test_device_001
[INFO] Successfully processed 1 records
```

### 6.3 Verify Database Records
```bash
# Check database records on EC2 instance
mysql -u usr_iot_admin -p'dew4DL' -e "
USE db_iot_smart_buildings;
SELECT * FROM tbl_smart_motion_model_x ORDER BY created_at DESC LIMIT 5;
"
```

**Expected Output:**
```
+----+-----------------+---------------------+-------------+---------------+-----------------+---------------+---------------------+
| id | device_id       | ts                  | latitude    | longitude     | motion_detected | device_status | created_at          |
+----+-----------------+---------------------+-------------+---------------+-----------------+---------------+---------------------+
|  1 | test_device_001 | 2025-07-18 06:30:00 | 37.77490000 | -122.41940000 |               1 | online        | 2025-07-18 07:09:14 |
+----+-----------------+---------------------+-------------+---------------+-----------------+---------------+---------------------+
```

## Step 7: Common Issues and Solutions

### 7.1 Lambda Function Still Fails
**Problem**: Lambda returns "ProcessingFailed"

**Solutions**:
1. Check CloudWatch logs for specific error messages
2. Verify database credentials are correct
3. Ensure EC2 security group allows port 3306
4. Test database connection manually

### 7.2 "Connection Refused" Error
**Problem**: Database connection is refused

**Solutions**:
1. Verify MariaDB service is running: `sudo systemctl status mariadb`
2. Check bind-address configuration: `grep bind-address /etc/my.cnf.d/mariadb-server.cnf`
3. Restart MariaDB: `sudo systemctl restart mariadb`
4. Check if port 3306 is listening: `sudo netstat -tlnp | grep 3306`

### 7.3 "Access Denied" Error
**Problem**: Authentication fails

**Solutions**:
1. Verify user exists: `SELECT user, host FROM mysql.user WHERE user = 'usr_iot_admin';`
2. Check user permissions: `SHOW GRANTS FOR 'usr_iot_admin'@'%';`
3. Recreate user if needed
4. Verify password is correct

### 7.4 Timestamp Format Errors
**Problem**: "Incorrect datetime value" error

**Solutions**:
1. Ensure timestamp conversion is implemented: `mysql_timestamp = row['ts'].replace('T', ' ').replace('Z', '')`
2. Check input timestamp format
3. Verify table column is TIMESTAMP type

### 7.5 "Table doesn't exist" Error
**Problem**: Table not found

**Solutions**:
1. Verify database exists: `SHOW DATABASES;`
2. Check table exists: `USE db_iot_smart_buildings; SHOW TABLES;`
3. Recreate table if needed
4. Verify Lambda is connecting to correct database

## Step 8: Security Best Practices

### 8.1 Secure Database Credentials
Instead of hardcoding credentials, use AWS Secrets Manager:

```python
import boto3
import json

def get_database_credentials():
    """Get database credentials from AWS Secrets Manager"""
    secrets_client = boto3.client('secretsmanager')
    
    try:
        secret_value = secrets_client.get_secret_value(
            SecretId='db_credentials_iot_project'
        )
        return json.loads(secret_value['SecretString'])
    except Exception as e:
        logger.error(f"Error getting database credentials: {e}")
        raise

# Usage in Lambda function
def lambda_handler(event, context):
    credentials = get_database_credentials()
    
    conn = pymysql.connect(
        host=credentials['host'],
        user=credentials['username'],
        passwd=credentials['password'],
        db=credentials['database'],
        connect_timeout=5
    )
```

### 8.2 Restrict Security Group Access
Instead of allowing access from anywhere (0.0.0.0/0), restrict to specific IP ranges:

```bash
# Remove overly permissive rule
aws ec2 revoke-security-group-ingress \
  --group-id sg-00c2deae19c80516a \
  --protocol tcp \
  --port 3306 \
  --cidr 0.0.0.0/0 \
  --region us-west-1

# Add restricted rule (replace with your specific IP range)
aws ec2 authorize-security-group-ingress \
  --group-id sg-00c2deae19c80516a \
  --protocol tcp \
  --port 3306 \
  --cidr 10.0.0.0/16 \
  --region us-west-1
```

### 8.3 Use VPC for Lambda (Production Recommendation)
For production, place Lambda in the same VPC as your database:

```hcl
# Terraform configuration
resource "aws_lambda_function" "iot_data_processor" {
  # ... other configuration ...
  
  vpc_config {
    subnet_ids         = [aws_subnet.private_subnet.id]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }
}
```

## Step 9: Monitoring and Alerting

### 9.1 Set Up CloudWatch Alarms
```bash
# Create alarm for Lambda errors
aws cloudwatch put-metric-alarm \
  --alarm-name "lambda-database-errors" \
  --alarm-description "Alert when Lambda function has database errors" \
  --metric-name Errors \
  --namespace AWS/Lambda \
  --statistic Sum \
  --period 300 \
  --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --dimensions Name=FunctionName,Value=o2-arena-iot-data-processor \
  --evaluation-periods 1 \
  --region us-west-1
```

### 9.2 Enable Detailed Monitoring
```bash
# Enable detailed monitoring for Lambda
aws lambda put-provisioned-concurrency-config \
  --function-name o2-arena-iot-data-processor \
  --qualifier '$LATEST' \
  --provisioned-concurrency-config ProvisionedConcurrencyConfig='{AllocatedConcurrency=1}' \
  --region us-west-1
```

## Step 10: Maintenance and Backup

### 10.1 Database Backup
```bash
# Create database backup
mysqldump -u usr_iot_admin -p'dew4DL' db_iot_smart_buildings > backup_$(date +%Y%m%d).sql

# Restore from backup
mysql -u usr_iot_admin -p'dew4DL' db_iot_smart_buildings < backup_20250718.sql
```

### 10.2 Log Rotation
```bash
# Configure log rotation for MariaDB
sudo nano /etc/logrotate.d/mariadb
```

Add this content:
```
/var/log/mariadb/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 640 mysql mysql
    postrotate
        /usr/bin/systemctl reload mariadb
    endscript
}
```

## Conclusion

You have successfully:
1. ✅ Installed and configured MariaDB on EC2
2. ✅ Created database, user, and table structure
3. ✅ Configured network security for database access
4. ✅ Fixed Lambda function code and timestamp issues
5. ✅ Set up proper IAM roles and policies
6. ✅ Tested end-to-end connectivity
7. ✅ Verified data insertion and retrieval

Your Lambda function can now successfully connect to your EC2-hosted database and process IoT data. The pipeline is ready for production use with proper security measures in place.

## Quick Reference Commands

### Database Management
```bash
# Connect to database
mysql -u usr_iot_admin -p'dew4DL'

# Check service status
sudo systemctl status mariadb

# Restart service
sudo systemctl restart mariadb

# View recent records
mysql -u usr_iot_admin -p'dew4DL' -e "USE db_iot_smart_buildings; SELECT * FROM tbl_smart_motion_model_x ORDER BY created_at DESC LIMIT 10;"
```

### Lambda Testing
```bash
# Test Lambda function
aws lambda invoke --function-name o2-arena-iot-data-processor --payload '{"records":[{"recordId":"test","data":"base64_data"}]}' response.json --region us-west-1

# Check logs
aws logs describe-log-streams --log-group-name "/aws/lambda/o2-arena-iot-data-processor" --region us-west-1 --order-by LastEventTime --descending --max-items 1
```

### Network Testing
```bash
# Test database connectivity
nc -zv 3.101.111.137 3306

# Check listening ports
sudo netstat -tlnp | grep 3306
```

This guide provides a complete solution for fixing database connection issues between Lambda and EC2-hosted databases. Follow each step carefully, and you'll have a working, secure database connection.