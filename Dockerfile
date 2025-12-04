# Multi-stage Dockerfile for DecoCMS monorepo deployment on Coolify
# Optimized for production with Node.js 24+ and workspace dependencies

# =================================================================
# Base stage - Set up common dependencies and build environment
# =================================================================
FROM node:24-alpine AS base
RUN apk add --no-cache libc6-compat
WORKDIR /app

# Copy package files for workspace setup
COPY package.json bun.lockb* package-lock.json* pnpm-lock.yaml* ./
COPY apps/web/package.json ./apps/web/
COPY apps/api/package.json ./apps/api/
COPY packages/*/package.json ./packages/*/

# Install dependencies based on available lock file
RUN \
  if [ -f "bun.lockb" ]; then \
    corepack enable bun && bun install --frozen-lockfile; \
  elif [ -f "pnpm-lock.yaml" ]; then \
    corepack enable pnpm && pnpm install --frozen-lockfile; \
  elif [ -f "package-lock.json" ]; then \
    npm ci; \
  else \
    echo "No lock file found, installing dependencies" && npm install; \
  fi

# =================================================================
# Web App Build Stage - React/Vite frontend with PWA
# =================================================================
FROM base AS web-build
WORKDIR /app

# Copy source files
COPY apps/web/ ./apps/web/
COPY packages/ ./packages/

# Build web application
WORKDIR /app/apps/web
RUN npm run build

# =================================================================
# API Build Stage - Hono backend for production
# =================================================================
FROM base AS api-build
WORKDIR /app

# Copy source files
COPY apps/api/ ./apps/api/
COPY packages/ ./packages/

# Prepare production dependencies (if any build steps needed)
WORKDIR /app/apps/api

# =================================================================
# Production Web Stage - Serve static files with nginx
# =================================================================
FROM nginx:alpine AS web-production

# Install necessary tools
RUN apk add --no-cache curl

# Copy built web app
COPY --from=web-build /app/apps/web/dist /usr/share/nginx/html

# Copy nginx configuration for SPA and PWA
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
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/javascript
        application/xml+rss
        application/json;

    server {
        listen 3000;
        server_name localhost;
        root /usr/share/nginx/html;
        index index.html;

        # Security headers
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header Referrer-Policy "strict-origin-when-cross-origin" always;

        # PWA caching headers
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }

        # API proxy to backend service
        location /api/ {
            proxy_pass http://api:3001/;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_cache_bypass \$http_upgrade;
        }

        # SPA fallback
        location / {
            try_files \$uri \$uri/ /index.html;
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
# Health check for nginx
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

# Install necessary runtime packages
RUN apk add --no-cache curl

# Copy built application and dependencies
WORKDIR /app

# Copy only production dependencies
COPY package.json bun.lockb* package-lock.json* pnpm-lock.yaml* ./
COPY apps/api/package.json ./apps/api/
COPY packages/*/package.json ./packages/*/

RUN \
  if [ -f "bun.lockb" ]; then \
    corepack enable bun && bun install --frozen-lockfile --production; \
  elif [ -f "pnpm-lock.yaml" ]; then \
    corepack enable pnpm && pnpm install --frozen-lockfile --prod; \
  elif [ -f "package-lock.json" ]; then \
    npm ci --only=production; \
  else \
    echo "No lock file found, installing production dependencies" && npm install --production; \
  fi

# Copy application source
COPY apps/api/ ./apps/api/
COPY packages/ ./packages/

# Create non-root user for security
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Change ownership to nodejs user
RUN chown -R nodejs:nodejs /app
USER nodejs

WORKDIR /app/apps/api

# Health check script
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
    console.log('Health check failed with status:', res.statusCode);
    process.exit(1);
  }
});

req.on('error', (err) => {
  console.log('Health check failed:', err.message);
  process.exit(1);
});

req.on('timeout', () => {
  console.log('Health check timeout');
  req.destroy();
  process.exit(1);
});

req.end();
EOF

# Startup script with health check
COPY <<EOF /app/start.sh
#!/bin/sh
set -e

echo "Starting DecoCMS API server..."

# Wait for database connection if needed
if [ -n "\$SUPABASE_URL" ]; then
    echo "Supabase URL configured: \$SUPABASE_URL"
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