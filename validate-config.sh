#!/bin/bash

# Configuration Validation Script
# This script checks if all sensitive data placeholders have been replaced

set -e

echo "🔍 Validating Kubernetes configuration..."
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

# Track validation status
validation_failed=false

# Function to check for placeholders in files
check_placeholders() {
    local file=$1
    local description=$2
    
    if [[ ! -f "$file" ]]; then
        print_warning "File $file not found"
        return
    fi
    
    print_status "Checking $description ($file)..."
    
    # Check for placeholder patterns (exclude documentation and comments)
    placeholders_found=""
    
    # Get lines with YOUR_ but exclude those in echo/print statements and comments
    your_placeholders=$(grep -n "YOUR_.*" "$file" | grep -v "echo\|print_warning\|print_status\|#.*YOUR" || true)
    if [[ -n "$your_placeholders" ]]; then
        placeholders_found="$placeholders_found YOUR_* patterns"
    fi
    
    if grep -q "your_actual_.*" "$file"; then
        placeholders_found="$placeholders_found your_actual_* patterns"
    fi
    
    if grep -q "WU9VUl9EQl9QQVNTV09SRA==" "$file"; then
        placeholders_found="$placeholders_found base64 placeholder"
    fi
    
    if [[ -n "$placeholders_found" ]]; then
        print_error "  Found placeholders:$placeholders_found"
        validation_failed=true
        
        # Show specific lines with placeholders
        echo "  Problematic lines:"
        if [[ "$placeholders_found" == *"YOUR_*"* ]]; then
            echo "$your_placeholders" | while read line; do
                echo "    $line"
            done
        fi
        if [[ "$placeholders_found" == *"your_actual_*"* ]]; then
            grep -n "your_actual_.*" "$file" | while read line; do
                echo "    $line"
            done
        fi
        if [[ "$placeholders_found" == *"base64 placeholder"* ]]; then
            grep -n "WU9VUl9EQl9QQVNTV09SRA==" "$file" | while read line; do
                echo "    $line"
            done
        fi
    else
        print_success "  No placeholders found"
    fi
}

# Function to validate base64 encoding
validate_base64() {
    local encoded_value=$1
    local description=$2
    
    if echo "$encoded_value" | base64 -d &>/dev/null; then
        print_success "  $description is valid base64"
    else
        print_error "  $description is not valid base64"
        validation_failed=true
    fi
}

# Check each configuration file
echo
print_status "Checking configuration files for placeholders..."
echo

check_placeholders "auth-service.yaml" "Auth Service Configuration"
check_placeholders "people-counter.yaml" "People Counter Configuration" 
check_placeholders "video-transcoder.yaml" "Video Transcoder Configuration"
check_placeholders "postgres-config.yaml" "PostgreSQL Configuration"
check_placeholders "deploy.sh" "Deployment Script"

# Additional checks for postgres-config.yaml
echo
print_status "Validating PostgreSQL secret encoding..."
if [[ -f "postgres-config.yaml" ]]; then
    postgres_password=$(grep "POSTGRES_PASSWORD:" postgres-config.yaml | awk '{print $2}' | head -1)
    if [[ "$postgres_password" != "WU9VUl9EQl9QQVNTV09SRA==" ]]; then
        validate_base64 "$postgres_password" "PostgreSQL password"
    else
        print_error "  PostgreSQL password still contains placeholder"
        validation_failed=true
    fi
fi

# Check for security best practices
echo
print_status "Checking security best practices..."

# Check if sensitive files are in .gitignore
if [[ -f ".gitignore" ]]; then
    if grep -q "\*secret\*\|\*credential\*\|\.env" .gitignore; then
        print_success "  .gitignore includes sensitive file patterns"
    else
        print_warning "  .gitignore may not cover all sensitive files"
    fi
else
    print_warning "  No .gitignore file found"
fi

# Check for common security issues
for file in *.yaml; do
    if [[ -f "$file" ]]; then
        # Check for hardcoded passwords that look like real ones
        if grep -qE "password.*[a-zA-Z0-9]{8,}" "$file"; then
            potential_passwords=$(grep -nE "password.*[a-zA-Z0-9]{8,}" "$file")
            if [[ -n "$potential_passwords" ]]; then
                print_warning "  Potential hardcoded passwords found in $file:"
                echo "$potential_passwords" | while read line; do
                    echo "    $line"
                done
            fi
        fi
    fi
done

echo
echo "================================================"

if [[ "$validation_failed" == "true" ]]; then
    print_error "❌ Configuration validation FAILED"
    echo
    echo "Please fix the issues above before deploying:"
    echo "1. Replace all YOUR_* placeholders with actual values"
    echo "2. Ensure base64 encoded values are valid"
    echo "3. Review the SECURITY_SETUP.md file for guidance"
    echo
    exit 1
else
    print_success "✅ Configuration validation PASSED"
    echo
    echo "Your configuration appears to be ready for deployment!"
    echo "Run ./deploy.sh to deploy your application."
    echo
    exit 0
fi
