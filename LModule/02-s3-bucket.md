# Module 2: S3 Bucket Creation and Configuration

## Overview
This module covers creating an S3 bucket for storing processed IoT data with proper security and configuration.

## S3 Bucket Role in IoT Pipeline
The S3 bucket serves as the **final destination** for processed IoT data:
- Stores compressed data files from Firehose
- Provides long-term archival storage
- Enables data analytics and reporting
- Maintains data durability and availability

## Terraform Code Explanation

### 1. S3 Bucket Resource
```hcl
resource "aws_s3_bucket" "o2_arena_bucket" {
  bucket = "o2-arena-iot-data-bucket-${random_string.bucket_suffix.result}"
  
  tags = {
    Name        = "O2Arena-IoT-Data-Bucket"
    Environment = "dev"
    Project     = "IoT-Smart-Buildings"
  }
}
```

**Code Breakdown:**
- `bucket`: Unique bucket name with random suffix for global uniqueness
- `tags`: Metadata for resource organization and cost tracking
- Bucket names must be globally unique across all AWS accounts

### 2. Random String Generator
```hcl
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}
```

**Purpose:**
- Ensures bucket name uniqueness
- Prevents naming conflicts
- Creates reproducible random suffixes

### 3. Bucket Versioning
```hcl
resource "aws_s3_bucket_versioning" "o2_arena_bucket_versioning" {
  bucket = aws_s3_bucket.o2_arena_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}
```

**Benefits:**
- Protects against accidental deletion
- Maintains historical versions of data
- Enables data recovery capabilities

### 4. Encryption Configuration
```hcl
resource "aws_s3_bucket_server_side_encryption_configuration" "o2_arena_bucket_encryption" {
  bucket = aws_s3_bucket.o2_arena_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
```

**Security Features:**
- **AES256**: AWS-managed encryption keys
- **Server-side encryption**: Data encrypted at rest
- **Automatic**: All objects encrypted by default

### 5. Public Access Block
```hcl
resource "aws_s3_bucket_public_access_block" "o2_arena_bucket_pab" {
  bucket = aws_s3_bucket.o2_arena_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

**Security Hardening:**
- Blocks all public access
- Prevents accidental data exposure
- Follows AWS security best practices

## Step-by-Step Deployment

### 1. Create the Terraform File
```bash
# Create s3_bucket.tf file with the above configuration
vi s3_bucket.tf
```

### 2. Initialize Terraform
```bash
terraform init
```

### 3. Plan the Deployment
```bash
terraform plan -target=aws_s3_bucket.o2_arena_bucket
```

### 4. Apply the Configuration
```bash
terraform apply -target=aws_s3_bucket.o2_arena_bucket -auto-approve
```

### 5. Verify Creation
```bash
# List buckets
aws s3 ls

# Check bucket details
aws s3api get-bucket-location --bucket <bucket-name>
```

## Expected Outputs
```
s3_bucket_arn = "arn:aws:s3:::o2-arena-iot-data-bucket-9eby42ws"
s3_bucket_name = "o2-arena-iot-data-bucket-9eby42ws"
```

## Security Considerations
1. **Encryption**: All data encrypted at rest
2. **Access Control**: No public access allowed
3. **Versioning**: Enabled for data protection
4. **Monitoring**: CloudTrail logs all access

## Best Practices Implemented
- Unique naming with random suffixes
- Comprehensive tagging strategy
- Defense-in-depth security
- Infrastructure as code

## Common Issues and Solutions
1. **Bucket name conflicts**: Random suffix resolves this
2. **Permission errors**: Ensure proper IAM permissions
3. **Region mismatch**: Verify AWS CLI region configuration

## Next Steps
Proceed to Module 3 to create the Lambda function for data processing.