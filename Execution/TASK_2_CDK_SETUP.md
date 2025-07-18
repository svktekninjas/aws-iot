# Task 2: Install and configure AWS CDK - Complete Setup from Scratch

## What is AWS CDK?
AWS CDK (Cloud Development Kit) is a framework that allows you to define cloud infrastructure using familiar programming languages like Python, TypeScript, Java, etc. It generates CloudFormation templates from your code and deploys them to AWS.

## Why do we need CDK for this IoT project?
- **Infrastructure as Code**: Define AWS resources (S3, Lambda, IoT rules, Kinesis Firehose) using Python
- **Type Safety**: Catch errors before deployment
- **Reusability**: Create reusable components
- **Integration**: Seamlessly integrate multiple AWS services

## Prerequisites for Task 2:
- Task 1 completed (AWS CLI configured)
- Node.js installed (CDK CLI runs on Node.js)
- npm available (Node Package Manager)

## Step-by-Step Task 2 Execution:

### Step 1: Verify Node.js and npm installation
First, we need to ensure Node.js is available because CDK CLI is built on Node.js.

```bash
node --version
npm --version
```

**What we did in our execution:**
```bash
$ node --version
v18.12.1
$ npm --version
8.19.2
```

**Why Node.js is needed:**
- CDK CLI is a Node.js application
- Even though we write Python code, CDK's core engine runs on Node.js
- npm is used to install CDK globally

### Step 2: Install AWS CDK globally
Install CDK CLI so we can use `cdk` commands from anywhere.

```bash
npm install -g aws-cdk
```

**What we did in our execution:**
```bash
$ npm install -g aws-cdk
added 2 packages, and audited 3 packages in 1s
found 0 vulnerabilities
```

**Why global installation:**
- Makes `cdk` command available system-wide
- No need to prefix with `npx` or navigate to specific directories

### Step 3: Verify CDK installation
Check if CDK is properly installed and accessible.

```bash
cdk --version
```

**What we did in our execution:**
```bash
$ cdk --version
2.1021.0 (build 059c862)
```

### Step 4: Create and configure project files
Now we need to create the essential files for CDK to work with our project.

#### File 1: `cdk.json` - CDK Configuration File

**Why we need this file:**
- Tells CDK how to run our application
- Defines which command to execute (`python3 app.py`)
- Contains CDK-specific settings and context

**File location:** `/project-root/cdk.json`

**Code snippet we need:**
```json
{
  "app": "python3 app.py",
  "watch": {
    "include": [
      "**"
    ],
    "exclude": [
      "README.md",
      "cdk*.json",
      "requirements*.txt",
      "source.bat",
      "**/__init__.py",
      "python/__pycache__",
      "tests"
    ]
  },
  "context": {
    "@aws-cdk/aws-lambda:recognizeLayerVersion": true,
    "@aws-cdk/core:checkSecretUsage": true,
    "@aws-cdk/core:target-partitions": [
      "aws",
      "aws-cn"
    ],
    "@aws-cdk-containers/ecs-service-extensions:enableDefaultLogDriver": true,
    "@aws-cdk/aws-ec2:uniqueImdsv2TemplateName": true,
    "@aws-cdk/aws-ecs:arnFormatIncludesClusterName": true,
    "@aws-cdk/aws-iam:minimizePolicies": true,
    "@aws-cdk/core:validateSnapshotRemovalPolicy": true,
    "@aws-cdk/aws-codepipeline:crossAccountKeyAliasStackSafeResourceName": true,
    "@aws-cdk/aws-s3:createDefaultLoggingPolicy": true,
    "@aws-cdk/aws-sns-subscriptions:restrictSqsDescryption": true,
    "@aws-cdk/aws-apigateway:disableCloudWatchRole": true,
    "@aws-cdk/core:enablePartitionLiterals": true,
    "@aws-cdk/aws-events:eventsTargetQueueSameAccount": true,
    "@aws-cdk/aws-iam:standardizedServicePrincipals": true,
    "@aws-cdk/aws-ecs:disableExplicitDeploymentControllerForCircuitBreaker": true,
    "@aws-cdk/aws-iam:importedRoleStackSafeDefaultPolicyName": true,
    "@aws-cdk/aws-s3:serverAccessLogsUseBucketPolicy": true,
    "@aws-cdk/aws-route53-patters:useCertificate": true,
    "@aws-cdk/customresources:installLatestAwsSdkDefault": false,
    "@aws-cdk/aws-rds:databaseProxyUniqueResourceName": true,
    "@aws-cdk/aws-codedeploy:removeAlarmsFromDeploymentGroup": true,
    "@aws-cdk/aws-apigateway:authorizerChangeDeploymentLogicalId": true,
    "@aws-cdk/aws-ec2:launchTemplateDefaultUserData": true,
    "@aws-cdk/aws-secretsmanager:useAttachedSecretResourcePolicyForSecretTargetAttachments": true,
    "@aws-cdk/aws-redshift:columnId": true,
    "@aws-cdk/aws-stepfunctions-tasks:enableEmrServicePolicyV2": true
  }
}
```

**What we did in our execution:**
- We had to fix the existing `cdk.json` file
- Changed `"app": "python app.py"` to `"app": "python3 app.py"`
- This was necessary because macOS uses `python3` command instead of `python`

#### File 2: `app.py` - Main CDK Application Entry Point

**Why we need this file:**
- Entry point for the entire CDK application
- Defines AWS environment (account, region)
- Orchestrates different stacks (S3, Lambda, IoT)
- Contains configuration parameters

**File location:** `/project-root/app.py`

**Code snippet we need:**
```python
#!/usr/bin/env python3
from aws_cdk import Environment
from aws_cdk import App
from s3_stack.o2_arena_cdk_s3_stack import O2ArenaS3Stack
from lambda_firehose_stack.o2_arena_cdk_lambda_firehose_stack import O2ArenaLambdaFirehoseStack

""" Config settings:
    The hard-coded values can be input parameters or pulled from config files,
    once the code is released to production.
"""
input_params = dict([
    ('aws_account_id','YOUR_ACCOUNT_ID'),  # Replace with actual account ID
    ('aws_region', 'us-west-1'),
    ('db_secret_arn_nosuffix','arn:aws:secretsmanager:us-west-1:YOUR_ACCOUNT_ID:secret:db_credentials_11'),
  ])

# AWS Settings
app = App()
env_oregon = Environment(account=input_params['aws_account_id'], region=input_params['aws_region'])

# Stacks definition
s3_stack = O2ArenaS3Stack(app, "o2-arena-s3-stack", 
                                input_metadata=input_params, 
                                env=env_oregon)

lambda_firehose_stack = O2ArenaLambdaFirehoseStack(app, "o2-arena-lambda-firehose-stack", 
                                input_metadata=input_params,
                                input_s3_bucket_arn=s3_stack.bucket.bucket_arn,
                                env=env_oregon)

app.synth()
```

**Integration in execution flow:**
- `app.py` is the entry point when CDK runs
- It imports and instantiates different stack classes
- Passes configuration parameters between stacks
- Calls `app.synth()` to generate CloudFormation templates

#### File 3: `requirements.txt` - Python Dependencies

**Why we need this file:**
- Lists all Python packages required for CDK
- Ensures consistent dependency versions
- Used by `pip install -r requirements.txt`

**File location:** `/project-root/requirements.txt`

**Code snippet we need:**
```txt
aws-cdk-lib>=2.0.0
constructs>=10.0.0
pymysql
```

**What each dependency does:**
- `aws-cdk-lib`: Core CDK library for Python
- `constructs`: Base classes for CDK constructs
- `pymysql`: MySQL connector for Lambda function

#### File 4: `requirements-dev.txt` - Development Dependencies

**Why we need this file:**
- Contains development-only dependencies
- Separate from production requirements
- Used for testing and development

**File location:** `/project-root/requirements-dev.txt`

**Code snippet we need:**
```txt
pytest>=6.2.5
```

### Step 5: Bootstrap CDK in AWS Account

**Why bootstrap is needed:**
- Creates S3 bucket for storing CDK assets (Lambda code, templates)
- Sets up IAM roles for CDK deployment
- One-time setup per AWS account/region combination

**What we did in our execution:**
```bash
# We created a temporary directory to avoid Python dependency issues
mkdir temp-bootstrap
cd temp-bootstrap

# Bootstrap CDK for our account and region
cdk bootstrap aws://606639739464/us-west-1
```

**Output we received:**
```
⏳  Bootstrapping environment aws://606639739464/us-west-1...
Trusted accounts for deployment: (none)
Trusted accounts for lookup: (none)
Using default execution policy of 'arn:aws:iam::aws:policy/AdministratorAccess'
CDKToolkit: creating CloudFormation changeset...
[12 resources created including S3 bucket, IAM roles, ECR repository]
✅  Environment aws://606639739464/us-west-1 bootstrapped.
```

**What bootstrap created:**
1. **S3 Staging Bucket**: `cdk-<random-id>-assets-606639739464-us-west-1`
2. **IAM Roles**: 
   - CloudFormationExecutionRole
   - DeploymentActionRole
   - FilePublishingRole
   - ImagePublishingRole
   - LookupRole
3. **ECR Repository**: For container images
4. **SSM Parameter**: CDK bootstrap version tracking

### Step 6: File Integration in Execution Flow

**How files work together:**
1. **`cdk.json`** → Tells CDK to run `python3 app.py`
2. **`app.py`** → Entry point, imports stack classes, orchestrates deployment
3. **Stack files** → Define actual AWS resources (S3, Lambda, IoT)
4. **`requirements.txt`** → Lists dependencies needed for the code to run
5. **Bootstrap resources** → Provide the infrastructure for CDK to deploy

**Execution flow:**
```
cdk command → reads cdk.json → executes python3 app.py → imports stack classes → 
uses bootstrap resources → creates CloudFormation templates → deploys to AWS
```

## Complete Summary of Task 2 Execution:

### What we accomplished:
1. ✅ **Verified Node.js/npm**: Confirmed v18.12.1 and v8.19.2 available
2. ✅ **Installed CDK**: Successfully installed CDK v2.1021.0 globally
3. ✅ **Fixed Python path**: Updated `cdk.json` to use `python3` instead of `python`
4. ✅ **Bootstrapped CDK**: Created CDK infrastructure in AWS account 606639739464, us-west-1 region
5. ✅ **Created project structure**: Established foundation for CDK application

### Key files created/configured:
- `cdk.json`: CDK configuration and entry point
- `app.py`: Main application orchestrator
- `requirements.txt`: Python dependencies
- `requirements-dev.txt`: Development dependencies

### AWS resources created by bootstrap:
- S3 bucket for CDK assets
- IAM roles for deployment
- ECR repository for containers
- SSM parameter for version tracking
- CloudFormation stack: `CDKToolkit`

### Issues encountered and solved:
- **Python path issue**: System uses `python3` not `python`
- **Module import error**: Expected at this stage, will be resolved in Task 5
- **Bootstrap from project directory**: Avoided by using temporary directory

### Next steps preparation:
- CDK is now ready for stack deployment
- Python environment setup (Task 5) can proceed
- Bootstrap infrastructure is available for all future CDK operations

### Cost impact:
- Minimal S3 storage costs (few cents per month)
- IAM roles and ECR repository are free
- No ongoing compute charges

**Task 2 Status: COMPLETE ✅**

The CDK framework is now fully installed, configured, and bootstrapped in your AWS account. You can proceed with Python environment setup (Task 5) and eventually deploy the IoT infrastructure stacks.