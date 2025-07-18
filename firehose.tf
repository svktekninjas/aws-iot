# --------------------
# Kinesis Data Firehose
# --------------------

# IAM role for Firehose
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

# IAM policy for Firehose
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

# Kinesis Data Firehose Delivery Stream
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

# Lambda permission for Firehose to invoke
resource "aws_lambda_permission" "firehose_lambda_permission" {
  statement_id  = "AllowExecutionFromFirehose"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.iot_data_processor.function_name
  principal     = "firehose.amazonaws.com"
  source_arn    = aws_kinesis_firehose_delivery_stream.o2_arena_stream.arn
}

# --------------------
# IoT Rule
# --------------------

# IAM role for IoT Rule
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

# IAM policy for IoT Rule
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

# IoT Topic Rule
resource "aws_iot_topic_rule" "o2_arena_motion_rule" {
  name        = "O2ArenaMotionRule"
  description = "Rule to process IoT motion data from O2 Arena devices"
  enabled     = true
  sql         = "SELECT * FROM '/iot-o2-arena-motion'"
  sql_version = "2016-03-23"

  firehose {
    delivery_stream_name = aws_kinesis_firehose_delivery_stream.o2_arena_stream.name
    role_arn            = aws_iam_role.iot_rule_role.arn
    separator           = "\n"
    batch_mode          = false
  }
}

# Outputs
output "firehose_stream_name" {
  value = aws_kinesis_firehose_delivery_stream.o2_arena_stream.name
}

output "iot_rule_name" {
  value = aws_iot_topic_rule.o2_arena_motion_rule.name
}