# ec2.tf (FULL AND CORRECTED CONTENT)

# Data sources for fetching existing VPC and Subnet details
data "aws_vpc" "selected" {
  id = "vpc-0056d65477e4e13e3" # Your VPC ID from Image 3
}

# --- IMPORTANT: Using your specific public subnet ID ---
# Go to VPC -> Subnets in the AWS console and verify this ID is correct and public:
# subnet-00800be7cda9813b8 (from your screenshot)
data "aws_subnet" "selected" {
  id = "subnet-00800be7cda9813b8" # Directly using the Subnet ID you found
}

# Security Group for your EC2 instances
resource "aws_security_group" "app_sg" {
  name        = "${var.project_name}-app-sg"
  description = "Allow inbound traffic for web app and SSH"
  vpc_id      = data.aws_vpc.selected.id # References the VPC data source

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Be more restrictive in production for SSH
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow HTTP access
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-app-sg"
    ManagedBy   = "Terraform"
    Project     = var.project_name
  }
}

# EC2 Instance for your application
resource "aws_instance" "app_server" {
  # Find a valid AMI for ap-south-1 (Mumbai region).
  # Go to EC2 Console -> AMIs -> Public Images. Search for "Amazon Linux 2023 AMI" or "Amazon Linux 2 AMI".
  # Example for Amazon Linux 2023 in ap-south-1: ami-053b0a797c2349e92
  ami           = "ami-0b32d400456908bf9" # Your provided AMI ID (VERIFY if this is latest/correct for ap-south-1)
  instance_type = "t2.micro"
  subnet_id     = data.aws_subnet.selected.id # References the selected subnet
  associate_public_ip_address = true # Gives the instance a public IP for easier SSH and testing

  # This is the name of an EC2 Key Pair you have created in ap-south-1
  key_name = "tftest" # Your EC2 Key Pair name

  vpc_security_group_ids = [aws_security_group.app_sg.id]
  # IMPORTANT: This references the IAM instance profile defined in main.tf
  iam_instance_profile   = aws_iam_instance_profile.codedeploy_ec2_instance_profile.name

  tags = {
    Name        = "${var.project_name}-app-server-managed-by-terraform"
    Environment = "Dev" # Matches CodeDeploy deployment group filter
    App         = "WebApp" # Matches CodeDeploy deployment group filter
    ManagedBy   = "Terraform"
    Project     = var.project_name
  }

  # User data to install CodeDeploy agent on launch (adjust for your OS, this is for Amazon Linux)
  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install -y ruby wget
              cd /home/ec2-user
              wget https://aws-codedeploy-ap-south-1.s3.ap-south-1.amazonaws.com/latest/install
              chmod +x ./install
              sudo ./install auto
              sudo service code deploy-agent status
              sudo service code deploy-agent start # Ensure agent starts
              EOF
}