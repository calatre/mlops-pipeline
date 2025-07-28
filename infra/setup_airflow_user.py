#!/usr/bin/env python3
"""
Script to set up Airflow user with Simple auth manager
This creates/updates the simple_auth_manager_passwords.json.generated file
"""
import json
import hashlib
import os

def generate_password_hash(password):
    """Generate a simple hash for the password"""
    return hashlib.sha256(password.encode()).hexdigest()

def setup_airflow_user():
    # Path where passwords are stored
    passwords_file = "/opt/airflow/simple_auth_manager_passwords.json.generated"
    
    # Create user data
    user_data = {
        "airflow": {
            "password": "airflow",
            "role": "admin"
        }
    }
    
    # Write to file
    with open(passwords_file, 'w') as f:
        json.dump(user_data, f, indent=2)
    
    print(f"Created user 'airflow' with password 'airflow' and role 'admin'")
    print(f"Password file saved to: {passwords_file}")

if __name__ == "__main__":
    setup_airflow_user()
