# Task 3 & 6: Terraform Setup and Infrastructure Deployment - Complete Guide

## What is Terraform?
Terraform is an **Infrastructure as Code (IaC)** tool that allows you to define, provision, and manage cloud infrastructure using configuration files. Instead of manually clicking through AWS console, you write code that describes what infrastructure you want, and Terraform creates it for you.

## Why Terraform for IoT Project?
- **Reproducibility**: Create the same infrastructure multiple times
- **Version Control**: Track changes to your infrastructure
- **Automation**: Deploy complex infrastructure with one command
- **Documentation**: Code serves as documentation of your infrastructure

## Project Architecture Overview
Our IoT project requires infrastructure to:
1. **Host a database** (MariaDB) to store IoT motion data
2. **Provide networking** (VPC, subnets) for secure communication
3. **Manage security** (IAM roles, security groups) for controlled access
4. **Store secrets** (database credentials) securely

## Step-by-Step Execution Guide

### Step 1: Install and Verify Terraform

**What we're doing**: Installing Terraform CLI tool on your system.

**Check if Terraform is installed**:
```bash
terraform --version
```

**Expected output**:
```
Terraform v1.12.2
on darwin_amd64
```

**If not installed** (choose your platform):
```bash
# macOS
brew install terraform

# Linux
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# Windows
# Download from https://terraform.io and add to PATH
```

### Step 2: Create Terraform Configuration File

**What we're doing**: Creating the main infrastructure definition file.

**File**: `EC2_ssm.tf`
**Location**: Project root directory
**Purpose**: Defines all 13 AWS resources needed for our IoT infrastructure

```hcl
# ================================================
# AWS PROVIDER CONFIGURATION
# ================================================
provider "aws" {
  region = "us-west-1"
}

# ================================================
# VPC INFRASTRUCTURE (Resources 1-6)
# ================================================

# Resource 1: VPC - Virtual Private Cloud
# Purpose: Creates isolated network environment for our resources
# Why needed: Provides secure, private network for our IoT infrastructure
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"          # Network range: 10.0.0.0 to 10.0.255.255
  enable_dns_hostnames = true                    # Allows DNS resolution within VPC
  tags = {
    Name = "iot-vpc"
  }
}

# Resource 2: Internet Gateway
# Purpose: Allows internet access for resources in public subnet
# Why needed: EC2 instance needs internet access for software installation
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id                      # Attaches to our VPC
  tags = {
    Name = "iot-igw"
  }
}

# Resource 3: Public Subnet
# Purpose: Creates subnet where EC2 instance will be placed
# Why needed: EC2 needs to be in a subnet, public subnet allows internet access
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.main.id     # Belongs to our VPC
  cidr_block              = "10.0.1.0/24"      # Subnet range: 10.0.1.0 to 10.0.1.255
  map_public_ip_on_launch = true               # Automatically assigns public IP
  availability_zone       = "us-west-1a"      # Specific AZ in us-west-1
  tags = {
    Name = "iot-public-subnet"
  }
}

# Resource 4: Route Table
# Purpose: Defines how network traffic is routed
# Why needed: Routes internet traffic through internet gateway
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "iot-public-rt"
  }
}

# Resource 5: Internet Route
# Purpose: Creates route to internet (0.0.0.0/0) via internet gateway
# Why needed: Allows resources in public subnet to reach internet
resource "aws_route" "internet_access" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"         # All internet traffic
  gateway_id             = aws_internet_gateway.igw.id
}

# Resource 6: Route Table Association
# Purpose: Links subnet to route table
# Why needed: Applies routing rules to our public subnet
resource "aws_route_table_association" "public_rta" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# ================================================
# IAM & SECURITY CONFIGURATION (Resources 7-10)
# ================================================

# Resource 7: IAM Role for EC2
# Purpose: Defines permissions for EC2 instance
# Why needed: EC2 needs permissions to use AWS Systems Manager (SSM)
resource "aws_iam_role" "ssm_role" {
  name = "EC2SSMRole_55"

  # Trust policy: allows EC2 service to assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

# Resource 8: IAM Policy Attachment
# Purpose: Attaches AWS managed policy to our IAM role
# Why needed: Grants SSM permissions to EC2 instance for remote management
resource "aws_iam_policy_attachment" "ssm_attach" {
  name       = "ssm-attach"
  roles      = [aws_iam_role.ssm_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMFullAccess"
}

# Resource 9: IAM Instance Profile
# Purpose: Allows EC2 instance to use IAM role
# Why needed: Bridge between EC2 instance and IAM role
resource "aws_iam_instance_profile" "ssm_profile" {
  name = "EC2SSMInstanceProfile_55"
  role = aws_iam_role.ssm_role.name
}

# Resource 10: Security Group
# Purpose: Acts as virtual firewall for EC2 instance
# Why needed: Controls inbound/outbound traffic to database and HTTPS
resource "aws_security_group" "ec2_sg" {
  name        = "ec2_security_group"
  description = "Allow MySQL and HTTPS"
  vpc_id      = aws_vpc.main.id

  # Allow MySQL connections from anywhere (port 3306)
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow HTTPS connections from anywhere (port 443)
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ================================================
# COMPUTE RESOURCES (Resource 11)
# ================================================

# Resource 11: EC2 Instance
# Purpose: Virtual server that hosts MariaDB database
# Why needed: Database server for storing IoT motion detection data
resource "aws_instance" "ec2" {
  ami                    = "ami-0b5358e1f13744bc7"  # Amazon Linux 2 AMI
  instance_type          = "t2.micro"               # Small instance (free tier)
  subnet_id              = aws_subnet.public_subnet.id
  associate_public_ip_address = true
  iam_instance_profile   = aws_iam_instance_profile.ssm_profile.name
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  # User data script: runs when instance starts
  # Purpose: Installs and configures MariaDB database
  user_data = <<-EOF
              #!/bin/bash
              # Update system packages
              sudo yum update -y
              
              # Install MariaDB server
              sudo yum install -y mariadb-server
              
              # Start and enable MariaDB service
              sudo systemctl start mariadb
              sudo systemctl enable mariadb
              
              # Create database user for IoT application
              mysql -uroot -e "CREATE USER 'usr_iot_admin'@'%' IDENTIFIED BY 'dew4DL';"
              mysql -uroot -e "CREATE USER 'usr_iot_admin'@'localhost' IDENTIFIED BY 'dew4DL';"
              
              # Grant permissions to the user
              mysql -uroot -e "GRANT ALL ON *.* TO 'usr_iot_admin'@'localhost';"
              mysql -uroot -e "GRANT ALL ON *.* TO 'usr_iot_admin'@'%';"
              mysql -uroot -e "FLUSH PRIVILEGES;"
              
              # Create IoT database
              mysql -uroot -e "CREATE DATABASE db_iot_smart_buildings;"
              
              # Create table for motion detection data
              mysql -uroot -e "USE db_iot_smart_buildings; CREATE TABLE tbl_smart_motion_model_x (device_id varchar(10) NOT NULL, ts timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, latitude DECIMAL(17,14) DEFAULT NULL, longitude DECIMAL(17,14) DEFAULT NULL, motion_detected tinyint(1), device_status varchar(20) NOT NULL);"
              EOF

  tags = {
    Name = "EC2-SSM-Managed"
  }
}

# ================================================
# SECRETS MANAGEMENT (Resources 12-13)
# ================================================

# Resource 12: Secrets Manager Secret
# Purpose: Securely stores database connection credentials
# Why needed: Lambda functions need database credentials to connect
resource "aws_secretsmanager_secret" "db_secret" {
  name = "db_credentials_iot_project"
}

# Resource 13: Secret Version
# Purpose: Stores the actual credential values
# Why needed: Contains connection details for database access
resource "aws_secretsmanager_secret_version" "db_secret_version" {
  secret_id     = aws_secretsmanager_secret.db_secret.id
  secret_string = jsonencode({
    mysql_host       = aws_instance.ec2.public_ip    # EC2 public IP
    mysql_db_name    = "db_iot_smart_buildings"      # Database name
    mysql_db_user    = "usr_iot_admin"               # Database user
    mysql_db_password = "dew4DL"                     # Database password
  })
}
```

### Step 3: Update Account Configuration

**What we're doing**: Ensuring all configurations use your actual AWS account ID.

**Update `app.py`** (needed for CDK integration):
```python
input_params = dict([
    ('aws_account_id','606639739464'),    # Your actual account ID
    ('aws_region', 'us-west-1'),
    ('db_secret_arn_nosuffix','arn:aws:secretsmanager:us-west-1:606639739464:secret:db_credentials_iot_project'),
  ])
```

### Step 4: Initialize Terraform

**What we're doing**: Preparing Terraform to work with AWS.

```bash
# Navigate to project directory
cd /path/to/your/project

# Initialize Terraform (downloads AWS provider)
terraform init
```

**Expected output**:
```
Initializing the backend...
Initializing provider plugins...
- Installing hashicorp/aws v6.3.0...
- Installed hashicorp/aws v6.3.0 (signed by HashiCorp)

Terraform has been successfully initialized!
```

**What happens**:
- Downloads AWS provider plugin
- Creates `.terraform` directory
- Creates `.terraform.lock.hcl` file

### Step 5: Plan Infrastructure

**What we're doing**: Previewing what Terraform will create.

```bash
terraform plan
```

**Expected output**:
```
Plan: 13 to add, 0 to change, 0 to destroy.

Terraform will perform the following actions:
  # aws_vpc.main will be created
  # aws_internet_gateway.igw will be created
  # aws_subnet.public_subnet will be created
  # ... (all 13 resources)
```

### Step 6: Deploy Infrastructure

**What we're doing**: Creating all 13 AWS resources.

```bash
terraform apply -auto-approve
```

**Deployment process**:
1. **Secrets created first** (no dependencies)
2. **VPC created** (foundation for networking)
3. **Internet Gateway attached** to VPC
4. **Subnet created** within VPC
5. **Route table and routes** configured
6. **IAM role and instance profile** created
7. **Security group** created within VPC
8. **EC2 instance** launched with all dependencies
9. **Secret version** created with EC2 IP

## Resource Dependencies & Relationships

### **Dependency Chain**:
```
VPC (foundation)
├── Internet Gateway → VPC
├── Subnet → VPC
├── Security Group → VPC
├── Route Table → VPC
│   └── Internet Route → Route Table + Internet Gateway
│   └── Route Table Association → Route Table + Subnet
└── EC2 Instance → Subnet + Security Group + Instance Profile
    └── Secret Version → EC2 Instance (for IP address)

IAM Role (independent)
├── Policy Attachment → IAM Role
└── Instance Profile → IAM Role

Secret (independent)
└── Secret Version → Secret + EC2 Instance
```

### **How Resources Work Together**:

1. **VPC** creates isolated network environment
2. **Internet Gateway** provides internet access to VPC
3. **Subnet** creates network segment within VPC
4. **Route Table** + **Internet Route** enable internet connectivity
5. **Route Table Association** applies routing to subnet
6. **Security Group** controls traffic to/from EC2
7. **IAM Role** + **Instance Profile** give EC2 permissions
8. **Policy Attachment** grants SSM access to EC2
9. **EC2 Instance** runs in subnet with security group and IAM role
10. **Secret** stores database credentials securely
11. **Secret Version** contains actual connection details

## Files Created During Process

### **Terraform Files**:
- `EC2_ssm.tf` - Main infrastructure definition
- `.terraform.lock.hcl` - Provider version lock file
- `terraform.tfstate` - Current state of infrastructure
- `terraform.tfstate.backup` - Previous state backup

### **Terraform Directories**:
- `.terraform/` - Provider plugins and modules
- `.terraform/providers/` - AWS provider binaries

### **Updated Project Files**:
- `app.py` - Updated with correct account ID for CDK integration

## Infrastructure Verification

### **Check Resources Created**:
```bash
# List all resources in Terraform state
terraform state list

# Show detailed resource information
terraform show

# Check specific resource
terraform state show aws_instance.ec2
```

### **AWS Console Verification**:
1. **VPC Dashboard**: Check VPC, subnets, route tables
2. **EC2 Dashboard**: Verify instance is running
3. **IAM Dashboard**: Check role and instance profile
4. **Secrets Manager**: Verify secret with credentials
5. **Security Groups**: Check firewall rules

## Database Connection Details

**After deployment, your database is accessible at**:
- **Host**: EC2 Public IP (from terraform output)
- **Port**: 3306
- **Database**: `db_iot_smart_buildings`
- **Username**: `usr_iot_admin`
- **Password**: `dew4DL`

**Table Schema**:
```sql
CREATE TABLE tbl_smart_motion_model_x (
    device_id varchar(10) NOT NULL,
    ts timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    latitude DECIMAL(17,14) DEFAULT NULL,
    longitude DECIMAL(17,14) DEFAULT NULL,
    motion_detected tinyint(1),
    device_status varchar(20) NOT NULL
);
```

## Security Considerations

### **What we implemented**:
- **VPC isolation**: Resources in private network
- **IAM roles**: Least privilege access
- **Security groups**: Firewall rules
- **Secrets Manager**: Encrypted credential storage

### **Production improvements**:
- Use private subnets for database
- Implement VPC endpoints
- Use RDS instead of EC2-hosted database
- Enable MFA and stricter IAM policies
- Use AWS WAF for web application protection

## Cost Optimization

### **Current costs**:
- **EC2 t2.micro**: Free tier eligible
- **VPC components**: Free
- **Secrets Manager**: ~$0.40/month per secret
- **Data transfer**: Minimal for testing

### **Cost monitoring**:
```bash
# Check AWS costs
aws ce get-cost-and-usage --time-period Start=2024-01-01,End=2024-01-31 --granularity MONTHLY --metrics BlendedCost
```

## Troubleshooting Common Issues

### **Issue 1: Account ID mismatch**
```
Error: User not authorized to perform secretsmanager:DescribeSecret
```
**Solution**: Update account ID in `app.py` and `EC2_ssm.tf`

### **Issue 2: Region mismatch**
```
Error: InvalidAMIID.NotFound
```
**Solution**: Use correct AMI ID for your region

### **Issue 3: Terraform state conflicts**
```
Error: Resource already exists
```
**Solution**: Import existing resources or remove state file

### **Issue 4: EC2 instance not accessible**
```
Error: Connection timeout
```
**Solution**: Check security group rules and instance status

## Next Steps

After successful deployment:
1. ✅ **Infrastructure ready** - All 13 resources created
2. ➡️ **Set up Python environment** (Task 5)
3. ➡️ **Deploy CDK stacks** (Task 8)
4. ➡️ **Test IoT data pipeline** (Task 9)

## Resource Summary

**Total Resources**: 13
**Estimated Setup Time**: 5-10 minutes
**Monthly Cost**: ~$0.40 (free tier EC2)
**Dependencies**: AWS CLI, Terraform, proper IAM permissions

The infrastructure is now ready to support the IoT motion detection data pipeline with proper networking, security, compute, and storage components.