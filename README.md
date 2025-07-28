# High Performance Video Cluster - Local Kubernetes

[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.21+-blue.svg)](https://kubernetes.io/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

A complete local Kubernetes deployment for a high-performance video processing cluster with authentication, people counting, video transcoding, and monitoring capabilities.

## 🏗️ Architecture Overview

This project deploys a microservices architecture on local Kubernetes with the following components:

### Core Services

- **Auth Service** - JWT-based authentication and authorization
- **People Counter** - AI-powered people detection and counting service
- **Video Transcoder** - High-performance video processing and transcoding
- **PostgreSQL** - Primary database for persistent storage

### Infrastructure & Monitoring

- **Prometheus** - Metrics collection and monitoring
- **Alertmanager** - Alert routing and notification management
- **Grafana** - Observability dashboards and visualization
- **NGINX Ingress** - Load balancing and routing
- **Persistent Storage** - StatefulSet configurations for data persistence

## 📋 Prerequisites

### Required Software

- **Docker Desktop** with Kubernetes enabled
- **kubectl** (v1.21+)
- **NGINX Ingress Controller**
- **Git**

### System Requirements

- **RAM**: Minimum 8GB, Recommended 16GB+
- **CPU**: 4+ cores recommended
- **Storage**: 20GB+ available space
- **OS**: Linux, macOS, or Windows with WSL2

### Enable Kubernetes in Docker Desktop

1. Open Docker Desktop
2. Go to Settings → Kubernetes
3. Check "Enable Kubernetes"
4. Click "Apply & Restart"

### Install NGINX Ingress Controller

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml
```

## 🚀 Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/moootid/local-k8s.git
cd local-k8s
```

### 2. Configure Security Settings

**⚠️ IMPORTANT**: Replace all placeholder values with actual credentials before deployment.

```bash
# Make scripts executable
chmod +x *.sh

# Validate configuration (this will show what needs to be replaced)
./validate-config.sh
```

See [Security Configuration](#-security-configuration) for detailed setup instructions.

### 3. Deploy the Cluster

```bash
# Deploy all services
./deploy.sh
```

The deployment script will:

- Create namespaces and apply configurations
- Deploy PostgreSQL database
- Deploy all microservices
- Set up monitoring stack
- Configure ingress routing
- Verify deployment status

### 4. Verify Deployment

```bash
# Check all pods are running
kubectl get pods -n myapp

# Check services
kubectl get services -n myapp

# Check ingress
kubectl get ingress -n myapp
```

## 🔐 Security Configuration

### Required Replacements

Before deploying, replace these placeholders in the YAML files:

#### Database Credentials
- `YOUR_DB_PASSWORD` → Your PostgreSQL password
- Files: `auth-service.yaml`, `people-counter.yaml`, `video-transcoder.yaml`, `deploy.sh`
- For `postgres-config.yaml`: Base64 encode your password

```bash
# Generate base64 encoded password
echo -n "your_actual_password" | base64
```

#### JWT Configuration
- `YOUR_JWT_SECRET_KEY` → Strong random secret (32+ characters)

```bash
# Generate JWT secret
openssl rand -base64 32
```

#### AWS Credentials (for S3 integration)

- `YOUR_AWS_ACCESS_KEY_ID` → Your AWS access key
- `YOUR_AWS_SECRET_ACCESS_KEY` → Your AWS secret key
- `YOUR_S3_BUCKET_NAME` → Your S3 bucket name

#### Discord Webhook (for Alertmanager notifications)

- `DISCORD_WEBHOOK` → Your Discord webhook URL for alert notifications
- Required for: `alertmanager.yaml` Discord integration

### Using Kubernetes Secrets (Recommended)

Instead of hardcoding values, create Kubernetes secrets:

```bash
# Database credentials
kubectl create secret generic db-credentials \
  --from-literal=password=your_actual_db_password \
  -n myapp

# JWT secret
kubectl create secret generic jwt-secret \
  --from-literal=key=your_actual_jwt_secret \
  -n myapp

# AWS credentials
kubectl create secret generic aws-credentials \
  --from-literal=access-key-id=your_access_key \
  --from-literal=secret-access-key=your_secret_key \
  -n myapp

# Discord webhook for Alertmanager notifications
kubectl create secret generic discord-webhook-secret \
  --from-literal=DISCORD_WEBHOOK=your_discord_webhook_url \
  -n monitoring
```

For complete security setup instructions, see [`SECURITY_SETUP.md`](SECURITY_SETUP.md).

## 🌐 Access URLs

After successful deployment, services are available at:

### Application Services
- **Auth Service**: http://localhost/auth/health
- **People Counter**: http://localhost/people-counter/
- **Video Transcoder**: http://localhost/video-transcoder/

### Alternative Direct Access
- **Auth Service**: http://auth.localhost/health

### Database Access
- **PostgreSQL**: localhost:5432
- **Connection String**: `postgresql://myapp:YOUR_DB_PASSWORD@localhost:5432/myapp`

### Monitoring (if enabled)

- **Prometheus**: Port-forward to access metrics at `http://localhost:30090`
- **Alertmanager**: Port-forward to access alerts at `http://localhost:30093`
- **Grafana**: Port-forward to access dashboards

## 🛠️ Management Commands

### Deployment Management
```bash
# Full deployment
./deploy.sh

# Cleanup all resources
./cleanup.sh

# Quick cleanup (preserves data)
./quick-cleanup.sh

# Validate configuration
./validate-config.sh
```

### Useful kubectl Commands
```bash
# View logs for a service
kubectl logs -n myapp -l app=auth-service

# Shell into a pod
kubectl exec -it -n myapp <pod-name> -- /bin/bash

# Port forward a service
kubectl port-forward -n myapp service/auth-service 8080:80

# Restart a deployment
kubectl rollout restart deployment/auth-service -n myapp

# Scale a deployment
kubectl scale deployment/auth-service --replicas=5 -n myapp
```

### Monitoring Access

```bash
# Access Prometheus metrics and configuration
kubectl port-forward -n monitoring service/prometheus 9090:9090
# Then visit: http://localhost:9090

# Access Alertmanager for alert management
kubectl port-forward -n monitoring service/alertmanager 9093:9093
# Then visit: http://localhost:9093

# Access Grafana dashboards
kubectl port-forward -n monitoring service/grafana 3000:3000
# Then visit: http://localhost:3000

# Check monitoring pod status
kubectl get pods -n monitoring

# View Prometheus logs
kubectl logs -n monitoring -l app=prometheus

# View Alertmanager logs
kubectl logs -n monitoring -l app=alertmanager
```

### Individual Service Management
```bash
# Redeploy a specific service
kubectl delete deployment auth-service -n myapp
kubectl apply -f auth-service.yaml

# Check service status
kubectl get deployment auth-service -n myapp -o wide
```

## 📊 Monitoring & Observability

### Prometheus Metrics

The cluster includes Prometheus for metrics collection. All services are configured with:

- Health check endpoints
- Prometheus scraping annotations
- Custom metrics exposure

### Alertmanager Integration

Alertmanager handles alert routing and notifications with the following features:

- **Service Availability Alerts**: Monitors service uptime and availability
- **HTTP Error Rate Alerts**: Tracks 5xx error rates across services
- **Resource Usage Alerts**: Monitors memory usage and pod restarts
- **Discord Notifications**: Sends alerts to Discord channels via webhook

#### Setting up Discord Notifications

To enable Discord notifications, create a Discord webhook secret:

```bash
# Create Discord webhook secret
kubectl create secret generic discord-webhook-secret \
  --from-literal=DISCORD_WEBHOOK=your_discord_webhook_url \
  -n monitoring
```

#### Available Alert Rules

- **ServiceDown**: Triggers when a service is unavailable for more than 1 minute
- **HighHttp5xxErrorRate**: Triggers when error rate exceeds 5% for 2 minutes
- **HighMemoryUsage**: Triggers when memory usage exceeds 85% for 5 minutes
- **PodFrequentlyRestarting**: Triggers when pods restart more than once in 5 minutes

### Grafana Dashboards

Grafana provides visualization for:

- Application performance metrics
- Resource utilization
- Error rates and latency
- Custom business metrics

### Log Aggregation

```bash
# View logs from all pods in namespace
kubectl logs -n myapp --all-containers=true -f

# View logs for specific service
kubectl logs -n myapp -l app=people-counter -f
```

## 🗂️ Project Structure

```
local-k8s/
├── README.md                 # This file
├── SECURITY_SETUP.md        # Security configuration guide
├── deploy.sh                # Main deployment script
├── cleanup.sh               # Full cleanup script
├── quick-cleanup.sh         # Quick cleanup script
├── validate-config.sh       # Configuration validation
├── setup-ingress.sh         # Ingress setup helper
├── config.template          # Configuration template
├── namespace.yaml           # Kubernetes namespace
├── postgres-config.yaml     # PostgreSQL configuration
├── postgres.yaml            # PostgreSQL deployment
├── auth-service.yaml        # Authentication service
├── people-counter.yaml      # People counting service
├── video-transcoder.yaml    # Video transcoding service
├── prometheus.yaml          # Prometheus monitoring
├── prometheus-alerts.yaml   # Prometheus alert rules
├── alertmanager.yaml        # Alertmanager configuration
├── grafana.yaml             # Grafana dashboards
└── ingress.yaml             # Ingress routing rules
```

## 🔄 Development Workflow

### Making Changes
1. Modify the relevant YAML file
2. Apply changes: `kubectl apply -f <file>.yaml`
3. Verify: `kubectl get pods -n myapp`

### Testing Services
1. Use port-forwarding to access services locally
2. Check health endpoints
3. Monitor logs for errors

### Updating Images
1. Build and push new image versions
2. Update image tags in YAML files
3. Apply changes: `kubectl apply -f <service>.yaml`
4. Monitor rollout: `kubectl rollout status deployment/<service> -n myapp`

## ⚠️ Troubleshooting

### Common Issues

#### Pods Not Starting
```bash
# Check pod status and events
kubectl describe pod <pod-name> -n myapp

# Check logs
kubectl logs <pod-name> -n myapp
```

#### Image Pull Errors
- Verify image names and tags in YAML files
- Check if images exist in the registry
- For local images, ensure they're built and available

#### Configuration Issues
```bash
# Run configuration validation
./validate-config.sh

# Check for placeholder values
grep -r "YOUR_" *.yaml
```

#### Network/Ingress Issues
```bash
# Check ingress status
kubectl get ingress -n myapp

# Verify ingress controller is running
kubectl get pods -n ingress-nginx
```

#### Database Connection Issues
- Verify PostgreSQL is running: `kubectl get pods -n myapp -l app=postgres`
- Check database credentials are correct
- Verify connection strings in application configs

### Performance Issues
- Monitor resource usage: `kubectl top pods -n myapp`
- Check for resource limits in YAML files
- Scale services if needed: `kubectl scale deployment/<service> --replicas=<count> -n myapp`


### Development Guidelines
- Follow Kubernetes best practices
- Include proper resource limits and requests
- Add health checks for new services
- Update documentation for any configuration changes
- Test all changes locally before submitting

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

For issues and questions:
1. Check the [troubleshooting section](#️-troubleshooting)
2. Review logs using the provided kubectl commands
3. Open an issue on GitHub with:
   - Description of the problem
   - Steps to reproduce
   - Relevant log outputs
   - Environment details

## 🔗 Related Projects

- [Auth Service Repository](https://github.com/moootid/auth-service)
- [People Counter Service](https://github.com/moootid/people-counter)
- [Video Transcoder Service](https://github.com/moootid/video-transcoder)
