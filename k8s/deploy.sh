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

# Check if Docker image exists locally
if ! docker images --format "table {{.Repository}}:{{.Tag}}" | grep -q "radar-backend:latest"; then
    print_warning "Docker image 'radar-backend:latest' not found locally."
    read -p "Do you want to build the image now? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Building Docker image..."
        cd ../
        docker build -t radar-backend:latest .
        cd k8s/
        print_status "Docker image built successfully."
    else
        print_error "Docker image is required for deployment. Please build it first with: docker build -t radar-backend:latest ."
        exit 1
    fi
else
    print_status "Docker image 'radar-backend:latest' found locally."
fi

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
print_status "Creating Persistent Volume..."
kubectl apply -f pv.yaml

print_status "Creating Persistent Volume Claim..."
# Check if PVC exists and delete it if it has wrong StorageClass
if kubectl get pvc radar-backend-logs -n radar-backend &> /dev/null; then
    CURRENT_SC=$(kubectl get pvc radar-backend-logs -n radar-backend -o jsonpath='{.spec.storageClassName}')
    if [[ "$CURRENT_SC" != "manual" ]]; then
        print_warning "PVC exists with wrong StorageClass ($CURRENT_SC). Deleting and recreating..."
        kubectl delete pvc radar-backend-logs -n radar-backend
        # Wait for deletion to complete
        kubectl wait --for=delete pvc/radar-backend-logs -n radar-backend --timeout=60s || true
    fi
fi
kubectl apply -f pvc.yaml

# Create RBAC
print_status "Creating RBAC resources..."
kubectl apply -f rbac.yaml

# Create Deployment (no service needed for batch job)
print_status "Creating Deployment..."
kubectl apply -f deployment.yaml

# Wait for deployment to be ready
print_status "Waiting for deployment to be ready..."
if ! kubectl wait --for=condition=available --timeout=300s deployment/radar-backend -n radar-backend; then
    print_error "Deployment failed to become ready. Diagnosing..."
    
    print_status "Pod status:"
    kubectl get pods -n radar-backend -o wide
    
    print_status "PVC status:"
    kubectl get pvc -n radar-backend
    kubectl describe pvc radar-backend-logs -n radar-backend
    
    print_status "PV status:"
    kubectl get pv
    kubectl describe pv radar-backend-logs-pv
    
    print_status "StorageClass available:"
    kubectl get storageclass
    
    print_status "Recent events:"
    kubectl get events -n radar-backend --sort-by='.lastTimestamp' | tail -20
    
    print_status "Deployment description:"
    kubectl describe deployment radar-backend -n radar-backend
    
    # Get pod name and show its details
    POD_NAME=$(kubectl get pods -n radar-backend -l app=radar-backend -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [[ -n "$POD_NAME" ]]; then
        print_status "Pod description for $POD_NAME:"
        kubectl describe pod "$POD_NAME" -n radar-backend
        
        print_status "Pod logs for $POD_NAME:"
        kubectl logs "$POD_NAME" -n radar-backend --tail=50 || true
    fi
    
    exit 1
fi

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
