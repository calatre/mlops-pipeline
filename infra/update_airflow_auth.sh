#!/bin/bash
# Script to update Airflow task definition with Simple auth manager configuration

# Find the line number where we need to insert the new environment variable
LINE_NUM=$(grep -n "AIRFLOW__CORE__LOAD_EXAMPLES" main-modular.tf | cut -d: -f1)

# Insert after the LOAD_EXAMPLES environment variable
sed -i "${LINE_NUM}a\\        },\\
        {\\
          name  = \"AIRFLOW__CORE__SIMPLE_AUTH_MANAGER_USERS\"\\
          value = \"airflow:admin\"" main-modular.tf

echo "Added Simple auth manager user configuration"
echo "This will create user 'airflow' with 'admin' role"
echo "Note: Password will be auto-generated and shown in webserver logs"
