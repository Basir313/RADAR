#!/bin/bash

# RADAR Backend Docker Run Script
# This script runs the RADAR backend container with proper configuration

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration
IMAGE_NAME="radar-backend:latest"
CONTAINER_NAME="radar-backend-run"
ENV_FILE=".env"
NETWORK_NAME="elastic"
LOGS_DIR="$(pwd)/logs"

print_status "Starting RADAR Backend container..."

# Check if .env file exists
if [[ ! -f "$ENV_FILE" ]]; then
    print_error ".env file not found. Please create it from .env.template"
    print_status "Run: cp .env.template .env"
    exit 1
fi

# Check if Docker image exists
if ! sudo docker images --format "table {{.Repository}}:{{.Tag}}" | grep -q "$IMAGE_NAME"; then
    print_warning "Docker image '$IMAGE_NAME' not found locally."
    read -p "Do you want to build the image now? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Building Docker image..."
        sudo docker build -t "$IMAGE_NAME" .
        print_status "Docker image built successfully."
    else
        print_error "Docker image is required. Please build it first with: sudo docker build -t $IMAGE_NAME ."
        exit 1
    fi
fi

# Check if network exists, create if not
if ! sudo docker network ls --format "table {{.Name}}" | grep -q "^$NETWORK_NAME$"; then
    print_warning "Network '$NETWORK_NAME' not found."
    read -p "Do you want to create the network now? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Run: sudo docker network create $NETWORK_NAME"
        exit 0
    else
        print_error "Network '$NETWORK_NAME' is required. Please create it first with: sudo docker network create $NETWORK_NAME"
        exit 1
    fi
fi

# Create logs directory if it doesn't exist
mkdir -p "$LOGS_DIR"

# Remove existing container if it exists
if docker ps -a --format "table {{.Names}}" | grep -q "^$CONTAINER_NAME$"; then
    print_status "Removing existing container '$CONTAINER_NAME'..."
    sudo docker rm -f "$CONTAINER_NAME" > /dev/null 2>&1
fi

print_status "Running container '$CONTAINER_NAME'..."
print_status "Image: $IMAGE_NAME"
print_status "Network: $NETWORK_NAME"
print_status "Environment file: $ENV_FILE"
print_status "Logs directory: $LOGS_DIR"

# Run the container
sudo docker run --rm \
    --name "$CONTAINER_NAME" \
    --network "$NETWORK_NAME" \
    --env-file "$ENV_FILE" \
    -v "$LOGS_DIR:/usr/src/app/logs" \
    "$IMAGE_NAME"

print_status "Container execution completed and automatically removed."
