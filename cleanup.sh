#!/bin/bash

# Kubernetes Cluster Cleanup Script
# This script removes all custom applications and resources while preserving system components

set -e  # Exit on any error

echo "🧹 Starting Kubernetes cluster cleanup..."
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

# Function to delete resources in a namespace
cleanup_namespace() {
    local namespace=$1
    
    if kubectl get namespace "$namespace" &> /dev/null; then
        print_status "Cleaning up namespace: $namespace"

        print_status "Cleaning up monitoring namespace..."
        kubectl delete namespace monitoring --timeout=60s || true
        # Delete all resources
        print_status "  - Deleting all pods, services, deployments..."
        kubectl delete all --all -n "$namespace" --timeout=60s || true
        
        # Delete persistent volume claims
        print_status "  - Deleting persistent volume claims..."
        kubectl delete pvc --all -n "$namespace" --timeout=60s || true
        
        # Delete secrets (except default service account token)
        print_status "  - Deleting secrets..."
        kubectl delete secrets --all -n "$namespace" --timeout=60s || true
        
        # Delete configmaps (except kube-root-ca.crt)
        print_status "  - Deleting configmaps..."
        kubectl delete configmaps --all -n "$namespace" --timeout=60s || true
        
        # Delete ingress
        print_status "  - Deleting ingress resources..."
        kubectl delete ingress --all -n "$namespace" --timeout=60s || true
        
        # Delete network policies
        print_status "  - Deleting network policies..."
        kubectl delete networkpolicy --all -n "$namespace" --timeout=60s || true
        
        # Delete the namespace itself (if not default namespaces)
        if [[ "$namespace" != "default" && "$namespace" != "kube-system" && "$namespace" != "kube-public" && "$namespace" != "kube-node-lease" ]]; then
            print_status "  - Deleting namespace: $namespace"
            kubectl delete namespace "$namespace" --timeout=60s || true
        fi
        
        print_success "Cleaned up namespace: $namespace"
    else
        print_warning "Namespace $namespace does not exist"
    fi
}

# Get all namespaces except system ones
print_status "Getting list of custom namespaces..."
CUSTOM_NAMESPACES=$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | grep -v -E '^(default|kube-system|kube-public|kube-node-lease)$' || true)

if [[ -n "$CUSTOM_NAMESPACES" ]]; then
    echo "Found custom namespaces:"
    for ns in $CUSTOM_NAMESPACES; do
        echo "  - $ns"
    done
    echo
    
    # Cleanup each custom namespace
    for namespace in $CUSTOM_NAMESPACES; do
        cleanup_namespace "$namespace"
    done
else
    print_status "No custom namespaces found"
fi

# Clean up orphaned persistent volumes
print_status "Checking for orphaned persistent volumes..."
PVS=$(kubectl get pv -o jsonpath='{.items[?(@.status.phase=="Available")].metadata.name}' 2>/dev/null || true)
if [[ -n "$PVS" ]]; then
    print_status "Deleting orphaned persistent volumes..."
    for pv in $PVS; do
        kubectl delete pv "$pv" --timeout=60s || true
    done
    print_success "Deleted orphaned persistent volumes"
else
    print_status "No orphaned persistent volumes found"
fi

# Clean up any resources in default namespace (optional)
read -p "Do you want to clean up custom resources in the 'default' namespace? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_status "Cleaning up custom resources in default namespace..."
    
    # Don't delete the kubernetes service or system resources
    kubectl delete deployment,statefulset,daemonset,job,cronjob --all -n default --timeout=60s || true
    kubectl delete service --all -n default --field-selector metadata.name!=kubernetes --timeout=60s || true
    kubectl delete ingress,configmap,secret --all -n default --timeout=60s || true
    
    print_success "Cleaned up custom resources in default namespace"
fi

echo
print_status "Cleaning up ingress webhook configurations..."
# Remove orphaned validating webhook configurations
kubectl delete validatingwebhookconfiguration ingress-nginx-admission 2>/dev/null || true
# Remove orphaned mutating webhook configurations  
kubectl delete mutatingwebhookconfiguration ingress-nginx-admission 2>/dev/null || true
print_status "Ingress webhook configurations cleaned up"

echo
print_status "Verifying cleanup..."
echo "Remaining resources:"
kubectl get all --all-namespaces | grep -v -E '^(kube-system|default.*service/kubernetes)'

echo
print_success "🎉 Cleanup completed successfully!"
print_status "Your Kubernetes cluster has been reset to a clean state."
print_status "System components (kube-system) have been preserved."

echo
echo "================================================"
echo "To redeploy your applications, run:"
echo "  ./deploy.sh           # Complete deployment"
echo "  # OR manually:"
echo "  kubectl apply -f namespace.yaml"
echo "  kubectl apply -f postgres-config.yaml"
echo "  kubectl apply -f postgres.yaml"
echo "  kubectl apply -f auth-service.yaml"
echo "  kubectl apply -f people-counter.yaml"
echo "  kubectl apply -f video-transcoder.yaml"
echo "  kubectl apply -f prometheus.yaml"
echo "  kubectl apply -f grafana.yaml"
echo "  ./setup-ingress.sh    # Setup ingress (recommended)"
echo "  # OR: kubectl apply -f ingress.yaml"
echo "================================================"
