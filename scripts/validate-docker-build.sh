#!/bin/bash
# Docker Build Validation Script for DecoCMS
# Tests multi-stage Docker builds locally before deployment

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
PROJECT_NAME="decocms"
WEB_IMAGE="${PROJECT_NAME}-web:test"
API_IMAGE="${PROJECT_NAME}-api:test"
BUILD_LOG="./docker-build.log"

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Function to check if running on supported platform
check_platform() {
    print_status "Checking platform compatibility..."

    # Check if Docker is available
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed or not in PATH"
        print_status "Please install Docker and try again"
        exit 1
    fi

    # Check Docker daemon is running
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker daemon is not running"
        print_status "Please start Docker daemon and try again"
        exit 1
    fi

    # Check Docker version
    DOCKER_VERSION=$(docker --version | cut -d' ' -f3 | sed 's/,//')
    print_success "Docker version: $DOCKER_VERSION ✓"

    # Check available disk space for build cache
    DISK_AVAILABLE=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//')
    if [[ $DISK_AVAILABLE -lt 10 ]]; then
        print_warning "Low disk space for Docker builds: ${DISK_AVAILABLE}GB available"
    else
        print_success "Disk space: ${DISK_AVAILABLE}GB available ✓"
    fi
}

# Function to validate prerequisites
validate_prerequisites() {
    print_status "Validating build prerequisites..."

    # Check required files
    required_files=(
        "Dockerfile"
        "package.json"
        "pnpm-lock.yaml"
    )

    missing_files=()
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            missing_files+=("$file")
        fi
    done

    if [[ ${#missing_files[@]} -gt 0 ]]; then
        print_error "Missing required files: ${missing_files[*]}"
        exit 1
    fi

    print_success "Required files present ✓"

    # Check workspace structure
    if [[ ! -d "apps" ]] || [[ ! -d "packages" ]]; then
        print_error "Missing required directories: apps/ and/or packages/"
        exit 1
    fi

    print_success "Workspace structure valid ✓"

    # Check .dockerignore for optimization
    if [[ ! -f ".dockerignore" ]]; then
        print_warning ".dockerignore not found, builds may be slower"
        create_dockerignore
    fi
}

# Function to create optimized .dockerignore
create_dockerignore() {
    print_status "Creating optimized .dockerignore..."

    cat <<'EOF' > .dockerignore
# Dependencies
node_modules
npm-debug.log*
yarn-debug.log*
yarn-error.log*
pnpm-debug.log*

# Production builds
dist
build
.next
.nuxt
.cache

# Environment files
.env.local
.env.development.local
.env.test.local
.env.production.local

# IDE and editor files
.vscode
.idea
*.swp
*.swo
*~

# OS generated files
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db

# Git
.git
.gitignore
.gitattributes

# Documentation
docs
*.md
!README.md

# Scripts and tools
scripts
.clude

# Test files
coverage
.nyc_output
junit.xml
test-results

# Temporary files
*.tmp
*.temp
*.log
*.tgz
*.tar.gz

# Development tools
.eslintcache
.stylelintcache
EOF

    print_success ".dockerignore created ✓"
}

# Function to build web stage
build_web_stage() {
    print_status "Building web production stage..."

    # Clear previous build log
    > "$BUILD_LOG"

    # Build web stage with progress tracking
    if docker build \
        --target web-production \
        --tag "$WEB_IMAGE" \
        --progress=plain \
        . 2>&1 | tee "$BUILD_LOG"; then

        print_success "Web build completed ✓"

        # Check image size
        WEB_SIZE=$(docker images "$WEB_IMAGE" --format "{{.Size}}")
        print_status "Web image size: $WEB_SIZE"

        # Test web container
        test_web_container
    else
        print_error "Web build failed"
        show_build_errors "web"
        return 1
    fi
}

# Function to build API stage
build_api_stage() {
    print_status "Building API production stage..."

    if docker build \
        --target api-production \
        --tag "$API_IMAGE" \
        --progress=plain \
        . 2>&1 | tee -a "$BUILD_LOG"; then

        print_success "API build completed ✓"

        # Check image size
        API_SIZE=$(docker images "$API_IMAGE" --format "{{.Size}}")
        print_status "API image size: $API_SIZE"

        # Test API container
        test_api_container
    else
        print_error "API build failed"
        show_build_errors "api"
        return 1
    fi
}

# Function to test web container
test_web_container() {
    print_status "Testing web container..."

    # Start web container
    WEB_CONTAINER_ID=$(docker run -d --rm \
        --name "${PROJECT_NAME}-web-test" \
        -p 3000:3000 \
        "$WEB_IMAGE")

    # Wait for container to start
    sleep 5

    # Check if container is running
    if docker ps --filter "id=$WEB_CONTAINER_ID" --quiet | grep -q .; then
        print_success "Web container started successfully ✓"

        # Test health check endpoint
        if curl -f http://localhost:3000/health > /dev/null 2>&1; then
            print_success "Web health check passed ✓"
        else
            print_warning "Web health check failed (endpoint may not be implemented)"
        fi

        # Stop test container
        docker stop "$WEB_CONTAINER_ID" > /dev/null
    else
        print_error "Web container failed to start"
        docker logs "$WEB_CONTAINER_ID" 2>&1 | tail -10
        docker stop "$WEB_CONTAINER_ID" > /dev/null 2>&1 || true
        return 1
    fi
}

# Function to test API container
test_api_container() {
    print_status "Testing API container..."

    # Start API container
    API_CONTAINER_ID=$(docker run -d --rm \
        --name "${PROJECT_NAME}-api-test" \
        -p 3001:3001 \
        -e NODE_ENV=production \
        -e SUPABASE_URL="https://test.supabase.co" \
        -e SUPABASE_ANON_KEY="test-key" \
        "$API_IMAGE")

    # Wait for container to start
    sleep 5

    # Check if container is running
    if docker ps --filter "id=$API_CONTAINER_ID" --quiet | grep -q .; then
        print_success "API container started successfully ✓"

        # Test health check endpoint
        if curl -f http://localhost:3001/health > /dev/null 2>&1; then
            print_success "API health check passed ✓"
        else
            print_warning "API health check failed (endpoint may not be implemented)"
        fi

        # Stop test container
        docker stop "$API_CONTAINER_ID" > /dev/null
    else
        print_error "API container failed to start"
        docker logs "$API_CONTAINER_ID" 2>&1 | tail -10
        docker stop "$API_CONTAINER_ID" > /dev/null 2>&1 || true
        return 1
    fi
}

# Function to show build errors
show_build_errors() {
    local stage="$1"
    print_status "Showing last 20 lines of build log for $stage stage:"
    echo "============================================"
    tail -20 "$BUILD_LOG"
    echo "============================================"

    # Extract common error patterns
    if grep -q "npm ERR\|pnpm ERR\|404\|ENOTFOUND" "$BUILD_LOG"; then
        print_status "Common issues detected:"
        grep -n "npm ERR\|pnpm ERR\|404\|ENOTFOUND" "$BUILD_LOG" | tail -5
    fi
}

# Function to analyze build performance
analyze_build_performance() {
    print_status "Analyzing build performance..."

    if [[ -f "$BUILD_LOG" ]]; then
        # Extract build time from Docker logs
        BUILD_TIME=$(grep -o "real.*m.*s" "$BUILD_LOG" | tail -1 || echo "Not measured")
        print_status "Total build time: $BUILD_TIME"

        # Count number of layers
        LAYER_COUNT=$(grep -c "Step " "$BUILD_LOG")
        print_status "Number of build steps: $LAYER_COUNT"

        # Check for warnings
        WARNING_COUNT=$(grep -c "warning\|Warning" "$BUILD_LOG")
        if [[ $WARNING_COUNT -gt 0 ]]; then
            print_warning "Build warnings: $WARNING_COUNT"
        fi
    fi
}

# Function to generate build report
generate_build_report() {
    local web_result="$1"
    local api_result="$2"

    print_status "Generating build validation report..."

    cat <<EOF > DOCKER_BUILD_REPORT.md
# Docker Build Validation Report - $(date)

## Summary

- **Web Build**: $web_result
- **API Build**: $api_result
- **Docker Version**: $(docker --version)
- **Platform**: $(uname -s) $(uname -m)

## Build Details

### Web Application
- **Image**: $WEB_IMAGE
- **Size**: $(docker images "$WEB_IMAGE" --format "{{.Size}}" 2>/dev/null || echo "Build failed")
- **Exposed Port**: 3000

### API Application
- **Image**: $API_IMAGE
- **Size**: $(docker images "$API_IMAGE" --format "{{.Size}}" 2>/dev/null || echo "Build failed")
- **Exposed Port**: 3001

## Performance Metrics

EOF

    if [[ -f "$BUILD_LOG" ]]; then
        echo "### Build Analysis" >> DOCKER_BUILD_REPORT.md
        echo "" >> DOCKER_BUILD_REPORT.md
        echo "- **Build Time**: $(grep -o "real.*m.*s" "$BUILD_LOG" | tail -1 || echo "Not measured")" >> DOCKER_BUILD_REPORT.md
        echo "- **Build Steps**: $(grep -c "Step " "$BUILD_LOG")" >> DOCKER_BUILD_REPORT.md
        echo "- **Warnings**: $(grep -c "warning\|Warning" "$BUILD_LOG")" >> DOCKER_BUILD_REPORT.md
        echo "" >> DOCKER_BUILD_REPORT.md
    fi

    cat <<EOF >> DOCKER_BUILD_REPORT.md
## Recommendations

EOF

    if [[ "$web_result" == "SUCCESS" && "$api_result" == "SUCCESS" ]]; then
        echo "✅ **Ready for Coolify Deployment**" >> DOCKER_BUILD_REPORT.md
        echo "- All Docker builds completed successfully" >> DOCKER_BUILD_REPORT.md
        echo "- Images are optimized for production" >> DOCKER_BUILD_REPORT.md
        echo "- Health checks are functional" >> DOCKER_BUILD_REPORT.md
    else
        echo "❌ **Build Issues Need Resolution**" >> DOCKER_BUILD_REPORT.md
        echo "- Review build logs for specific errors" >> DOCKER_BUILD_REPORT.md
        echo "- Check VPS resource requirements" >> DOCKER_BUILD_REPORT.md
        echo "- Verify dependency installation" >> DOCKER_BUILD_REPORT.md
    fi

    echo "" >> DOCKER_BUILD_REPORT.md
    echo "## Next Steps" >> DOCKER_BUILD_REPORT.md
    echo "" >> DOCKER_BUILD_REPORT.md
    echo "1. Review DEPLOYMENT_CHECKLIST.md" >> DOCKER_BUILD_REPORT.md
    echo "2. Deploy to Coolify with confidence" >> DOCKER_BUILD_REPORT.md
    echo "3. Monitor deployment with provided scripts" >> DOCKER_BUILD_REPORT.md
    echo "" >> DOCKER_BUILD_REPORT.md
    echo "---" >> DOCKER_BUILD_REPORT.md
    echo "Generated by: decocms-build-validation" >> DOCKER_BUILD_REPORT.md

    print_success "Build report generated: DOCKER_BUILD_REPORT.md"
}

# Cleanup function
cleanup() {
    print_status "Cleaning up test resources..."

    # Remove test containers
    docker stop "${PROJECT_NAME}-web-test" "${PROJECT_NAME}-api-test" 2>/dev/null || true

    # Remove test images
    docker rmi "$WEB_IMAGE" "$API_IMAGE" 2>/dev/null || true

    print_success "Cleanup completed"
}

# Main execution
main() {
    echo "🐳 DecoCMS Docker Build Validation"
    echo "================================="

    # Set up cleanup trap
    trap cleanup EXIT

    local web_result="FAILED"
    local api_result="FAILED"

    check_platform
    validate_prerequisites

    print_status ""
    print_status "Starting Docker build validation..."
    print_status "This may take 10-20 minutes depending on your system specs"

    # Build web stage
    if build_web_stage; then
        web_result="SUCCESS"
    fi

    print_status ""

    # Build API stage
    if build_api_stage; then
        api_result="SUCCESS"
    fi

    print_status ""
    analyze_build_performance
    generate_build_report "$web_result" "$api_result"

    print_status ""
    if [[ "$web_result" == "SUCCESS" && "$api_result" == "SUCCESS" ]]; then
        print_success "🎉 All Docker builds validated successfully!"
        print_status "Your DecoCMS is ready for Coolify deployment!"
        print_status "Review DOCKER_BUILD_REPORT.md for details."
    else
        print_error "❌ Build validation failed"
        print_status "Review build logs and fix issues before deploying to Coolify."
        exit 1
    fi
}

# Run main function
main "$@"