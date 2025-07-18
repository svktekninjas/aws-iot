# IoT Data Pipeline Learning Module

## Overview
This learning module provides comprehensive step-by-step instructions for creating an IoT data pipeline using Terraform. The pipeline processes IoT motion sensor data from O2 Arena devices, transforming and storing it in both MySQL database and S3 for analytics.

## Architecture Overview
```
IoT Devices → IoT Core → Firehose → Lambda → MySQL Database
                    ↓
                  S3 Bucket (Archive)
```

## Module Structure
- `01-prerequisites.md` - Setup and prerequisites
- `02-s3-bucket.md` - S3 bucket creation and configuration
- `03-lambda-function.md` - Lambda function for data processing
- `04-firehose-stream.md` - Kinesis Data Firehose setup
- `05-iot-rule.md` - IoT Core rule configuration
- `06-iam-policies.md` - IAM roles and policies detailed explanation
- `07-pipeline-flow.md` - Complete data flow explanation
- `08-testing.md` - Testing and validation

## Learning Objectives
By completing this module, you will understand:
1. How to design and implement IoT data pipelines
2. Terraform infrastructure as code best practices
3. AWS service integration patterns
4. IAM security model for IoT applications
5. Data flow patterns in serverless architectures

## Prerequisites
- AWS CLI configured with appropriate permissions
- Terraform installed (v1.12+)
- Basic understanding of AWS services
- Python knowledge for Lambda function understanding

## Getting Started
Start with `01-prerequisites.md` and follow the modules in order.