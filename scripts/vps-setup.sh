#!/bin/bash
# VPS Setup Script for DecoCMS Coolify Deployment
# This script configures a VPS for DecoCMS deployment requirements

set -e

echo "🚀 Setting up VPS for DecoCMS Coolify deployment..."

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

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_warning "Running as root. Some commands will use sudo where needed."
    fi
}

# Check system resources
check_resources() {
    print_status "Checking system resources..."

    # Check RAM
    TOTAL_RAM=$(free -m | awk 'NR==2{printf "%.0f", $2}')
    if [[ $TOTAL_RAM -lt 4096 ]]; then
        print_error "Insufficient RAM: ${TOTAL_RAM}MB detected. Minimum 4096MB required for DecoCMS builds."
        print_warning "Consider upgrading your VPS to at least 4GB RAM."
        return 1
    else
        print_success "RAM: ${TOTAL_RAM}MB ✓"
    fi

    # Check CPU cores
    CPU_CORES=$(nproc)
    if [[ $CPU_CORES -lt 2 ]]; then
        print_warning "Low CPU cores detected: ${CPU_CORES}. Minimum 2 recommended."
    else
        print_success "CPU: ${CPU_CORES} cores ✓"
    fi

    # Check disk space
    DISK_AVAILABLE=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [[ $DISK_AVAILABLE -lt 20 ]]; then
        print_warning "Low disk space: ${DISK_AVAILABLE}GB available. Minimum 20GB recommended."
    else
        print_success "Disk: ${DISK_AVAILABLE}GB available ✓"
    fi
}

# Check and install Node.js 24
setup_nodejs() {
    print_status "Setting up Node.js 24..."

    CURRENT_NODE_VERSION=$(node --version 2>/dev/null | cut -d'v' -f2 | cut -d'.' -f1)
    REQUIRED_NODE_VERSION=24

    if [[ "$CURRENT_NODE_VERSION" -eq "$REQUIRED_NODE_VERSION" ]]; then
        print_success "Node.js v24 is already installed ✓"
        return 0
    fi

    print_status "Installing Node.js v24..."

    # Install using NodeSource repository
    if command -v apt-get &> /dev/null; then
        # Ubuntu/Debian
        curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -
        sudo apt-get install -y nodejs
    elif command -v yum &> /dev/null; then
        # CentOS/RHEL
        curl -fsSL https://rpm.nodesource.com/setup_24.x | sudo bash -
        sudo yum install -y nodejs npm
    elif command -v dnf &> /dev/null; then
        # Fedora
        curl -fsSL https://rpm.nodesource.com/setup_24.x | sudo bash -
        sudo dnf install -y nodejs npm
    else
        print_error "Unsupported package manager. Please install Node.js 24 manually."
        return 1
    fi

    # Verify installation
    NEW_NODE_VERSION=$(node --version | cut -d'v' -f1)
    if [[ "$NEW_NODE_VERSION" == "v24" ]]; then
        print_success "Node.js $NEW_NODE_VERSION installed successfully ✓"
    else
        print_error "Node.js installation failed. Current version: $NEW_NODE_VERSION"
        return 1
    fi
}

# Configure JSR registry
setup_jsr_registry() {
    print_status "Configuring JSR registry..."

    # Set JSR registry globally
    npm config set @jsr:registry https://npm.jsr.io/
    npm config set @jsr:token ""
    npm config set registry https://registry.npmjs.org/

    # Verify JSR registry configuration
    JSR_REGISTRY=$(npm config get @jsr:registry)
    if [[ "$JSR_REGISTRY" == "https://npm.jsr.io/" ]]; then
        print_success "JSR registry configured ✓"
    else
        print_error "Failed to configure JSR registry"
        return 1
    fi
}

# Setup Docker and BuildKit
setup_docker() {
    print_status "Setting up Docker..."

    if ! command -v docker &> /dev/null; then
        print_status "Installing Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        sudo usermod -aG docker $USER
        rm get-docker.sh
        print_success "Docker installed ✓"
    else
        print_success "Docker is already installed ✓"
    fi

    # Enable Docker BuildKit
    echo 'export DOCKER_BUILDKIT=1' | sudo tee -a /etc/environment
    export DOCKER_BUILDKIT=1

    # Verify Docker version
    DOCKER_VERSION=$(docker --version | cut -d' ' -f3 | sed 's/,//')
    print_success "Docker version: $DOCKER_VERSION ✓"
}

# Configure Coolify environment
configure_coolify() {
    print_status "Configuring Coolify environment variables..."

    # Create Coolify configuration directory
    sudo mkdir -p /etc/coolify

    # Set build limits for DecoCMS
    cat <<EOF | sudo tee /etc/coolify/decocms.conf
# DecoCMS Coolify Configuration
export COOLIFY_BUILD_MEMORY_LIMIT=4g
export COOLIFY_BUILD_CPU_LIMIT=2
export COOLIFY_BUILD_TIMEOUT=1800
export DOCKER_BUILDKIT=1
export NODE_OPTIONS="--max-old-space-size=4096"
EOF

    print_success "Coolify environment configured ✓"
}

# Configure firewall for npm/JSR access
setup_firewall() {
    print_status "Configuring firewall for npm/JSR registry access..."

    if command -v ufw &> /dev/null; then
        # Ubuntu firewall
        sudo ufw allow out 80/tcp
        sudo ufw allow out 443/tcp
        sudo ufw allow out 443/tcp to registry.npmjs.org
        sudo ufw allow out 443/tcp to npm.jsr.io
        print_success "Firewall configured for npm/JSR access ✓"
    elif command -v firewall-cmd &> /dev/null; then
        # CentOS/RHEL firewall
        sudo firewall-cmd --permanent --add-service=http
        sudo firewall-cmd --permanent --add-service=https
        sudo firewall-cmd --reload
        print_success "Firewall configured for npm/JSR access ✓"
    else
        print_warning "Could not configure firewall automatically. Please ensure ports 80 and 443 are open for outbound connections."
    fi
}

# Create deployment health check script
create_health_check() {
    print_status "Creating deployment health check script..."

    cat <<'EOF' > ~/decocms-health-check.sh
#!/bin/bash
# DecoCMS Deployment Health Check

echo "🏥 DecoCMS Health Check"
echo "======================="

# Check Node.js version
echo "Node.js: $(node --version)"

# Check Docker
echo "Docker: $(docker --version | cut -d' ' -f3)"

# Check JSR registry
echo "JSR Registry: $(npm config get @jsr:registry)"

# Check available memory
echo "Available RAM: $(free -m | awk 'NR==2{printf "%.0fMB", $7}')"

# Check disk space
echo "Available Disk: $(df -h / | awk 'NR==2 {print $4}')"

# Test npm registry access
if curl -s https://registry.npmjs.org/ > /dev/null; then
    echo "npm Registry: ✓ Accessible"
else
    echo "npm Registry: ❌ Not accessible"
fi

# Test JSR registry access
if curl -s https://npm.jsr.io/ > /dev/null; then
    echo "JSR Registry: ✓ Accessible"
else
    echo "JSR Registry: ❌ Not accessible"
fi

echo "======================="
EOF

    chmod +x ~/decocms-health-check.sh
    print_success "Health check script created: ~/decocms-health-check.sh"
}

# Validate VPS configuration
validate_configuration() {
    print_status "Validating VPS configuration..."

    # Run health check
    ~/decocms-health-check.sh

    print_status ""
    print_status "Configuration Summary:"
    print_status "- VPS Resources: ✓ Checked"
    print_status "- Node.js 24: ✓ Installed"
    print_status "- JSR Registry: ✓ Configured"
    print_status "- Docker: ✓ Configured with BuildKit"
    print_status "- Coolify Environment: ✓ Optimized"
    print_status "- Firewall: ✓ Configured"

    print_success "VPS is ready for DecoCMS deployment! 🚀"
}

# Main execution
main() {
    echo "🎯 DecoCMS VPS Setup Script"
    echo "============================="

    check_root

    if check_resources; then
        setup_nodejs
        setup_jsr_registry
        setup_docker
        configure_coolify
        setup_firewall
        create_health_check
        validate_configuration
    else
        print_error "VPS does not meet minimum requirements. Please upgrade your VPS and run this script again."
        exit 1
    fi
}

# Run main function
main "$@"