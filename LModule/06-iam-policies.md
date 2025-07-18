# Module 6: IAM Policies and Roles - Complete Security Model

## Overview
This module provides a comprehensive breakdown of all IAM roles, policies, and permissions used in the IoT pipeline, explaining how they work together to secure the system.

## IAM Security Architecture

### Security Principle: Least Privilege
- Each service gets only the minimum permissions needed
- Resource-specific permissions where possible
- No wildcard permissions unless absolutely necessary
- Regular permission auditing and review

### Trust Relationships
Each service needs to **trust** other services to perform actions on its behalf:
```
IoT Core → Firehose → Lambda → S3
   ↓         ↓         ↓       ↓
  Trust    Trust    Trust   Trust
```

## Complete IAM Roles and Policies Breakdown

### 1. Lambda Execution Role

#### Role Definition
```hcl
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
```

**Trust Policy Analysis:**
- **Principal**: `lambda.amazonaws.com`
- **Action**: `sts:AssumeRole`
- **Purpose**: Allows Lambda service to assume this role
- **When Used**: Every Lambda function invocation

#### Lambda Policy
```hcl
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
```

**Permission Breakdown:**
- **CloudWatch Logs**: Function can write logs for debugging
- **Secrets Manager**: Access to specific database secret only
- **Resource Scope**: Limited to specific secret ARN

### 2. Firehose Delivery Role

#### Role Definition
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

**Trust Policy Analysis:**
- **Principal**: `firehose.amazonaws.com`
- **Purpose**: Allows Firehose service to assume this role
- **When Used**: Data delivery operations

#### Firehose Policy
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
- **S3 Operations**: Write data to specific bucket
  - `s3:PutObject`: Upload processed data
  - `s3:AbortMultipartUpload`: Handle failed uploads
  - `s3:GetBucketLocation`: Verify bucket region
  - `s3:ListBucket`: List bucket contents
- **Lambda Operations**: Invoke data processing function
  - `lambda:InvokeFunction`: Execute Lambda function
  - `lambda:GetFunctionConfiguration`: Get function details
- **CloudWatch Logs**: Write delivery logs

### 3. IoT Rule Role

#### Role Definition
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

**Trust Policy Analysis:**
- **Principal**: `iot.amazonaws.com`
- **Purpose**: Allows IoT Core service to assume this role
- **When Used**: IoT rule execution

#### IoT Rule Policy
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
- **Firehose Operations**: Send data to specific stream
  - `firehose:PutRecord`: Send individual records
  - `firehose:PutRecordBatch`: Send multiple records efficiently
- **Resource Scope**: Limited to specific Firehose stream ARN

### 4. Cross-Service Permissions

#### Lambda Permission for Firehose
```hcl
resource "aws_lambda_permission" "firehose_lambda_permission" {
  statement_id  = "AllowExecutionFromFirehose"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.iot_data_processor.function_name
  principal     = "firehose.amazonaws.com"
  source_arn    = aws_kinesis_firehose_delivery_stream.o2_arena_stream.arn
}
```

**Resource-Based Permission:**
- **Type**: Lambda function resource policy
- **Allows**: Specific Firehose stream to invoke Lambda
- **Security**: Limited to specific source ARN

## IAM Role Bindings and Assignments

### 1. Service-to-Role Assignments

#### Lambda Function → Lambda Role
```hcl
resource "aws_lambda_function" "iot_data_processor" {
  # ... other configuration
  role = aws_iam_role.lambda_role.arn
}
```

#### Firehose Stream → Firehose Role
```hcl
resource "aws_kinesis_firehose_delivery_stream" "o2_arena_stream" {
  # ... other configuration
  extended_s3_configuration {
    role_arn = aws_iam_role.firehose_role.arn
    # ... other configuration
  }
}
```

#### IoT Rule → IoT Role
```hcl
resource "aws_iot_topic_rule" "o2_arena_motion_rule" {
  # ... other configuration
  firehose {
    role_arn = aws_iam_role.iot_rule_role.arn
    # ... other configuration
  }
}
```

### 2. Permission Flow Diagram

```
IoT Device → IoT Core Topic
                  ↓
            [IoT Rule Role]
                  ↓
              Firehose Stream
                  ↓
            [Firehose Role]
                  ↓
              Lambda Function
                  ↓
            [Lambda Role]
                  ↓
         Secrets Manager + Database
                  ↓
            [Lambda Role]
                  ↓
              S3 Bucket
```

## Security Best Practices Implemented

### 1. Principle of Least Privilege
- **Resource-Specific ARNs**: Permissions limited to exact resources
- **Action-Specific**: Only required actions granted
- **Time-Limited**: No permanent credentials

### 2. Defense in Depth
- **Multiple Security Layers**: IAM + Resource policies + Network security
- **Encryption**: At rest and in transit
- **Monitoring**: CloudTrail logs all access

### 3. Separation of Concerns
- **Service-Specific Roles**: Each service has dedicated role
- **Policy Isolation**: Policies attached to specific roles
- **Cross-Service Permissions**: Explicitly granted

## Common Security Issues and Solutions

### 1. "Access Denied" Errors

#### Troubleshooting Steps
```bash
# Check role trust policy
aws iam get-role --role-name o2-arena-lambda-execution-role

# Check policy permissions
aws iam get-role-policy \
  --role-name o2-arena-lambda-execution-role \
  --policy-name o2-arena-lambda-policy

# Check resource-based policies
aws lambda get-policy \
  --function-name o2-arena-iot-data-processor
```

#### Common Fixes
1. **Wrong Resource ARN**: Verify ARN in policy matches actual resource
2. **Missing Permission**: Add required action to policy
3. **Trust Policy**: Ensure service can assume role

### 2. "Invalid Principal" Errors

#### Check Service Principals
```bash
# Valid service principals for our services:
# lambda.amazonaws.com
# firehose.amazonaws.com
# iot.amazonaws.com

# Verify in trust policy
aws iam get-role --role-name [role-name] \
  --query 'Role.AssumeRolePolicyDocument'
```

### 3. Cross-Region Issues

#### Region-Specific Considerations
- **S3 Bucket Region**: Must match Firehose region
- **Lambda Region**: Must match Firehose region
- **IAM Roles**: Global but resources must be same region

## Security Monitoring

### 1. CloudTrail Logging
```bash
# Monitor role assumptions
aws logs filter-log-events \
  --log-group-name CloudTrail/YourTrailName \
  --filter-pattern "{ $.eventName = AssumeRole }"

# Monitor policy changes
aws logs filter-log-events \
  --log-group-name CloudTrail/YourTrailName \
  --filter-pattern "{ $.eventSource = iam.amazonaws.com }"
```

### 2. Access Analyzer
```bash
# Check for external access
aws accessanalyzer create-analyzer \
  --analyzer-name iot-pipeline-analyzer \
  --type ACCOUNT

# Get findings
aws accessanalyzer list-findings \
  --analyzer-arn arn:aws:access-analyzer:region:account:analyzer/iot-pipeline-analyzer
```

## Policy Testing

### 1. IAM Policy Simulator
```bash
# Test Lambda role permissions
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::ACCOUNT:role/o2-arena-lambda-execution-role \
  --action-names secretsmanager:GetSecretValue \
  --resource-arns arn:aws:secretsmanager:region:account:secret:db_credentials_iot_project-suffix
```

### 2. Dry Run Testing
```bash
# Test S3 permissions
aws s3 cp test.txt s3://bucket-name/test.txt --dryrun

# Test Lambda invoke
aws lambda invoke \
  --function-name o2-arena-iot-data-processor \
  --payload '{"test": true}' \
  --dry-run response.json
```

## Role Lifecycle Management

### 1. Role Rotation
- **Regular Review**: Quarterly permission audits
- **Unused Roles**: Remove unused roles and policies
- **Permission Creep**: Monitor for excessive permissions

### 2. Compliance
- **SOC 2**: Role-based access control
- **GDPR**: Data access logging
- **HIPAA**: Audit trails and access controls

## Next Steps
Proceed to Module 7 to understand the complete data flow through the pipeline.