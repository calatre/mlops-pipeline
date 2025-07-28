#!/usr/bin/env python3
import re

# Read the file
with open('main-modular.tf', 'r') as f:
    content = f.read()

# Find where to insert - after SIMPLE_AUTH_MANAGER_USERS
pattern = r'(name\s*=\s*"AIRFLOW__CORE__SIMPLE_AUTH_MANAGER_USERS"\s*\n\s*value\s*=\s*"airflow:admin"\s*\n\s*})'
replacement = r'''\1,
        {
          name  = "AIRFLOW__CORE__SIMPLE_AUTH_MANAGER_ALL_ADMINS"
          value = "False"
        }'''

# Replace
new_content = re.sub(pattern, replacement, content)

# Write back
with open('main-modular.tf', 'w') as f:
    f.write(new_content)

print("Added additional auth configuration")
