# Task 1: Set up AWS CLI and configure credentials

## What is AWS CLI?
AWS CLI (Command Line Interface) is a tool that allows you to interact with AWS services from your command line/terminal. It's essential for deploying and managing AWS resources programmatically.

## Step-by-Step Instructions for Beginners:

### Step 1: Check if AWS CLI is already installed
First, let's see if you already have AWS CLI installed on your system.

**For macOS/Linux:**
```bash
aws --version
```

**For Windows:**
```cmd
aws --version
```

If you get a version number, AWS CLI is already installed. If you get "command not found" or similar error, you need to install it.

### Step 2: Install AWS CLI (if not already installed)

**For macOS:**
```bash
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
sudo installer -pkg AWSCLIV2.pkg -target /
```

**For Linux:**
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

**For Windows:**
- Download the AWS CLI MSI installer from: https://awscli.amazonaws.com/AWSCLIV2.msi
- Run the installer and follow the instructions

### Step 3: Create AWS Account and Get Credentials
Before configuring AWS CLI, you need:

1. **AWS Account**: If you don't have one, sign up at https://aws.amazon.com/
2. **IAM User with programmatic access**:
   - Go to AWS Console → IAM → Users → Create User
   - Choose "Programmatic access"
   - Attach policies like "AdministratorAccess" (for learning purposes)
   - Save the **Access Key ID** and **Secret Access Key**

### Step 4: Configure AWS CLI
Run the configuration command:
```bash
aws configure
```

You'll be prompted to enter:
1. **AWS Access Key ID**: [Your access key from Step 3]
2. **AWS Secret Access Key**: [Your secret key from Step 3]
3. **Default region name**: `us-west-1` (required for this project)
4. **Default output format**: `json` (recommended)

### Step 5: Test the Configuration
Verify your AWS CLI is working:
```bash
aws sts get-caller-identity
```

This should return information about your AWS account, including:
- Account ID
- User ARN
- User ID

### Step 6: Update Project Configuration (Important!)
The project is hardcoded to use account ID `443370692694`. You need to update this in the code to match your actual AWS account ID.

**Files to update:**
- `app.py` line 12: Change the account ID to your actual account ID
- `EC2_ssm.tf`: Update any account-specific references if needed

### Expected Output:
When successful, `aws sts get-caller-identity` should return something like:
```json
{
    "UserId": "AIDACKCEVSQ6C2EXAMPLE",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/your-username"
}
```

### Common Issues and Solutions:
- **Permission denied**: Make sure your IAM user has sufficient permissions
- **Invalid credentials**: Double-check your access keys
- **Region issues**: Ensure you're using `us-west-1` as specified in the project

### Security Best Practices:
- Never share your AWS access keys
- Use IAM roles instead of access keys when possible
- Enable MFA (Multi-Factor Authentication) on your AWS account
- Regularly rotate your access keys

### Next Steps:
Once you complete these steps, we can move to Task 2: Installing and configuring AWS CDK.

### Verification Checklist:
- [ ] AWS CLI installed and showing version
- [ ] AWS credentials configured
- [ ] `aws sts get-caller-identity` returns your account information
- [ ] Account ID updated in project files
- [ ] Default region set to `us-west-1`

**Status**: Task 1 complete when all checklist items are verified.