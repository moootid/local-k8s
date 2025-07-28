# Security Configuration Guide

This guide helps you configure sensitive data for your Kubernetes deployment. **Never commit sensitive data to version control.**

## Required Sensitive Data

### 1. Database Configuration

Replace the following placeholders in your YAML files:

- `YOUR_DB_PASSWORD`: Your PostgreSQL database password
  - Files to update: `auth-service.yaml`, `people-counter.yaml`, `video-transcoder.yaml`, `deploy.sh`
  - For `postgres-config.yaml`: Base64 encode your password and replace `WU9VUl9EQl9QQVNTV09SRA==`
  
**To generate base64 encoded password:**
```bash
echo -n "your_actual_password" | base64
```

### 2. JWT Secret Key

Replace `YOUR_JWT_SECRET_KEY` in `auth-service.yaml`:
- Use a strong, randomly generated secret (at least 32 characters)
- Generate one with: `openssl rand -base64 32`

### 3. AWS Credentials

Replace the following placeholders in `people-counter.yaml` and `video-transcoder.yaml`:

- `YOUR_AWS_ACCESS_KEY_ID`: Your AWS Access Key ID
- `YOUR_AWS_SECRET_ACCESS_KEY`: Your AWS Secret Access Key
- `YOUR_S3_BUCKET_NAME`: Your S3 bucket name (in `video-transcoder.yaml`)

### 4. Security Best Practices

#### Option A: Using Kubernetes Secrets (Recommended)

Instead of hardcoding values, create Kubernetes secrets:

```bash
# Create database secret
kubectl create secret generic db-credentials \
  --from-literal=password=your_actual_db_password \
  -n myapp

# Create JWT secret
kubectl create secret generic jwt-secret \
  --from-literal=key=your_actual_jwt_secret \
  -n myapp

# Create AWS credentials secret
kubectl create secret generic aws-credentials \
  --from-literal=access-key-id=your_aws_access_key \
  --from-literal=secret-access-key=your_aws_secret_key \
  -n myapp
```

Then update your deployment files to reference these secrets using `secretKeyRef`.

#### Option B: Environment-based Configuration

Use environment variables and substitute them before applying:

```bash
export DB_PASSWORD="your_actual_password"
export JWT_SECRET="your_actual_jwt_secret"
export AWS_ACCESS_KEY_ID="your_aws_access_key"
export AWS_SECRET_ACCESS_KEY="your_aws_secret_key"
export S3_BUCKET_NAME="your_bucket_name"

# Use envsubst to replace variables
envsubst < auth-service.yaml | kubectl apply -f -
```

#### Option C: Using Helm or Kustomize

Consider using Helm charts or Kustomize for better configuration management.

## Files That Contain Sensitive Data Placeholders

1. **auth-service.yaml**
   - `YOUR_DB_PASSWORD`
   - `YOUR_JWT_SECRET_KEY`

2. **people-counter.yaml**
   - `YOUR_DB_PASSWORD`
   - `YOUR_AWS_ACCESS_KEY_ID`
   - `YOUR_AWS_SECRET_ACCESS_KEY`

3. **video-transcoder.yaml**
   - `YOUR_DB_PASSWORD`
   - `YOUR_AWS_ACCESS_KEY_ID`
   - `YOUR_AWS_SECRET_ACCESS_KEY`
   - `YOUR_S3_BUCKET_NAME`

4. **postgres-config.yaml**
   - `WU9VUl9EQl9QQVNTV09SRA==` (base64 encoded placeholder)

5. **deploy.sh**
   - `YOUR_DB_PASSWORD` (in connection string example)

## Deployment Checklist

- [ ] Replace all `YOUR_*` placeholders with actual values
- [ ] Ensure all secrets are properly base64 encoded where required
- [ ] Verify AWS credentials have appropriate permissions
- [ ] Test database connectivity with new credentials
- [ ] Confirm JWT secret is sufficiently strong
- [ ] Remove this file from production deployments
- [ ] Add sensitive files to `.gitignore`

## Security Notes

- Never commit actual credentials to version control
- Use separate credentials for different environments (dev/staging/prod)
- Rotate credentials regularly
- Use minimal required permissions for AWS IAM users
- Consider using AWS IAM roles for service accounts (IRSA) instead of access keys
- Monitor access logs and set up alerts for suspicious activity

## Need Help?

If you encounter issues:
1. Verify all placeholders are replaced
2. Check Kubernetes secret creation
3. Validate base64 encoding
4. Confirm AWS permissions
5. Review Kubernetes logs: `kubectl logs <pod-name> -n myapp`
