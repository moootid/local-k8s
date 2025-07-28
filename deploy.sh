#!/bin/bash

# Kubernetes Deployment Script
# This script deploys all applications in the correct order

set -e  # Exit on any error

echo "🚀 Starting Kubernetes deployment..."
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

# Validate configuration before deployment
print_status "Validating configuration..."
if [[ -x "./validate-config.sh" ]]; then
    if ! ./validate-config.sh; then
        print_error "Configuration validation failed. Please fix the issues and try again."
        exit 1
    fi
else
    print_warning "Configuration validation script not found or not executable"
    print_warning "Please ensure all YOUR_* placeholders are replaced with actual values"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Function to wait for deployment to be ready
wait_for_deployment() {
    local deployment=$1
    local namespace=$2
    local timeout=${3:-300}  # Default 5 minutes
    
    print_status "Waiting for deployment '$deployment' to be ready..."
    if kubectl wait --for=condition=available --timeout=${timeout}s deployment/$deployment -n $namespace; then
        print_success "Deployment '$deployment' is ready"
        return 0
    else
        print_error "Deployment '$deployment' failed to become ready within ${timeout}s"
        return 1
    fi
}

# Function to wait for statefulset to be ready
wait_for_statefulset() {
    local statefulset=$1
    local namespace=$2
    local timeout=${3:-300}  # Default 5 minutes
    
    print_status "Waiting for statefulset '$statefulset' to be ready..."
    if kubectl wait --for=condition=ready --timeout=${timeout}s pod -l app=$statefulset -n $namespace; then
        print_success "StatefulSet '$statefulset' is ready"
        return 0
    else
        print_error "StatefulSet '$statefulset' failed to become ready within ${timeout}s"
        return 1
    fi
}

# Function to apply and wait for resource
apply_and_wait() {
    local file=$1
    local resource_type=$2
    local resource_name=$3
    local namespace=$4
    
    print_status "Applying $file..."
    if kubectl apply -f "$file"; then
        print_success "Applied $file successfully"
        
        case $resource_type in
            "deployment")
                wait_for_deployment "$resource_name" "$namespace"
                ;;
            "statefulset")
                wait_for_statefulset "$resource_name" "$namespace"
                ;;
            *)
                sleep 2  # Small delay for other resources
                ;;
        esac
    else
        print_error "Failed to apply $file"
        return 1
    fi
}

echo
print_status "Deployment order:"
echo "  1. Namespace"
echo "  2. PostgreSQL Configuration & Secrets"
echo "  3. PostgreSQL Database"
echo "  4. Application Services"
echo "  5. Ingress Configuration"
echo

# Step 1: Create namespace
print_status "📁 Step 1: Creating namespace..."
apply_and_wait "namespace.yaml" "namespace" "myapp" "myapp"

# Step 2: Apply PostgreSQL configuration and secrets
print_status "🔧 Step 2: Applying PostgreSQL configuration..."
apply_and_wait "postgres-config.yaml" "configmap" "postgres-config" "myapp"

# Step 3: Deploy PostgreSQL
print_status "🗄️  Step 3: Deploying PostgreSQL database..."
apply_and_wait "postgres.yaml" "statefulset" "postgres" "myapp"

# Step 4: Deploy application services
print_status "🔧 Step 4: Deploying application services..."

# Step 5: Deploy Monitoring Stack
print_status "📊 Step 5: Deploying Prometheus and Grafana..."
apply_and_wait "prometheus-alerts.yaml" "configmap" "prometheus-alerts" "monitoring"
apply_and_wait "alertmanager.yaml" "deployment" "alertmanager" "monitoring"
apply_and_wait "prometheus.yaml" "deployment" "prometheus" "monitoring"
apply_and_wait "grafana.yaml" "deployment" "grafana" "monitoring"

# Deploy auth-service
print_status "Deploying auth-service..."
apply_and_wait "auth-service.yaml" "deployment" "auth-service" "myapp"

# Deploy people-counter (may fail if image doesn't exist)
print_status "Deploying people-counter..."
if ! apply_and_wait "people-counter.yaml" "deployment" "people-counter" "myapp"; then
    print_warning "people-counter deployment may have failed - check if the image exists"
fi

# Deploy video-transcoder (may fail if image doesn't exist)
print_status "Deploying video-transcoder..."
if ! apply_and_wait "video-transcoder.yaml" "deployment" "video-transcoder" "myapp"; then
    print_warning "video-transcoder deployment may have failed - check if the image exists"
fi

# Step 6: Apply ingress configuration
print_status "🌐 Step 6: Applying ingress configuration..."
apply_and_wait "ingress.yaml" "ingress" "myapp-ingress" "myapp"

echo
print_status "🔍 Deployment verification..."
echo "================================================"

# Show deployment status
print_status "Checking deployment status..."
kubectl get pods -n myapp -o wide

echo
print_status "Checking services..."
kubectl get services -n myapp

echo
print_status "Checking ingress..."
kubectl get ingress -n myapp

echo
print_success "🎉 Deployment completed!"
echo "================================================"

# Show access URLs
echo -e "${GREEN}📋 Access URLs:${NC}"
echo "  🔐 Auth Service:"
echo "    - http://localhost/auth/health"
echo "    - http://auth.localhost/health"
echo "    - Port Forward: kubectl port-forward -n myapp service/auth-service 8080:80"
echo
echo "  👥 People Counter:"
echo "    - http://localhost/people-counter/"
echo
echo "  🎬 Video Transcoder:"
echo "    - http://localhost/video-transcoder/"
echo
echo "  � PostgreSQL Database:"
echo "    - Host: localhost:5432"
echo "    - Connection: postgresql://myapp:YOUR_DB_PASSWORD@localhost:5432/myapp"  # TODO: Replace YOUR_DB_PASSWORD with actual password

echo
print_status "📊 Useful commands:"
echo "  • Check logs: kubectl logs -n myapp -l app=<service-name>"
echo "  • Shell into pod: kubectl exec -it -n myapp <pod-name> -- /bin/bash"
echo "  • Port forward: kubectl port-forward -n myapp service/<service-name> <local-port>:<service-port>"
echo "  • Cleanup: ./cleanup.sh"

echo
print_status "🔄 To redeploy a specific service:"
echo "  kubectl delete deployment <service-name> -n myapp"
echo "  kubectl apply -f <service-name>.yaml"

echo "================================================"
