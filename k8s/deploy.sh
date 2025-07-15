#!/bin/bash

# Kubernetes Deployment Script for RADAR Backend
# This script deploys the RADAR backend application to a Kubernetes cluster

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

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed. Please install kubectl first."
    exit 1
fi

# Check if we can connect to the cluster
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
    exit 1
fi

print_status "Starting RADAR Backend deployment..."

# Create namespace
print_status "Creating namespace..."
kubectl apply -f namespace.yaml

# Create ConfigMap
print_status "Creating ConfigMap..."
kubectl apply -f configmap.yaml

# Create Secret (user should update the values first)
print_warning "Please make sure you have updated the secret.yaml file with your actual credentials!"
read -p "Have you updated the secret.yaml file with your credentials? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_error "Please update the secret.yaml file with your actual credentials before proceeding."
    exit 1
fi

print_status "Creating Secret..."
kubectl apply -f secret.yaml

# Create PVC
print_status "Creating Persistent Volume Claim..."
kubectl apply -f pvc.yaml

# Create RBAC
print_status "Creating RBAC resources..."
kubectl apply -f rbac.yaml

# Create Service
print_status "Creating Service..."
kubectl apply -f service.yaml

# Create Deployment
print_status "Creating Deployment..."
kubectl apply -f deployment.yaml

# Wait for deployment to be ready
print_status "Waiting for deployment to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/radar-backend -n radar-backend

# Create CronJob (optional)
read -p "Do you want to create a CronJob for scheduled execution? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_status "Creating CronJob..."
    kubectl apply -f cronjob.yaml
fi

# Create Ingress (optional)
read -p "Do you want to create an Ingress for external access? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Please make sure you have updated the ingress.yaml file with your domain!"
    read -p "Have you updated the ingress.yaml file with your domain? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Creating Ingress..."
        kubectl apply -f ingress.yaml
    else
        print_warning "Skipping Ingress creation. You can apply it later after updating the domain."
    fi
fi

print_status "Deployment completed successfully!"

# Show deployment status
print_status "Current deployment status:"
kubectl get all -n radar-backend

print_status "To check logs, run: kubectl logs -f deployment/radar-backend -n radar-backend"
print_status "To check pod status, run: kubectl get pods -n radar-backend"
