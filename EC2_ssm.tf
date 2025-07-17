provider "aws" {
  region = "us-west-1"
}

# --------------------
# VPC Infrastructure
# --------------------

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "iot-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "iot-igw"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-west-1a"
  tags = {
    Name = "iot-public-subnet"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "iot-public-rt"
  }
}

resource "aws_route" "internet_access" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_rta" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# --------------------
# IAM & SSM Setup
# --------------------

resource "aws_iam_role" "ssm_role" {
  name = "EC2SSMRole_55"

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

resource "aws_iam_policy_attachment" "ssm_attach" {
  name       = "ssm-attach"
  roles      = [aws_iam_role.ssm_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMFullAccess"
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "EC2SSMInstanceProfile_55"
  role = aws_iam_role.ssm_role.name
}

# --------------------
# Security Group
# --------------------

resource "aws_security_group" "ec2_sg" {
  name        = "ec2_security_group"
  description = "Allow MySQL and HTTPS"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --------------------
# EC2 Instance
# --------------------

resource "aws_instance" "ec2" {
  ami                    = "ami-0b5358e1f13744bc7" 
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public_subnet.id
  associate_public_ip_address = true
  iam_instance_profile   = aws_iam_instance_profile.ssm_profile.name
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install -y mariadb-server
              sudo systemctl start mariadb
              sudo systemctl enable mariadb
              mysql -uroot -e "CREATE USER 'usr_iot_admin'@'%' IDENTIFIED BY 'dew4DL';"
              mysql -uroot -e "CREATE USER 'usr_iot_admin'@'localhost' IDENTIFIED BY 'dew4DL';"
              mysql -uroot -e "GRANT ALL ON *.* TO 'usr_iot_admin'@'localhost';"
              mysql -uroot -e "GRANT ALL ON *.* TO 'usr_iot_admin'@'%';"
              mysql -uroot -e "FLUSH PRIVILEGES;"
              mysql -uroot -e "CREATE DATABASE db_iot_smart_buildings;"
              mysql -uroot -e "USE db_iot_smart_buildings; CREATE TABLE tbl_smart_motion_model_x (device_id varchar(10) NOT NULL, ts timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, latitude DECIMAL(17,14) DEFAULT NULL, longitude DECIMAL(17,14) DEFAULT NULL, motion_detected tinyint(1), device_status varchar(20) NOT NULL);"
              EOF

  tags = {
    Name = "EC2-SSM-Managed"
  }
}

# --------------------
# Secrets Manager
# --------------------

resource "aws_secretsmanager_secret" "db_secret" {
  name = "db_credentials_11"
}

resource "aws_secretsmanager_secret_version" "db_secret_version" {
  secret_id     = aws_secretsmanager_secret.db_secret.id
  secret_string = jsonencode({
    mysql_host       = aws_instance.ec2.public_ip
    mysql_db_name    = "db_iot_smart_buildings"
    mysql_db_user    = "usr_iot_admin"
    mysql_db_password = "dew4DL"
  })
}
