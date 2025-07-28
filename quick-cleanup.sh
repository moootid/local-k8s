#!/bin/bash

# Quick Kubernetes Cleanup Script
# Removes all resources from 'myapp' namespace quickly

echo "🧹 Quick cleanup: Removing all resources from 'myapp' namespace..."

# Check if myapp namespace exists
if kubectl get namespace myapp &> /dev/null; then
    echo "Deleting all resources in 'myapp' namespace..."
    kubectl delete all --all -n myapp
    
    echo "Deleting PVCs..."
    kubectl delete pvc --all -n myapp
    
    echo "Deleting secrets and configmaps..."
    kubectl delete secrets,configmaps --all -n myapp
    
    echo "Deleting namespace 'myapp'..."
    kubectl delete namespace myapp
    
    echo "✅ Cleanup complete!"
else
    echo "⚠️  Namespace 'myapp' does not exist"
fi

echo
echo "To redeploy your apps:"
echo "  ./deploy.sh"
echo "  # or manually:"
echo "  kubectl apply -f namespace.yaml"
echo "  kubectl apply -f *.yaml"
