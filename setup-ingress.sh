#!/bin/bash

# Ingress Deployment Script
# This script handles NGINX Ingress Controller setup and ingress resources deployment

set -e  # Exit on any error

echo "🌐 Setting up NGINX Ingress Controller and Ingress resources..."
echo "================================================"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed or not in PATH"
    exit 1
fi

# Check if we can connect to the cluster
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster. Make sure your cluster is running and kubectl is configured."
    exit 1
fi

print_status "Connected to cluster: $(kubectl config current-context)"

# Function to check if NGINX Ingress Controller is running
check_ingress_controller() {
    print_status "Checking NGINX Ingress Controller status..."
    
    if kubectl get namespace ingress-nginx &> /dev/null; then
        local ready_pods=$(kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller --no-headers 2>/dev/null | grep -c "Running" || echo "0")
        if [ "$ready_pods" -gt 0 ]; then
            print_success "NGINX Ingress Controller is running"
            return 0
        else
            print_warning "NGINX Ingress Controller namespace exists but no running pods found"
            return 1
        fi
    else
        print_warning "NGINX Ingress Controller is not installed"
        return 1
    fi
}

# Function to install NGINX Ingress Controller
install_ingress_controller() {
    print_status "Installing NGINX Ingress Controller..."
    
    # Install NGINX Ingress Controller
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml
    
    print_status "Waiting for NGINX Ingress Controller to be ready..."
    kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=300s
    
    # Wait a bit more for admission webhook to be ready
    print_status "Waiting for admission webhook to be ready..."
    sleep 10
    
    # Verify admission webhook service is available
    if kubectl get service ingress-nginx-controller-admission -n ingress-nginx &> /dev/null; then
        print_success "NGINX Ingress Controller and admission webhook are ready"
    else
        print_warning "Admission webhook service not found, but controller is running"
    fi
}

# Function to apply ingress with retry logic
apply_ingress_with_retry() {
    local max_retries=3
    local retry_count=0
    
    while [ $retry_count -lt $max_retries ]; do
        print_status "Attempting to apply ingress configuration (attempt $((retry_count + 1))/$max_retries)..."
        
        if kubectl apply -f ingress.yaml; then
            print_success "Ingress configuration applied successfully"
            return 0
        else
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $max_retries ]; then
                print_warning "Failed to apply ingress, retrying in 10 seconds..."
                sleep 10
                
                # Check if we need to reinstall the controller
                if ! check_ingress_controller; then
                    print_status "Reinstalling NGINX Ingress Controller..."
                    install_ingress_controller
                fi
            else
                print_error "Failed to apply ingress after $max_retries attempts"
                return 1
            fi
        fi
    done
}

# Function to clean up orphaned webhook configurations
cleanup_webhook_configs() {
    print_status "Cleaning up orphaned webhook configurations..."
    
    # Remove orphaned validating webhook configurations
    kubectl delete validatingwebhookconfiguration ingress-nginx-admission 2>/dev/null || true
    
    # Remove orphaned mutating webhook configurations  
    kubectl delete mutatingwebhookconfiguration ingress-nginx-admission 2>/dev/null || true
    
    print_status "Webhook configurations cleaned up"
}

# Main execution
echo
print_status "Step 1: Checking NGINX Ingress Controller..."

if ! check_ingress_controller; then
    # Clean up any orphaned webhook configurations first
    cleanup_webhook_configs
    
    # Install fresh ingress controller
    install_ingress_controller
fi

echo
print_status "Step 2: Applying ingress configuration..."

# Apply ingress with retry logic
apply_ingress_with_retry

echo
print_status "Step 3: Verifying ingress deployment..."
kubectl get ingress -n myapp

echo
print_success "🎉 Ingress setup completed successfully!"
echo "================================================"

# Show access URLs
echo -e "${GREEN}📋 Access URLs:${NC}"
echo "  🔐 Auth Service:"
echo "    - http://localhost/auth/health"
echo "    - http://auth.localhost/health"
echo
echo "  📊 To check ingress status:"
echo "    kubectl get ingress -n myapp"
echo "    kubectl describe ingress -n myapp"
echo
echo "  🔄 To rerun this script:"
echo "    ./setup-ingress.sh"
echo "================================================"
