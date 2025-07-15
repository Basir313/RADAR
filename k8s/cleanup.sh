#!/bin/bash

# Kubernetes Cleanup Script for RADAR Backend
# This script removes all RADAR backend resources from the Kubernetes cluster

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

print_warning "This will delete all RADAR backend resources from the Kubernetes cluster!"
read -p "Are you sure you want to proceed? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_status "Cleanup cancelled."
    exit 0
fi

print_status "Starting RADAR Backend cleanup..."

# Delete resources in reverse order
if kubectl get ingress radar-backend-ingress -n radar-backend &> /dev/null; then
    print_status "Deleting Ingress..."
    kubectl delete -f ingress.yaml --ignore-not-found=true
fi

if kubectl get cronjob radar-backend-cronjob -n radar-backend &> /dev/null; then
    print_status "Deleting CronJob..."
    kubectl delete -f cronjob.yaml --ignore-not-found=true
fi

print_status "Deleting Deployment..."
kubectl delete -f deployment.yaml --ignore-not-found=true

print_status "Deleting Service..."
kubectl delete -f service.yaml --ignore-not-found=true

print_status "Deleting RBAC resources..."
kubectl delete -f rbac.yaml --ignore-not-found=true

print_status "Deleting PVC..."
kubectl delete -f pvc.yaml --ignore-not-found=true

print_status "Deleting Secret..."
kubectl delete -f secret.yaml --ignore-not-found=true

print_status "Deleting ConfigMap..."
kubectl delete -f configmap.yaml --ignore-not-found=true

print_status "Deleting Namespace..."
kubectl delete -f namespace.yaml --ignore-not-found=true

print_status "Cleanup completed successfully!"
