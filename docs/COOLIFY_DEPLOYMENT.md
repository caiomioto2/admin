# DecoCMS Coolify Deployment Guide

This comprehensive guide covers deploying DecoCMS using Coolify with Docker containers, automated CI/CD pipelines, and production-ready configurations.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Coolify Setup](#coolify-setup)
4. [Environment Configuration](#environment-configuration)
5. [Deployment Strategy](#deployment-strategy)
6. [Step-by-Step Implementation](#step-by-step-implementation)
7. [Monitoring and Maintenance](#monitoring-and-maintenance)
8. [Troubleshooting](#troubleshooting)
9. [Security Best Practices](#security-best-practices)
10. [Performance Optimization](#performance-optimization)

## Overview

### Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Web Service   │    │   API Service   │    │   Traefik       │
│  (Nginx + SPA)  │────│  (Node.js API)  │────│  (Load Balancer)│
│   Port: 3000    │    │   Port: 3001    │    │  Ports: 80/443  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │   Supabase DB   │
                    │   (External)    │
                    │   PostgreSQL    │
                    └─────────────────┘
```

### Services

- **Web Service**: React/Vite frontend served by Nginx with PWA support
- **API Service**: Hono backend with Node.js 24+
- **Database**: Supabase (PostgreSQL) or local PostgreSQL
- **Reverse Proxy**: Traefik for SSL termination and load balancing
- **Cache**: Redis for session storage and caching (optional)

## Prerequisites

### System Requirements

- **Coolify Server**: Ubuntu 20.04+ / Debian 11+ / CentOS 8+
- **Minimum Resources**: 2 CPU, 4GB RAM, 20GB storage
- **Recommended Resources**: 4 CPU, 8GB RAM, 50GB storage
- **Docker**: 20.10+ with Docker Compose v2
- **Git**: 2.30+

### Required Accounts

1. **Coolify**: Self-hosted instance or managed account
2. **Git Provider**: GitHub, GitLab, Bitbucket, or Gitea
3. **Container Registry**: GitHub Container Registry, Docker Hub, or private registry
4. **Database**: Supabase account or self-hosted PostgreSQL
5. **DNS**: Domain name for production deployment

### Environment Variables

Prepare the following values before starting:

```bash
# Project Configuration
PROJECT_NAME=decocms
DOMAIN=yourdomain.com
REGISTRY=ghcr.io

# Database
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
SUPABASE_ANON_KEY=your-anon-key

# API Security
JWT_SECRET=your-32-character-secret-key
OPENROUTER_API_KEY=your-openrouter-key

# SSL/TLS
LETSENCRYPT_EMAIL=admin@yourdomain.com
```

## Coolify Setup

### 1. Install Coolify

```bash
# Install Coolify using their official script
curl -fsSL https://coolify.io/install.sh | sh

# Or manual installation
git clone https://github.com/coollabsio/coolify.git
cd coolify
cp .env.example .env
# Edit .env with your configuration
docker-compose up -d
```

### 2. Configure Coolify

1. **Access Coolify**: Navigate to `http://your-server-ip:8000`
2. **Initial Setup**: Create admin account and configure basic settings
3. **Git Integration**: Connect your Git provider account
4. **Registry Setup**: Configure container registry access

### 3. Create Project in Coolify

1. **New Project**: Click "New Project" → "From Git Repository"
2. **Select Repository**: Choose your DecoCMS repository
3. **Configure Branches**: Select main (production) and develop (staging)
4. **Set Build Context**: Root directory of repository

## Environment Configuration

### Production Environment (.env)

```bash
# Copy and customize the template
cp .env.example .env

# Edit with your values
nano .env
```

**Critical Environment Variables:**

```bash
# Database (Required for production)
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
SUPABASE_ANON_KEY=your-anon-key

# API Security (Required)
JWT_SECRET=your-32-character-secret-key-minimum
OPENROUTER_API_KEY=your-openrouter-api-key

# CORS Configuration (Required)
CORS_ORIGIN=https://yourdomain.com

# Frontend Configuration
VITE_USE_LOCAL_BACKEND=false
VITE_API_URL=https://api.yourdomain.com
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-key
```

### Development Environment (.env.development)

```bash
# Development overrides
NODE_ENV=development
VITE_USE_LOCAL_BACKEND=true
VITE_API_URL=http://localhost:3001
CORS_ORIGIN=http://localhost:3000
LOG_LEVEL=debug
```

### Coolify Environment Variables

Add these in Coolify's environment configuration:

```bash
# Coolify auto-injects these during deployment
COOLIFY_SERVICE_ID=your-service-id
COOLIFY_DEPLOYMENT_ID=deployment-id
COOLIFY_ENVIRONMENT=production
COOLIFY_BRANCH=main
```

## Deployment Strategy

### Multi-Environment Setup

1. **Production**: `main` branch → `yourdomain.com`
2. **Staging**: `develop` branch → `staging.yourdomain.com`
3. **Development**: Feature branches → `feature-name.yourdomain.com`

### Service Architecture

**Web Service:**
- Multi-stage build with Nginx
- PWA optimization with service worker caching
- Static asset optimization (gzip, compression)
- Health check endpoint `/health`

**API Service:**
- Node.js 24+ Alpine Linux
- Production-optimized Hono application
- Health check endpoint `/health`
- Graceful shutdown handling
- Memory and CPU limits

### Database Strategy

**Option 1: Supabase (Recommended)**
- Managed PostgreSQL service
- Built-in authentication
- Real-time subscriptions
- Automatic backups
- Edge functions support

**Option 2: Self-hosted PostgreSQL**
- Full control over data
- Local development support
- Custom backup strategies
- Advanced configuration options

## Step-by-Step Implementation

### Phase 1: Repository Preparation

1. **Repository Setup:**
   ```bash
   # Ensure all files are committed
   git add .
   git commit -m "Add Coolify deployment configuration"
   git push origin main
   ```

2. **Branch Strategy:**
   ```bash
   # Create develop branch if not exists
   git checkout -b develop
   git push origin develop
   ```

### Phase 2: Coolify Service Configuration

#### Web Service Configuration

```yaml
Service Type: Docker Compose
Build Context: .
Dockerfile: Dockerfile
Target: web-production
Ports: 3000
Environment Variables:
  - NODE_ENV=production
  - VITE_USE_LOCAL_BACKEND=false
  - VITE_API_URL=${API_URL}
  - VITE_SUPABASE_URL=${SUPABASE_URL}
  - VITE_SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}
Health Check:
  Path: /health
  Interval: 30s
  Timeout: 10s
```

#### API Service Configuration

```yaml
Service Type: Docker Compose
Build Context:
Dockerfile: Dockerfile
Target: api-production
Ports: 3001
Environment Variables:
  - NODE_ENV=production
  - SUPABASE_URL=${SUPABASE_URL}
  - SUPABASE_SERVICE_ROLE_KEY=${SUPABASE_SERVICE_ROLE_KEY}
  - JWT_SECRET=${JWT_SECRET}
  - OPENROUTER_API_KEY=${OPENROUTER_API_KEY}
Health Check:
  Path: /health
  Interval: 30s
  Timeout: 10s
```

### Phase 3: Deployment Pipeline Setup

#### GitHub Actions Configuration

1. **Add Secrets to GitHub Repository:**
   - `COOLIFY_URL`: Your Coolify instance URL
   - `COOLIFY_API_TOKEN`: Coolify API token
   - `COOLIFY_SERVICE_ID`: Service ID from Coolify
   - `SLACK_WEBHOOK_URL`: Slack notifications (optional)

2. **Configure Workflow:**
   ```yaml
   # The .github/workflows/deploy.yml file handles:
   # - Testing and validation
   # - Multi-stage Docker builds
   # - Automated deployment to Coolify
   # - Health checks and rollback
   # - Slack notifications
   ```

### Phase 4: SSL/TLS Configuration

#### Automatic SSL with Traefik

```yaml
# Already configured in docker-compose.yml
certificatesresolvers:
  letsencrypt:
    acme:
      httpchallenge:
        entrypoint: web
      email: ${LETSENCRYPT_EMAIL}
      storage: /letsencrypt/acme.json
```

#### Custom SSL Certificates

1. **Upload Certificates** to Coolify
2. **Configure Traefik** to use custom certificates
3. **Update DNS** records to point to your server

### Phase 5: DNS Configuration

```bash
# Add A records for your domain
A yourdomain.com YOUR_SERVER_IP
A api.yourdomain.com YOUR_SERVER_IP
A www.yourdomain.com YOUR_SERVER_IP

# Optional: Add CNAME for subdomains
CNAME staging.yourdomain.com yourdomain.com
```

### Phase 6: Database Setup

#### Supabase Configuration

1. **Create Project** on Supabase dashboard
2. **Get Connection Details**:
   - Project URL
   - Service Role Key
   - Anonymous Key
3. **Configure Environment Variables** in Coolify
4. **Run Migrations** if needed

#### Local PostgreSQL

```bash
# For development with docker-compose
docker-compose --profile local-db up postgres
```

### Phase 7: Testing and Validation

#### Pre-deployment Testing

```bash
# Run all tests locally
npm test
npm run check
npm run lint

# Build applications
npm run build:runtime
cd apps/web && npm run build

# Test Docker builds
docker build -t decocms-test --target web-production .
docker build -t decocms-test --target api-production .
```

#### Post-deployment Validation

```bash
# Test health endpoints
curl https://yourdomain.com/health
curl https://api.yourdomain.com/health

# Test API connectivity
curl https://api.yourdomain.com/status

# Test SSL certificates
openssl s_client -connect yourdomain.com:443
```

## Monitoring and Maintenance

### Health Monitoring

#### Application Health Checks

```bash
# Web service health
curl -f https://yourdomain.com/health

# API service health
curl -f https://api.yourdomain.com/health

# Database connectivity
curl -f https://api.yourdomain.com/health/database
```

#### System Monitoring

1. **Coolify Dashboard**: Built-in service monitoring
2. **Traefik Dashboard**: `https://traefik.yourdomain.com`
3. **Container Logs**: Docker container monitoring
4. **Resource Usage**: CPU, memory, disk monitoring

### Log Management

#### Centralized Logging

```yaml
# Configure log rotation in docker-compose.yml
logging:
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"
```

#### Access Logs

```bash
# View application logs
docker-compose logs web
docker-compose logs api
docker-compose logs traefik

# Real-time log monitoring
docker-compose logs -f web
```

### Backup Strategy

#### Database Backups

**Supabase:**
- Automatic daily backups
- Point-in-time recovery
- Download backups for local storage

**Self-hosted PostgreSQL:**
```bash
# Create backup script
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
docker exec postgres pg_dump -U decocms decocms > backup_$DATE.sql
```

#### Application Backups

```bash
# Backup Docker volumes
docker run --rm -v decocms_postgres_data:/data -v $(pwd):/backup \
  alpine tar czf /backup/postgres_backup_$(date +%Y%m%d).tar.gz -C /data .
```

### Update Strategy

#### Zero-Downtime Updates

1. **Blue-Green Deployment**: Maintain two production environments
2. **Rolling Updates**: Update services one at a time
3. **Health Checks**: Ensure services are healthy before proceeding

#### Update Process

```bash
# 1. Update dependencies
npm update

# 2. Run tests
npm test

# 3. Build and push images
docker build -t your-registry/decocms:new-version .
docker push your-registry/decocms:new-version

# 4. Update Coolify environment
# Use Coolify UI to update image version

# 5. Monitor deployment
docker-compose logs -f
```

## Troubleshooting

### Common Issues

#### 1. Container Won't Start

**Symptoms:** Service shows as unhealthy or won't start
**Solutions:**
```bash
# Check container logs
docker-compose logs web
docker-compose logs api

# Inspect container
docker inspect decocms-web

# Check resource usage
docker stats

# Common fixes:
# - Increase memory limits
# - Check environment variables
# - Verify port availability
```

#### 2. Database Connection Issues

**Symptoms:** API can't connect to database
**Solutions:**
```bash
# Test database connectivity
docker exec -it postgres psql -U decocms -d decocms -c "SELECT 1;"

# Check network connectivity
docker network ls
docker network inspect decocms_app-network

# Common fixes:
# - Verify database URL
# - Check firewall rules
# - Confirm database is running
```

#### 3. SSL Certificate Issues

**Symptoms:** HTTPS not working, certificate errors
**Solutions:**
```bash
# Check Traefik logs
docker-compose logs traefik

# Test SSL configuration
openssl s_client -connect yourdomain.com:443

# Common fixes:
# - Verify DNS A records
# - Check LetsEncrypt rate limits
# - Confirm domain ownership
```

#### 4. Performance Issues

**Symptoms:** Slow response times, high resource usage
**Solutions:**
```bash
# Monitor resource usage
docker stats

# Check response times
curl -w "@curl-format.txt" https://yourdomain.com

# Profile Node.js application
docker exec -it api node --inspect=0.0.0.0:9229 dev.mjs

# Common optimizations:
# - Increase CPU/memory limits
# - Add Redis caching
# - Optimize database queries
# - Enable CDN
```

### Debugging Tools

#### Container Debugging

```bash
# Enter running container
docker exec -it web sh
docker exec -it api sh

# Run commands in container
docker exec web nginx -t
docker exec api node --version

# Network debugging
docker run --rm --network decocms_app-network \
  alpine ping web
```

#### Application Debugging

```bash
# Enable debug logging
LOG_LEVEL=debug docker-compose up api

# Use Node.js inspector
docker-compose -f docker-compose.debug.yml up
```

## Security Best Practices

### Container Security

1. **Use Non-Root Users**: All containers run as non-root users
2. **Minimal Images**: Alpine Linux based images
3. **Security Scanning**: Regular vulnerability scanning
4. **Resource Limits**: CPU and memory limits enforced

### Environment Security

1. **Secrets Management**: Use Coolify's built-in secret management
2. **Environment Variables**: Never commit secrets to Git
3. **Regular Rotation**: Rotate API keys and secrets regularly
4. **Access Control**: Limited access to production environments

### Network Security

1. **HTTPS Only**: Force HTTPS with proper redirects
2. **Firewall Rules**: Restrict access to necessary ports only
3. **VPN Access**: Use VPN for administrative access
4. **DDoS Protection**: Enable DDoS protection

### Application Security

1. **Input Validation**: Comprehensive input sanitization
2. **Rate Limiting**: API rate limiting implemented
3. **CORS Configuration**: Proper CORS headers
4. **Security Headers**: Security headers configured in Nginx

## Performance Optimization

### Frontend Optimization

1. **Asset Optimization**: Gzip compression and minification
2. **Caching Strategy**: Browser caching with proper headers
3. **CDN Integration**: Content delivery network for static assets
4. **PWA Support**: Service worker for offline functionality

### Backend Optimization

1. **Database Optimization**: Connection pooling and query optimization
2. **Caching Layer**: Redis for frequently accessed data
3. **Load Balancing**: Multiple API instances behind load balancer
4. **Resource Limits**: Appropriate CPU and memory allocation

### Monitoring Performance

1. **Response Time Monitoring**: Track API response times
2. **Error Rate Tracking**: Monitor application error rates
3. **Resource Usage**: Monitor CPU, memory, and disk usage
4. **User Experience**: Core Web Vitals monitoring

## Advanced Configuration

### Custom Nginx Configuration

```nginx
# Custom configuration can be mounted
server {
    # Custom security headers
    add_header Strict-Transport-Security "max-age=31536000";
    add_header Content-Security-Policy "default-src 'self'";

    # Custom routing rules
    location /admin/ {
        # Admin dashboard routing
    }

    # Custom error pages
    error_page 404 /404.html;
    error_page 500 502 503 504 /50x.html;
}
```

### Custom API Configuration

```javascript
// apps/api/src/config/production.ts
export const productionConfig = {
  rateLimit: {
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 100, // limit each IP to 100 requests per window
  },
  cors: {
    origin: process.env.CORS_ORIGIN,
    credentials: true,
  },
  security: {
    helmet: true,
    compression: true,
  },
};
```

### Multi-Region Deployment

```yaml
# Docker Compose for multiple regions
version: '3.8'
services:
  web-primary:
    # Primary region configuration

  web-secondary:
    # Secondary region configuration
    deploy:
      replicas: 2
      placement:
        constraints:
          - node.labels.region == secondary
```

## Conclusion

This deployment guide provides a comprehensive solution for deploying DecoCMS using Coolify with production-ready configurations, automated CI/CD pipelines, and robust monitoring.

### Key Benefits

- **Automated Deployment**: Push-to-deploy with GitHub Actions
- **Zero Downtime**: Rolling updates with health checks
- **Scalable Architecture**: Microservices with load balancing
- **Security First**: SSL/TLS, security headers, and best practices
- **Monitoring**: Comprehensive logging and health monitoring
- **Cost Effective**: Optimized resource usage and caching

### Next Steps

1. **Set Up Coolify**: Install and configure Coolify server
2. **Prepare Repository**: Add deployment configuration to your repository
3. **Configure Environment**: Set up environment variables and secrets
4. **Deploy**: Trigger first deployment and validate
5. **Monitor**: Set up monitoring and alerting
6. **Maintain**: Regular updates and security patches

For support and questions, refer to the [Coolify Documentation](https://coolify.io/docs) and [DecoCMS Repository](https://github.com/your-org/decocms).