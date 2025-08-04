#!/bin/bash
# Build script for Lambda container deployment

set -e

echo "Building Lambda Docker container for deployment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="mlops-taxi-prediction"
ENVIRONMENT="${ENVIRONMENT:-dev}"
AWS_REGION="${AWS_REGION:-eu-north-1}"
BUILD_DATE=$(date +%Y%m%d)
GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "local")
IMAGE_TAG="v${BUILD_DATE}-${GIT_COMMIT}"
LAMBDA_IMAGE_NAME="${PROJECT_NAME}-lambda"

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in the right directory
if [ ! -f "lambda_function/lambda_function.py" ]; then
    log_error "lambda_function/lambda_function.py not found!"
    echo "Please run this script from the project root directory."
    exit 1
fi

# Check dependencies
log_info "Checking dependencies..."
if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed or not in PATH"
    exit 1
fi

if ! command -v aws &> /dev/null; then
    log_warning "AWS CLI is not installed - ECR push will not be available"
fi

log_success "Dependencies check complete"

# Clean up any existing zip artifacts (legacy cleanup)
log_info "Cleaning up legacy zip artifacts..."
rm -f taxi_predictor.zip
rm -rf lambda_function/package

# Build Docker image
log_info "Building Lambda Docker image..."
log_info "Project: ${PROJECT_NAME}"
log_info "Environment: ${ENVIRONMENT}"
log_info "Image tag: ${IMAGE_TAG}"

# Build the Docker image with platform specification for Lambda compatibility
docker build \
    --platform linux/amd64 \
    -t "${LAMBDA_IMAGE_NAME}:${IMAGE_TAG}" \
    -t "${LAMBDA_IMAGE_NAME}:latest" \
    --build-arg BUILD_DATE="${BUILD_DATE}" \
    --build-arg GIT_COMMIT="${GIT_COMMIT}" \
    ./lambda_function/

if [ $? -eq 0 ]; then
    log_success "Lambda Docker image built successfully"
else
    log_error "Failed to build Lambda Docker image"
    exit 1
fi

# Get image size for reference
IMAGE_SIZE=$(docker images "${LAMBDA_IMAGE_NAME}:latest" --format "table {{.Size}}" | tail -1)
log_info "Image size: ${IMAGE_SIZE}"

# Push to ECR if AWS CLI is available
push_to_ecr() {
    if ! command -v aws &> /dev/null; then
        log_warning "AWS CLI not available - skipping ECR push"
        log_info "To push manually later, run:"
        log_info "  aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin \$ECR_REGISTRY"
        log_info "  docker tag ${LAMBDA_IMAGE_NAME}:latest \$ECR_REGISTRY/${PROJECT_NAME}-lambda-app-${ENVIRONMENT}:latest"
        log_info "  docker push \$ECR_REGISTRY/${PROJECT_NAME}-lambda-app-${ENVIRONMENT}:latest"
        return 0
    fi
    
    log_info "Pushing Lambda image to ECR..."
    
    # Get AWS account ID
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")
    
    if [ -z "$AWS_ACCOUNT_ID" ]; then
        log_warning "Could not get AWS account ID - skipping ECR push"
        log_info "Please ensure AWS credentials are configured"
        return 0
    fi
    
    ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
    ECR_REPO_NAME="${PROJECT_NAME}-lambda-app-${ENVIRONMENT}"
    
    # Login to ECR
    log_info "Logging in to ECR..."
    aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
    
    if [ $? -ne 0 ]; then
        log_error "Failed to login to ECR"
        return 1
    fi
    
    # Create repository if it doesn't exist
    aws ecr describe-repositories --repository-names ${ECR_REPO_NAME} --region ${AWS_REGION} > /dev/null 2>&1 || {
        log_info "Creating ECR repository: ${ECR_REPO_NAME}"
        aws ecr create-repository --repository-name ${ECR_REPO_NAME} --region ${AWS_REGION} > /dev/null
    }
    
    # Tag and push
    log_info "Tagging and pushing image..."
    docker tag "${LAMBDA_IMAGE_NAME}:${IMAGE_TAG}" "${ECR_REGISTRY}/${ECR_REPO_NAME}:${IMAGE_TAG}"
    docker tag "${LAMBDA_IMAGE_NAME}:latest" "${ECR_REGISTRY}/${ECR_REPO_NAME}:latest"
    
    docker push "${ECR_REGISTRY}/${ECR_REPO_NAME}:${IMAGE_TAG}"
    docker push "${ECR_REGISTRY}/${ECR_REPO_NAME}:latest"
    
    if [ $? -eq 0 ]; then
        log_success "Lambda image pushed to ECR successfully"
        log_info "Image URI: ${ECR_REGISTRY}/${ECR_REPO_NAME}:latest"
    else
        log_error "Failed to push image to ECR"
        return 1
    fi
}

# Parse command line arguments
PUSH_TO_ECR=true
while [[ $# -gt 0 ]]; do
    case $1 in
        --no-push)
            PUSH_TO_ECR=false
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Build Docker image for Lambda function deployment"
            echo ""
            echo "Options:"
            echo "  --no-push     Skip pushing to ECR"
            echo "  -h, --help    Show this help message"
            echo ""
            echo "Environment Variables:"
            echo "  ENVIRONMENT   Target environment (default: dev)"
            echo "  AWS_REGION    AWS region (default: eu-north-1)"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Push to ECR if requested
if [ "$PUSH_TO_ECR" = true ]; then
    push_to_ecr
fi

log_success "Lambda container build process complete!"

# Show built images
log_info "Built Lambda images:"
docker images | grep "${LAMBDA_IMAGE_NAME}" | head -5

echo -e "\n${GREEN}Next steps:${NC}"
echo "1. Deploy infrastructure: cd infra && terraform apply"
echo "2. The container image will be automatically used by Lambda from ECR"
echo "3. Lambda will use container runtime instead of zip package (10GB limit vs 250MB)"
