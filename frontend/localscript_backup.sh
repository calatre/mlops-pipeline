# User data script to install Python 3.11 and dependencies
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