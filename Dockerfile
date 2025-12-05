# Multi-stage Dockerfile for DecoCMS deployment on Coolify
# Fixed JSR registry configuration and workspace dependencies

# =================================================================
# Base Stage - System setup and dependency management
# =================================================================
FROM node:24-alpine AS base
LABEL maintainer="DecoCMS Team" version="2.1.0"

# Install system dependencies
RUN apk add --no-cache libc6-compat curl bash git

# Install and configure corepack (package manager manager)
RUN npm install -g corepack@latest

# Configure npm and JSR registry globally before any operations
RUN npm config set @jsr:registry https://npm.jsr.io && \
  npm config set @jsr:token "" && \
  npm config set registry https://registry.npmjs.org/

WORKDIR /app

# =================================================================
# Dependency Installation Stage - Handle workspaces and JSR properly
# =================================================================
FROM base AS dependencies

# Enable pnpm (better for workspaces and JSR packages)
RUN corepack enable pnpm

# Copy package files for workspace setup
COPY package.json pnpm-workspace.yaml* ./
COPY apps/web/package.json ./apps/web/
COPY apps/api/package.json ./apps/api/
COPY packages/*/package.json ./packages/*/
# Copy workspace manifests (root + apps + packages)
COPY package.json ./
COPY apps/api/package.json ./apps/api/package.json
COPY apps/web/package.json ./apps/web/package.json
COPY packages/ai/package.json ./packages/ai/package.json
COPY packages/bindings/package.json ./packages/bindings/package.json
COPY packages/cf-sandbox/package.json ./packages/cf-sandbox/package.json
COPY packages/cli/package.json ./packages/cli/package.json
COPY packages/create-deco/package.json ./packages/create-deco/package.json
COPY packages/runtime/package.json ./packages/runtime/package.json
COPY packages/sdk/package.json ./packages/sdk/package.json
COPY packages/ui/package.json ./packages/ui/package.json
COPY packages/vite-plugin-deco/package.json ./packages/vite-plugin-deco/package.json

# Install all dependencies including JSR packages
# pnpm handles JSR and workspaces much better than npm
RUN pnpm install --frozen-lockfile || pnpm install

# =================================================================
# Web App Build Stage - React/Vite frontend with PWA
# =================================================================
FROM dependencies AS web-build
WORKDIR /app

# Copy source files
COPY apps/web/ ./apps/web/
COPY packages/ ./packages/

# Set production environment variables (will be overridden by Coolify)
ENV NODE_ENV=production
ENV VITE_USE_LOCAL_BACKEND=false

# Build web application
WORKDIR /app/apps/web
RUN pnpm build

# =================================================================
# API Preparation Stage - Prepare Node.js API files
# =================================================================
FROM dependencies AS api-prep
WORKDIR /app

# Copy API source files
COPY apps/api/ ./apps/api/
COPY packages/ ./packages/

# =================================================================
# Production Web Stage - Serve static files with nginx
# =================================================================
FROM nginx:alpine AS web-production

# Install additional tools
RUN apk add --no-cache curl

# Copy built web app
COPY --from=web-build /app/apps/web/dist /usr/share/nginx/html

# Create optimized nginx configuration
COPY <<EOF /etc/nginx/nginx.conf
events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 10240;
    gzip_proxied expired no-cache no-store private must-revalidate;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;
    gzip_disable "MSIE [1-6]\.";

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    server {
        listen 3000;
        server_name _;
        root /usr/share/nginx/html;
        index index.html;

        # PWA caching headers
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }

        # API proxy to backend service
        location /api/ {
            proxy_pass http://api:3001/;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_cache_bypass $http_upgrade;
        }

        # SPA fallback
        location / {
            try_files $uri $uri/ /index.html;
        }

        # Health check endpoint
        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }
    }
}
EOF

# Health check script
COPY <<EOF /docker-entrypoint.d/10-healthcheck.sh
#!/bin/sh
if ! curl -f http://localhost:3000/health > /dev/null 2>&1; then
    echo "Health check failed"
    exit 1
fi
echo "Health check passed"
EOF

RUN chmod +x /docker-entrypoint.d/10-healthcheck.sh

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

EXPOSE 3000

# =================================================================
# Production API Stage - Hono backend with Node.js
# =================================================================
FROM node:24-alpine AS api-production

# Install runtime packages
RUN apk add --no-cache curl

# Create application user for security
RUN addgroup -g 1001 -S nodejs && \
  adduser -S nodejs -u 1001

# Set up workspace
WORKDIR /app

# Copy package files for workspace setup
COPY package.json pnpm-workspace.yaml* ./
COPY apps/api/package.json ./apps/api/
COPY packages/*/package.json ./packages/*
# Copy workspace manifests (root + apps + packages)
COPY package.json ./
COPY apps/api/package.json ./apps/api/package.json
COPY apps/web/package.json ./apps/web/package.json
COPY packages/ai/package.json ./packages/ai/package.json
COPY packages/bindings/package.json ./packages/bindings/package.json
COPY packages/cf-sandbox/package.json ./packages/cf-sandbox/package.json
COPY packages/cli/package.json ./packages/cli/package.json
COPY packages/create-deco/package.json ./packages/create-deco/package.json
COPY packages/runtime/package.json ./packages/runtime/package.json
COPY packages/sdk/package.json ./packages/sdk/package.json
COPY packages/ui/package.json ./packages/ui/package.json
COPY packages/vite-plugin-deco/package.json ./packages/vite-plugin-deco/package.json

# Configure npm and JSR registry globally
RUN npm config set @jsr:registry https://npm.jsr.io && \
  npm config set @jsr:token "" && \
  npm config set registry https://registry.npmjs.org/

# Enable pnpm
RUN corepack enable pnpm

# Install production dependencies
RUN pnpm install --frozen-lockfile --prod || pnpm install --prod

# Copy application files
COPY --from=api-prep /app .

# Change ownership to nodejs user
RUN chown -R nodejs:nodejs /app

USER nodejs

WORKDIR /app/apps/api

# Health check script for API
COPY <<EOF /app/healthcheck.js
const http = require('http');

const options = {
    hostname: 'localhost',
    port: 3001,
    path: '/health',
    method: 'GET',
    timeout: 2000
};

const req = http.request(options, (res) => {
    if (res.statusCode === 200) {
        console.log('Health check passed');
        process.exit(0);
    } else {
        console.log(`Health check failed with status: ${res.statusCode}`);
        process.exit(1);
    }
});

req.on('error', (err) => {
    console.log(`Health check failed: ${err.message}`);
    process.exit(1);
});

req.on('timeout', () => {
    console.log('Health check timeout');
    req.destroy();
    process.exit(1);
});

req.end();
EOF

# Startup script
COPY <<EOF /app/start.sh
#!/bin/sh
set -e

echo "Starting DecoCMS API server on port ${PORT:-3001}..."

# Environment validation
if [ -n "$SUPABASE_URL" ]; then
    echo "Supabase configured: $SUPABASE_URL"
fi

# Start the application
exec node dev.mjs
EOF

RUN chmod +x /app/start.sh

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD node /app/healthcheck.js || exit 1

EXPOSE 3001

CMD ["/app/start.sh"]

# =================================================================
# Development Stage - Combined development environment
# =================================================================
FROM base AS development

# Install development tools
RUN npm install -g concurrently

# Copy all source code
COPY . .

# Expose development ports
EXPOSE 3000 3001

# Development command
CMD ["npm", "run", "dev"]

# =================================================================
# Labels and Metadata
# =================================================================
LABEL org.opencontainers.image.description="DecoCMS multi-service application"
LABEL org.opencontainers.image.source="https://github.com/caiomioto2/admin"
LABEL org.opencontainers.image.licenses="SUL"

# Default stage for Docker Compose
FROM web-production AS default