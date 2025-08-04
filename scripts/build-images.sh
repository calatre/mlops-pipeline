#!/bin/bash

# MLOps Pipeline - Local Docker Image Build Script
# This script builds Docker images locally for development and testing

set -e

# Configuration
PROJECT_NAME="mlops-taxi-prediction"
ENVIRONMENT="${ENVIRONMENT:-dev}"
AWS_REGION="${AWS_REGION:-eu-north-1}"
BUILD_DATE=$(date +%Y%m%d)
GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "local")
IMAGE_TAG="v${BUILD_DATE}-${GIT_COMMIT}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Check dependencies
check_dependencies() {
    log_info "Checking dependencies..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    if ! command -v aws &> /dev/null; then
        log_warning "AWS CLI is not installed - ECR push will not be available"
    fi
    
    log_success "Dependencies check complete"
}

# Build Airflow image
build_airflow() {
    log_info "Building Airflow image..."
    
    if [ ! -f "airflow/Dockerfile" ]; then
        log_error "airflow/Dockerfile not found"
        return 1
    fi
    
    docker build \
        -t "${PROJECT_NAME}-airflow:${IMAGE_TAG}" \
        -t "${PROJECT_NAME}-airflow:latest" \
        --build-arg BUILD_DATE="${BUILD_DATE}" \
        --build-arg GIT_COMMIT="${GIT_COMMIT}" \
        ./airflow/
    
    log_success "Airflow image built successfully"
}

# Build MLflow image
build_mlflow() {
    log_info "Building MLflow image..."
    
    # Create MLflow directory and Dockerfile if they don't exist
    if [ ! -d "mlflow" ]; then
        mkdir -p mlflow
    fi
    
    if [ ! -f "mlflow/Dockerfile" ]; then
        log_info "Creating MLflow Dockerfile..."
        cat > mlflow/Dockerfile << 'EOF'
FROM python:3.10-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install MLflow and dependencies
RUN pip install --no-cache-dir \
    mlflow[extras]==2.7.1 \
    boto3 \
    psycopg2-binary \
    pymysql \
    gunicorn

# Create MLflow user
RUN useradd -m -u 1000 mlflow && chown -R mlflow:mlflow /app
USER mlflow

# Expose MLflow port
EXPOSE 5000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

# Set environment variables
ENV MLFLOW_HOME=/app
ENV PYTHONPATH=/app

# Command to run MLflow server
CMD ["mlflow", "server", \
     "--host", "0.0.0.0", \
     "--port", "5000", \
     "--default-artifact-root", "${MLFLOW_ARTIFACT_ROOT:-s3://mlops-taxi-prediction-mlflow-artifacts-dev}", \
     "--backend-store-uri", "${MLFLOW_BACKEND_STORE_URI:-sqlite:///mlflow.db}"]
EOF
    fi
    
    docker build \
        -t "${PROJECT_NAME}-mlflow:${IMAGE_TAG}" \
        -t "${PROJECT_NAME}-mlflow:latest" \
        --build-arg BUILD_DATE="${BUILD_DATE}" \
        --build-arg GIT_COMMIT="${GIT_COMMIT}" \
        ./mlflow/
    
    log_success "MLflow image built successfully"
}

# Build Lambda image
build_lambda() {
    log_info "Building Lambda Docker image..."

    docker build \
        --platform linux/amd64 \
        -t "${PROJECT_NAME}-lambda:${IMAGE_TAG}" \
        -t "${PROJECT_NAME}-lambda:latest" \
        --build-arg BUILD_DATE="${BUILD_DATE}" \
        --build-arg GIT_COMMIT="${GIT_COMMIT}" \
        ./lambda_function/

    if [ $? -eq 0 ]; then
        log_success "Lambda Docker image built successfully"
    else
        log_error "Failed to build Lambda Docker image"
        exit 1
    fi
}

# Push to ECR
push_to_ecr() {
    if ! command -v aws &> /dev/null; then
        log_warning "AWS CLI not available - skipping ECR push"
        return 0
    fi
    
    log_info "Pushing images to ECR..."
    
    # Get AWS account ID
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")
    
    if [ -z "$AWS_ACCOUNT_ID" ]; then
        log_warning "Could not get AWS account ID - skipping ECR push"
        return 0
    fi
    
    ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
    
    # Login to ECR
    log_info "Logging in to ECR..."
    aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
    
    # Push images
    for service in airflow mlflow lambda; do
        repo_name="${PROJECT_NAME}-${service}-app-${ENVIRONMENT}"
        
        # Create repository if it doesn't exist
        aws ecr describe-repositories --repository-names ${repo_name} --region ${AWS_REGION} >/dev/null 2>&1 || {
            log_info "Creating ECR repository: ${repo_name}"
            aws ecr create-repository --repository-name ${repo_name} --region ${AWS_REGION} >/dev/null
        }
        
        # Tag and push
        docker tag "${PROJECT_NAME}-${service}:${IMAGE_TAG}" "${ECR_REGISTRY}/${repo_name}:${IMAGE_TAG}"
        docker tag "${PROJECT_NAME}-${service}:latest" "${ECR_REGISTRY}/${repo_name}:latest"
        
        docker push "${ECR_REGISTRY}/${repo_name}:${IMAGE_TAG}"
        docker push "${ECR_REGISTRY}/${repo_name}:latest"
        
        log_success "Pushed ${service} image to ECR"
    done
}

# Clean up old images
cleanup() {
    log_info "Cleaning up old images..."
    
    # Remove images older than 7 days
    docker image prune -f --filter "until=168h" >/dev/null 2>&1 || true
    
    log_success "Cleanup complete"
}

# Show usage
usage() {
    echo "Usage: $0 [OPTIONS] [SERVICES...]"
    echo ""
    echo "Build Docker images for MLOps pipeline services"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -p, --push     Push images to ECR after building"
    echo "  -c, --cleanup  Clean up old images after building"
    echo "  --no-cache     Build without using cache"
    echo ""
    echo "Services:"
    echo "  airflow        Build Airflow image"
    echo "  mlflow         Build MLflow image"
    echo "  lambda         Build Lambda image"
    echo "  all            Build all images (default)"
    echo ""
    echo "Environment Variables:"
    echo "  ENVIRONMENT    Target environment (default: dev)"
    echo "  AWS_REGION     AWS region (default: eu-north-1)"
    echo ""
    echo "Examples:"
    echo "  $0                    # Build all images"
    echo "  $0 airflow mlflow     # Build only Airflow and MLflow"
    echo "  $0 -p all             # Build all and push to ECR"
    echo "  $0 --cleanup lambda   # Build Lambda and cleanup old images"
}

# Main function
main() {
    local push_ecr=false
    local cleanup_images=false
    local no_cache=""
    local services=()
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -p|--push)
                push_ecr=true
                shift
                ;;
            -c|--cleanup)
                cleanup_images=true
                shift
                ;;
            --no-cache)
                no_cache="--no-cache"
                shift
                ;;
            airflow|mlflow|lambda|all)
                services+=("$1")
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Default to all services if none specified
    if [ ${#services[@]} -eq 0 ]; then
        services=("all")
    fi
    
    # Check dependencies
    check_dependencies
    
    log_info "Starting build process..."
    log_info "Project: ${PROJECT_NAME}"
    log_info "Environment: ${ENVIRONMENT}"
    log_info "Image tag: ${IMAGE_TAG}"
    log_info "Services: ${services[*]}"
    
    # Build services
    for service in "${services[@]}"; do
        case $service in
            airflow)
                build_airflow
                ;;
            mlflow)
                build_mlflow
                ;;
            lambda)
                build_lambda
                ;;
            all)
                build_airflow
                build_mlflow
                build_lambda
                ;;
            *)
                log_error "Unknown service: $service"
                exit 1
                ;;
        esac
    done
    
    # Push to ECR if requested
    if [ "$push_ecr" = true ]; then
        push_to_ecr
    fi
    
    # Cleanup if requested
    if [ "$cleanup_images" = true ]; then
        cleanup
    fi
    
    log_success "Build process complete!"
    
    # Show built images
    log_info "Built images:"
    docker images | grep "${PROJECT_NAME}" | head -10
}

# Run main function
main "$@"
