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

# Output
output "lambda_function_name" {
  value = aws_lambda_function.iot_data_processor.function_name
}

output "lambda_function_arn" {
  value = aws_lambda_function.iot_data_processor.arn
}