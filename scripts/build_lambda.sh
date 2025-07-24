#!/bin/bash
# Build script for Lambda deployment package

set -e

echo "Building Lambda deployment package..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if we're in the right directory
if [ ! -f "lambda_function/lambda_function.py" ]; then
    echo -e "${RED}Error: lambda_function/lambda_function.py not found!${NC}"
    echo "Please run this script from the project root directory."
    exit 1
fi

# Clean up any existing build artifacts
echo "Cleaning up old artifacts..."
rm -rf lambda_function/package
rm -f taxi_predictor.zip

# Create package directory
mkdir -p lambda_function/package

# Install dependencies
echo "Installing dependencies..."
cd lambda_function
pip install -r requirements.txt -t package/ --no-cache-dir

# Copy Lambda function code
echo "Copying Lambda function code..."
cp lambda_function.py package/

# Create deployment package
echo "Creating deployment package..."
cd package
zip -r ../../taxi_predictor.zip . -q

# Clean up
cd ../..
rm -rf lambda_function/package

# Verify the package
if [ -f "taxi_predictor.zip" ]; then
    SIZE=$(ls -lh taxi_predictor.zip | awk '{print $5}')
    echo -e "${GREEN}✓ Lambda deployment package created successfully!${NC}"
    echo "  File: taxi_predictor.zip"
    echo "  Size: $SIZE"
    
    # Check if size is too large for Lambda
    SIZE_BYTES=$(stat -f%z taxi_predictor.zip 2>/dev/null || stat -c%s taxi_predictor.zip)
    if [ $SIZE_BYTES -gt 52428800 ]; then
        echo -e "${YELLOW}Warning: Package size exceeds 50MB. Consider using Lambda Layers.${NC}"
    fi
else
    echo -e "${RED}Error: Failed to create deployment package!${NC}"
    exit 1
fi

echo -e "\n${GREEN}Next steps:${NC}"
echo "1. Deploy infrastructure: cd infra && terraform apply"
echo "2. The deployment package will be automatically uploaded by Terraform"
