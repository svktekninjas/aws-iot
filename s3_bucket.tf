# --------------------
# S3 Bucket for IoT Data
# --------------------

resource "aws_s3_bucket" "o2_arena_bucket" {
  bucket = "o2-arena-iot-data-bucket-${random_string.bucket_suffix.result}"
  
  tags = {
    Name        = "O2Arena-IoT-Data-Bucket"
    Environment = "dev"
    Project     = "IoT-Smart-Buildings"
  }
}

resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket_versioning" "o2_arena_bucket_versioning" {
  bucket = aws_s3_bucket.o2_arena_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "o2_arena_bucket_encryption" {
  bucket = aws_s3_bucket.o2_arena_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "o2_arena_bucket_pab" {
  bucket = aws_s3_bucket.o2_arena_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Output the bucket name for use in other modules
output "s3_bucket_name" {
  value = aws_s3_bucket.o2_arena_bucket.id
}

output "s3_bucket_arn" {
  value = aws_s3_bucket.o2_arena_bucket.arn
}