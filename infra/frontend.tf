# Frontend EC2 Infrastructure

# Data source to get the latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security Group for Frontend EC2 Instance
resource "aws_security_group" "frontend" {
  name        = "${var.project_name}-frontend-sg-${var.environment}"
  description = "Security group for frontend EC2 instance"
  vpc_id      = module.vpc.vpc_id

  # Inbound rule: Allow traffic on port 5000 from anywhere (for admin access)
  ingress {
    description = "Allow admin access on port 5000"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound rule: Allow HTTPS traffic to AWS services
  egress {
    description = "Allow HTTPS to AWS services"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound rule: Allow HTTP for package installations
  egress {
    description = "Allow HTTP for package installations"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-frontend-sg-${var.environment}"
  })
}

# IAM Role for EC2 Instance
resource "aws_iam_role" "frontend_ec2" {
  name = "${var.project_name}-frontend-ec2-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# IAM Instance Profile for EC2
resource "aws_iam_instance_profile" "frontend" {
  name = "${var.project_name}-frontend-instance-profile-${var.environment}"
  role = aws_iam_role.frontend_ec2.name
}

# IAM Policy for Frontend EC2 to access necessary AWS services
resource "aws_iam_policy" "frontend_ec2_policy" {
  name        = "${var.project_name}-frontend-ec2-policy-${var.environment}"
  description = "IAM policy for frontend EC2 instance"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.mlflow_artifacts.arn,
          "${aws_s3_bucket.mlflow_artifacts.arn}/*",
          aws_s3_bucket.data_storage.arn,
          "${aws_s3_bucket.data_storage.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeTags"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "frontend_ec2_policy" {
  role       = aws_iam_role.frontend_ec2.name
  policy_arn = aws_iam_policy.frontend_ec2_policy.arn
}

# Attach SSM policy for Session Manager access (optional but recommended)
resource "aws_iam_role_policy_attachment" "frontend_ssm" {
  role       = aws_iam_role.frontend_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# User data script to install Python 3.11 and dependencies
locals {
  user_data_script = <<-EOF
    #!/bin/bash
    set -e
    
    # Update system packages
    yum update -y
    
    # Install Python 3.11
    yum install -y python3.11 python3.11-pip python3.11-devel
    
    # Create python3 symlink to python3.11
    alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1
    alternatives --set python3 /usr/bin/python3.11
    
    # Install development tools and dependencies
    yum groupinstall -y "Development Tools"
    yum install -y git nginx
    
    # Create application directory
    mkdir -p /opt/mlops-frontend
    cd /opt/mlops-frontend
    
    # Create virtual environment
    python3.11 -m venv venv
    source venv/bin/activate
    
    # Upgrade pip
    pip install --upgrade pip
    
    # Install common Python packages for MLOps frontend
    pip install streamlit pandas numpy matplotlib seaborn plotly boto3 requests mlflow-client
    
    # Create a sample frontend application
    cat > /opt/mlops-frontend/app.py << 'PYTHON_EOF'
import streamlit as st
import pandas as pd
import requests
import os

st.set_page_config(
    page_title="MLOps Taxi Prediction Frontend",
    page_icon="🚕",
    layout="wide"
)

st.title("🚕 MLOps Taxi Prediction Dashboard")
st.markdown("---")

# Sidebar
st.sidebar.title("Navigation")
page = st.sidebar.selectbox("Choose a page", ["Home", "Model Predictions", "Model Performance"])

if page == "Home":
    st.header("Welcome to MLOps Taxi Prediction System")
    st.write("""
    This dashboard provides an interface to:
    - Make taxi trip duration predictions
    - View model performance metrics
    - Monitor system health
    """)
    
    col1, col2, col3 = st.columns(3)
    with col1:
        st.metric("Active Models", "3")
    with col2:
        st.metric("Predictions Today", "1,234")
    with col3:
        st.metric("Avg Response Time", "120ms")

elif page == "Model Predictions":
    st.header("Make a Prediction")
    
    col1, col2 = st.columns(2)
    
    with col1:
        pickup_longitude = st.number_input("Pickup Longitude", value=-73.98)
        pickup_latitude = st.number_input("Pickup Latitude", value=40.76)
        dropoff_longitude = st.number_input("Dropoff Longitude", value=-73.99)
        dropoff_latitude = st.number_input("Dropoff Latitude", value=40.75)
    
    with col2:
        passenger_count = st.number_input("Passenger Count", min_value=1, max_value=6, value=1)
        trip_distance = st.number_input("Trip Distance (miles)", min_value=0.1, value=2.5)
        
    if st.button("Predict Trip Duration"):
        st.success("Predicted trip duration: 15.3 minutes")

elif page == "Model Performance":
    st.header("Model Performance Metrics")
    st.write("Performance metrics visualization coming soon...")

PYTHON_EOF
    
    # Create systemd service for the Streamlit app
    cat > /etc/systemd/system/mlops-frontend.service << 'SERVICE_EOF'
[Unit]
Description=MLOps Frontend Streamlit Application
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/opt/mlops-frontend
Environment="PATH=/opt/mlops-frontend/venv/bin:/usr/local/bin:/usr/bin:/bin"
ExecStart=/opt/mlops-frontend/venv/bin/streamlit run app.py --server.port=5000 --server.address=0.0.0.0
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICE_EOF
    
    # Set proper permissions
    chown -R ec2-user:ec2-user /opt/mlops-frontend
    
    # Enable and start the service
    systemctl daemon-reload
    systemctl enable mlops-frontend.service
    systemctl start mlops-frontend.service
    
    # Configure CloudWatch agent (if needed)
    # This would be added based on monitoring requirements
    
    # Log the completion
    echo "Frontend setup completed successfully" >> /var/log/user-data.log
  EOF
}

# EC2 Instance for Frontend
resource "aws_instance" "frontend" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.micro"
  subnet_id              = module.vpc.public_subnet_ids[0] # Using first public subnet
  vpc_security_group_ids = [aws_security_group.frontend.id]
  iam_instance_profile   = aws_iam_instance_profile.frontend.name

  user_data = base64encode(local.user_data_script)

  # Enable detailed monitoring for cost optimization insights
  monitoring = false # Set to false for cost efficiency

  # Use gp3 for better cost efficiency
  root_block_device {
    volume_type = "gp3"
    volume_size = 30
    encrypted   = true

    tags = merge(var.tags, {
      Name = "${var.project_name}-frontend-root-volume-${var.environment}"
    })
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-frontend-${var.environment}"
    Type = "Frontend"
  })
}

# ALB resources removed - using direct EC2 access for simplified architecture

# Output the frontend instance details
output "frontend_instance_id" {
  description = "ID of the frontend EC2 instance"
  value       = aws_instance.frontend.id
}

output "frontend_instance_public_ip" {
  description = "Public IP of the frontend EC2 instance"
  value       = aws_instance.frontend.public_ip
}

output "frontend_instance_public_dns" {
  description = "Public DNS of the frontend EC2 instance"
  value       = aws_instance.frontend.public_dns
}

output "frontend_direct_url" {
  description = "Direct URL to access the frontend"
  value       = "http://${aws_instance.frontend.public_ip}:5000"
}
