#!/bin/bash
# Coolify Deployment Validation Script for DecoCMS
# This script validates deployment configuration and monitors deployment health

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
COOLIFY_API_URL="${COOLIFY_API_URL:-http://localhost:8000}"
COOLIFY_API_TOKEN="${COOLIFY_API_TOKEN:-}"
PROJECT_NAME="decocms"
MAX_DEPLOYMENT_TIME=1800  # 30 minutes

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."

    # Check if Coolify CLI is available
    if ! command -v coolify &> /dev/null; then
        print_warning "Coolify CLI not found. Using API checks only."
    fi

    # Check environment variables
    if [[ -z "$COOLIFY_API_TOKEN" ]]; then
        print_warning "COOLIFY_API_TOKEN not set. API checks limited."
    fi

    # Check project configuration
    if [[ ! -f "docker-compose.yml" ]]; then
        print_error "docker-compose.yml not found in current directory."
        exit 1
    fi

    if [[ ! -f "Dockerfile" ]]; then
        print_error "Dockerfile not found in current directory."
        exit 1
    fi

    print_success "Prerequisites check passed ✓"
}

# Validate Docker configuration
validate_docker_config() {
    print_status "Validating Docker configuration..."

    # Check Dockerfile syntax
    if docker --version > /dev/null 2>&1; then
        if docker build --dry-run -f Dockerfile . > /dev/null 2>&1; then
            print_success "Dockerfile syntax valid ✓"
        else
            print_error "Dockerfile syntax error"
            return 1
        fi
    else
        print_warning "Docker not available for local validation"
    fi

    # Check docker-compose.yml syntax
    if command -v docker-compose &> /dev/null; then
        if docker-compose -f docker-compose.yml config > /dev/null 2>&1; then
            print_success "docker-compose.yml syntax valid ✓"
        else
            print_error "docker-compose.yml syntax error"
            return 1
        fi
    fi

    # Validate environment variables
    if [[ -f ".env" ]]; then
        required_vars=("SUPABASE_URL" "PROJECT_DOMAIN" "VITE_API_URL")
        missing_vars=()

        for var in "${required_vars[@]}"; do
            if ! grep -q "^${var}=" .env; then
                missing_vars+=("$var")
            fi
        done

        if [[ ${#missing_vars[@]} -eq 0 ]]; then
            print_success "Required environment variables present ✓"
        else
            print_warning "Missing environment variables: ${missing_vars[*]}"
        fi
    else
        print_warning ".env file not found"
    fi
}

# Simulate build process (quick validation)
simulate_build() {
    print_status "Simulating build process..."

    # Check if all required files are present
    required_files=(
        "package.json"
        "pnpm-lock.yaml"
        "Dockerfile"
        "apps/web/package.json"
        "apps/api/package.json"
        "packages/ai/package.json"
        "packages/ui/package.json"
        "packages/sdk/package.json"
    )

    missing_files=()
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            missing_files+=("$file")
        fi
    done

    if [[ ${#missing_files[@]} -eq 0 ]]; then
        print_success "All required files present ✓"
    else
        print_error "Missing required files: ${missing_files[*]}"
        return 1
    fi

    # Validate workspace configuration
    if [[ -f "pnpm-workspace.yaml" ]]; then
        print_success "pnpm workspace configuration present ✓"
    elif grep -q '"workspaces"' package.json; then
        print_success "npm workspace configuration present ✓"
    else
        print_warning "No workspace configuration found"
    fi

    # Check JSR packages configuration
    if grep -q "@jsr:" package.json apps/*/package.json packages/*/package.json; then
        print_success "JSR packages configured ✓"
    else
        print_warning "JSR packages not found"
    fi
}

# Test repository connectivity
test_connectivity() {
    print_status "Testing repository and registry connectivity..."

    # Test npm registry
    if curl -s --connect-timeout 10 https://registry.npmjs.org/ > /dev/null; then
        print_success "npm registry accessible ✓"
    else
        print_error "npm registry not accessible"
        return 1
    fi

    # Test JSR registry
    if curl -s --connect-timeout 10 https://npm.jsr.io/ > /dev/null; then
        print_success "JSR registry accessible ✓"
    else
        print_warning "JSR registry not accessible (may cause build issues)"
    fi

    # Test GitHub connectivity (if using GitHub repository)
    if grep -q "github.com" .git/config 2>/dev/null; then
        if git fetch --dry-run > /dev/null 2>&1; then
            print_success "GitHub repository accessible ✓"
        else
            print_warning "GitHub repository access issues"
        fi
    fi
}

# Create deployment monitoring script
create_deployment_monitor() {
    print_status "Creating deployment monitoring script..."

    cat <<'EOF' > ~/decocms-deployment-monitor.sh
#!/bin/bash
# DecoCMS Deployment Monitor

DEPLOYMENT_ID="$1"
PROJECT_NAME="${PROJECT_NAME:-decocms}"
LOG_FILE="$HOME/decocms-deployment.log"

if [[ -z "$DEPLOYMENT_ID" ]]; then
    echo "Usage: $0 <deployment_id>"
    exit 1
fi

echo "🔍 Monitoring DecoCMS Deployment: $DEPLOYMENT_ID"
echo "Log file: $LOG_FILE"
echo "============================================"

# Function to check deployment status
check_deployment() {
    local deployment_id="$1"

    if command -v coolify &> /dev/null && [[ -n "$COOLIFY_API_TOKEN" ]]; then
        coolify deployment status "$deployment_id" 2>/dev/null || echo "Status check failed"
    else
        echo "Coolify CLI not available or API token missing"
    fi
}

# Function to check resource usage
check_resources() {
    echo "System Resources:"
    echo "CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)% used"
    echo "Memory: $(free | grep Mem | awk '{printf "%.1f%%", $3/$2 * 100.0}')"
    echo "Disk: $(df -h / | tail -1 | awk '{print $5}')"
}

# Function to check Docker containers
check_containers() {
    echo "Docker Containers:"
    if command -v docker &> /dev/null; then
        docker ps -a --filter "name=$PROJECT_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" || echo "No containers found"
    else
        echo "Docker not available"
    fi
}

# Monitor deployment
START_TIME=$(date +%s)
while true; do
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))

    echo "[$(date)] Elapsed: ${ELAPSED}s"
    check_deployment "$DEPLOYMENT_ID"
    check_resources
    check_containers

    # Check if deployment exceeded maximum time
    if [[ $ELAPSED -gt $MAX_DEPLOYMENT_TIME ]]; then
        echo "⚠️ Deployment timeout exceeded (${MAX_DEPLOYMENT_TIME}s)"
        break
    fi

    # Check if deployment completed (you may need to customize this based on your Coolify setup)
    if docker ps --filter "name=$PROJECT_NAME" --filter "status=running" | grep -q "healthy"; then
        echo "✅ Deployment completed successfully!"
        break
    fi

    sleep 30
done

echo "============================================"
echo "Monitoring completed at $(date)"
EOF

    chmod +x ~/decocms-deployment-monitor.sh
    print_success "Deployment monitor script created: ~/decocms-deployment-monitor.sh"
}

# Generate deployment checklist
generate_checklist() {
    print_status "Generating deployment checklist..."

    cat <<EOF > DEPLOYMENT_CHECKLIST.md
# DecoCMS Coolify Deployment Checklist

## Pre-Deployment Checklist

### VPS Configuration ✅
- [ ] RAM: 4GB+ (Current: $(free -m | awk 'NR==2{printf "%.0fGB", $2/1024}'))
- [ ] CPU: 2+ vCPU (Current: $(nproc))
- [ ] Disk: 40GB+ available (Current: $(df -h / | tail -1 | awk '{print $4}'))
- [ ] Node.js v24+ (Current: $(node --version 2>/dev/null || echo "Not installed"))
- [ ] Docker with BuildKit enabled
- [ ] JSR registry configured

### Project Configuration ✅
- [ ] pnpm-lock.yaml present and committed
- [ ] Dockerfile properly configured for multi-stage builds
- [ ] Environment variables configured in .env
- [ ] Supabase credentials correctly set
- [ ] JSR packages properly referenced

### Coolify Configuration ✅
- [ ] Project repository connected
- [ ] Build timeout set to 30+ minutes
- [ ] Resource limits configured (4GB RAM, 2 CPU)
- [ ] Environment variables injected correctly
- [ ] Health checks configured

## Deployment Process

1. **Trigger Deployment**
   \`\`\`bash
   # Via Coolify UI or API
   # Note deployment ID for monitoring
   \`\`\`

2. **Monitor Deployment**
   \`\`\`bash
   ~/decocms-deployment-monitor.sh <deployment_id>
   \`\`\`

3. **Verify Services**
   \`\`\`bash
   # Check web service
   curl -f https://\$PROJECT_DOMAIN/health

   # Check API service
   curl -f https://api.\$PROJECT_DOMAIN/health
   \`\`\`

## Post-Deployment Checklist

### Service Health ✅
- [ ] Web frontend loads correctly
- [ ] API endpoints respond
- [ ] Database connections work
- [ ] Supabase integration functional
- [ ] SSL certificates valid

### Performance ✅
- [ ] Page load times < 3 seconds
- [ ] API response times < 500ms
- [ ] Memory usage within limits
- [ ] No error logs in containers

### Security ✅
- [ ] Environment variables not exposed
- [ ] HTTPS properly configured
- [ ] Security headers present
- [ ] Database access properly restricted

## Troubleshooting

### Common Issues

1. **Build Failures**
   - Check VPS resources (RAM/CPU)
   - Verify JSR registry access
   - Review build logs for dependency issues

2. **Runtime Errors**
   - Check environment variables
   - Verify database connectivity
   - Review container logs

3. **Performance Issues**
   - Monitor resource usage
   - Check database queries
   - Verify caching configuration

### Emergency Rollback

\`\`\`bash
# Roll to previous deployment via Coolify UI
# Or restore from backup if needed
\`\`\`

---

Last Updated: $(date)
Generated by: decocms-setup scripts
EOF

    print_success "Deployment checklist created: DEPLOYMENT_CHECKLIST.md"
}

# Main execution
main() {
    echo "🔍 DecoCMS Coolify Deployment Validation"
    echo "======================================="

    check_prerequisites
    validate_docker_config
    simulate_build
    test_connectivity
    create_deployment_monitor
    generate_checklist

    echo ""
    print_success "Validation completed! 🎉"
    print_status "Next steps:"
    print_status "1. Review DEPLOYMENT_CHECKLIST.md"
    print_status "2. Run deployment on your VPS"
    print_status "3. Monitor with: ~/decocms-deployment-monitor.sh <deployment_id>"
}

# Run main function
main "$@"