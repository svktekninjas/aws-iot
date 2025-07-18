# Module 1: Prerequisites and Setup

## Overview
This module covers the essential prerequisites and setup required for building the IoT data pipeline.

## Prerequisites

### 1. AWS Account Setup
- Active AWS account with appropriate permissions
- AWS CLI configured with credentials
- Access to the following AWS services:
  - S3
  - Lambda
  - Kinesis Data Firehose
  - IoT Core
  - IAM
  - Secrets Manager

### 2. Tools Installation
```bash
# Install Terraform
brew install terraform  # macOS
# or
wget https://releases.hashicorp.com/terraform/1.12.2/terraform_1.12.2_linux_amd64.zip

# Verify installation
terraform version

# Install AWS CLI
pip install awscli
aws --version
```

### 3. AWS Credentials Configuration
```bash
# Configure AWS credentials
aws configure
# Enter:
# - AWS Access Key ID
# - AWS Secret Access Key
# - Default region (us-west-1)
# - Default output format (json)

# Verify credentials
aws sts get-caller-identity
```

### 4. Project Structure
```
project/
├── terraform/
│   ├── EC2_ssm.tf          # Existing EC2 infrastructure
│   ├── s3_bucket.tf        # S3 bucket for data storage
│   ├── lambda.tf           # Lambda function for data processing
│   ├── firehose.tf         # Firehose and IoT rule
│   └── lambda_function.py  # Lambda function code
└── LModule/                # Learning materials
```

## AWS Services Overview

### S3 (Simple Storage Service)
- **Purpose**: Long-term storage for processed IoT data
- **Role**: Archive processed data in compressed format
- **Key Features**: Versioning, encryption, lifecycle policies

### Lambda
- **Purpose**: Serverless compute for data processing
- **Role**: Process IoT data and store in MySQL database
- **Key Features**: Auto-scaling, event-driven, pay-per-use

### Kinesis Data Firehose
- **Purpose**: Real-time data delivery service
- **Role**: Buffer and deliver IoT data to Lambda and S3
- **Key Features**: Auto-scaling, data transformation, multiple destinations

### IoT Core
- **Purpose**: Managed IoT platform
- **Role**: Receive IoT device data and route to processing services
- **Key Features**: Device registry, message routing, security

### IAM (Identity and Access Management)
- **Purpose**: Security and access control
- **Role**: Control access between services
- **Key Features**: Roles, policies, fine-grained permissions

## Next Steps
Proceed to Module 2 to create the S3 bucket foundation for the pipeline.