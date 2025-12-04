# Local Development Setup for DecoCMS

This guide covers setting up a local development environment that mirrors the production Coolify deployment for consistent development experience.

## Quick Start

```bash
# Clone and setup
git clone <your-repository-url>
cd decocms
cp .env.example .env.local

# Start development environment
docker-compose -f docker-compose.yml -f docker-compose.override.yml up

# Or use npm for traditional development
npm install
npm run dev
```

## Prerequisites

- Node.js 24+
- Docker & Docker Compose
- Git
- Optional: Supabase CLI for local database

## Environment Setup

### 1. Configure Environment Variables

Create `.env.local` for local development:

```bash
# .env.local - Development environment
PROJECT_NAME=decocms
REGISTRY_URL=localhost:5000

# Local Development Ports
WEB_PORT=3000
API_PORT=3001
POSTGRES_PORT=5432
REDIS_PORT=6379

# Database Configuration
SUPABASE_URL=http://localhost:54321
SUPABASE_ANON_KEY=your-local-anon-key
DATABASE_URL=postgresql://postgres:postgres@localhost:54322/postgres

# API Configuration
JWT_SECRET=local-development-secret-key-32-chars
OPENROUTER_API_KEY=your-openrouter-api-key
CORS_ORIGIN=http://localhost:3000
LOG_LEVEL=debug

# Frontend Configuration
VITE_USE_LOCAL_BACKEND=true
VITE_API_URL=http://localhost:3001
VITE_SUPABASE_URL=http://localhost:54321
VITE_SUPABASE_ANON_KEY=your-local-anon-key

# Development Tools
NODE_ENV=development
LOG_LEVEL=debug
```

### 2. Development Tools Configuration

#### VS Code Configuration (`.vscode/settings.json`)

```json
{
  "editor.formatOnSave": true,
  "editor.codeActionsOnSave": {
    "source.fixAll.eslint": "explicit",
    "source.fixAll.stylelint": "explicit"
  },
  "typescript.preferences.importModuleSpecifier": "relative",
  "eslint.workingDirectories": ["apps/*", "packages/*"],
  "files.exclude": {
    "**/node_modules": true,
    "**/dist": true
  },
  "search.exclude": {
    "**/node_modules": true,
    "**/dist": true
  }
}
```

#### VS Code Extensions (`.vscode/extensions.json`)

```json
{
  "recommendations": [
    "esbenp.prettier-vscode",
    "dbaeumer.vscode-eslint",
    "ms-vscode.vscode-typescript-next",
    "bradlc.vscode-tailwindcss",
    "ms-vscode.vscode-json",
    "formulahendry.auto-rename-tag",
    "christian-kohler.path-intellisense"
  ]
}
```

## Development Workflows

### Option 1: Docker Development (Recommended)

Matches production environment:

```bash
# Start all services including database
docker-compose -f docker-compose.yml -f docker-compose.override.yml up

# Start without database (if using external Supabase)
docker-compose -f docker-compose.yml -f docker-compose.override.yml up web api

# Start with development tools
docker-compose -f docker-compose.yml -f docker-compose.override.yml --profile tools up

# View logs
docker-compose logs -f web
docker-compose logs -f api

# Stop services
docker-compose down
```

### Option 2: Native Node.js Development

For faster iteration during frontend development:

```bash
# Install dependencies
npm install

# Start both web and API
npm run dev

# Start only web (with external API)
cd apps/web && npm run dev

# Start only API
cd apps/api && npm run dev
```

### Option 3: Hybrid Development

Use Docker for database, native for application:

```bash
# Start only database services
docker-compose --profile local-db up postgres redis

# In another terminal, start applications natively
npm run dev
```

## Service Access URLs

### Local Environment

- **Web Application**: http://localhost:3000
- **API Service**: http://localhost:3001
- **Traefik Dashboard**: http://localhost:8080
- **API Documentation**: http://localhost:3001/docs

### Development Tools

- **Dev Tools Container**: Access via `docker exec -it decocms-dev-tools sh`
- **Database**: `localhost:5432` (PostgreSQL), `localhost:6379` (Redis)

## Database Setup

### Option 1: Supabase CLI (Recommended)

```bash
# Install Supabase CLI
npm install -g @supabase/cli

# Initialize local project
supabase init

# Start local services
supabase start

# Generate types
supabase gen types typescript --local > packages/sdk/src/storage/supabase/schema.ts
```

### Option 2: Docker PostgreSQL

```bash
# Start PostgreSQL container
docker-compose --profile local-db up postgres

# Access database
docker exec -it decocms-postgres psql -U decocms -d decocms

# Run migrations
supabase db push
```

### Database Operations

```bash
# Reset database
supabase db reset

# Run migrations
supabase db push

# View logs
supabase logs db

# Access database
supabase db shell
```

## Development Tasks

### Code Quality

```bash
# Lint code
npm run lint

# Type checking
npm run check

# Format code
npm run fmt

# Run tests
npm run test

# Watch tests
npm run test:watch
```

### Build and Preview

```bash
# Build for production preview
npm run build
npm run preview

# Build specific apps
cd apps/web && npm run build
cd apps/api && npm run build
```

### Package Development

```bash
# Build runtime package
npm run build:runtime

# Add UI components
npm run ui add button
npm run ui add card

# Check for unused dependencies
npm run knip
```

## Hot Reloading

### Frontend Hot Reload

The Vite development server provides instant hot reload:

```bash
# Apps with hot reload
cd apps/web
npm run dev -- --host 0.0.0.0
```

### API Development

For API changes during development:

```bash
# API with file watching
cd apps/api
npm run dev

# Or with nodemon for auto-restart
npm install -g nodemon
cd apps/api
nodemon dev.mjs
```

### Docker Development with Volumes

The Docker Compose override mounts source code for live reload:

```yaml
volumes:
  - ./apps/web:/app/apps/web
  - ./packages:/app/packages
  - /app/apps/web/node_modules  # Preserve node_modules
```

## Debugging

### Frontend Debugging

1. **Browser DevTools**: Standard Chrome/Firefox dev tools
2. **React DevTools**: Install browser extension
3. **Network Tab**: Monitor API calls and responses

### API Debugging

```bash
# Debug with Node.js inspector
cd apps/api
node --inspect=0.0.0.0:9229 dev.mjs

# Or use VS Code launch configuration
```

VS Code launch configuration (`.vscode/launch.json`):

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Debug API",
      "type": "node",
      "request": "launch",
      "program": "${workspaceFolder}/apps/api/dev.mjs",
      "env": {
        "NODE_ENV": "development"
      },
      "console": "integratedTerminal",
      "runtimeArgs": ["--inspect=0.0.0.0:9229"]
    }
  ]
}
```

### Database Debugging

```bash
# Connect to PostgreSQL
docker exec -it decocms-postgres psql -U decocms

# View tables
\dt

# View database logs
docker logs decocms-postgres

# Database connection test
npm run db:test
```

## Testing

### Unit Tests

```bash
# Run all tests
npm run test

# Run tests in watch mode
npm run test:watch

# Run tests with coverage
npm run test -- --coverage

# Run tests for specific package
cd packages/sdk && npm test
```

### Integration Tests

```bash
# Run API integration tests
cd apps/api && npm run test:integration

# Run E2E tests (if configured)
npm run test:e2e
```

### Manual Testing

```bash
# Start test environment
npm run test:env

# Run manual test scripts
npm run test:api
npm run test:web
```

## Performance Monitoring

### Local Performance Tools

```bash
# Lighthouse CLI
npm install -g lighthouse
lighthouse http://localhost:3000 --view

# WebPageTest
docker run --rm -it webpagetest/server http://localhost:3000

# Bundle analyzer
cd apps/web && npm run build:analyze
```

### API Performance

```bash
# Test API response times
curl -w "@curl-format.txt" http://localhost:3001/api/health

# Load testing with artillery
npm install -g artillery
artillery run load-test.yml
```

## Environment Switching

### Switch Between Environments

```bash
# Development (default)
NODE_ENV=development npm run dev

# Staging
NODE_ENV=staging npm run dev

# Production preview
NODE_ENV=production npm run build && npm run preview
```

### Environment-Specific Configurations

```javascript
// apps/api/src/config/index.ts
const config = {
  development: {
    database: process.env.DATABASE_URL_LOCAL,
    logLevel: 'debug',
    cors: { origin: 'http://localhost:3000' }
  },
  staging: {
    database: process.env.DATABASE_URL_STAGING,
    logLevel: 'info',
    cors: { origin: 'https://staging.yourdomain.com' }
  },
  production: {
    database: process.env.DATABASE_URL,
    logLevel: 'warn',
    cors: { origin: 'https://yourdomain.com' }
  }
};

export default config[process.env.NODE_ENV || 'development'];
```

## Pre-deployment Checklist

Before pushing changes to trigger deployment:

### Code Quality

```bash
# Ensure all checks pass
npm run lint
npm run check
npm run test
npm run build
```

### Environment Validation

```bash
# Test with production environment variables
NODE_ENV=production npm run build

# Validate environment variables
npm run env:validate
```

### Manual Testing

```bash
# Test core functionality
npm run test:manual

# Test API endpoints
curl http://localhost:3001/health
curl http://localhost:3000

# Test database connectivity
npm run db:check
```

## Troubleshooting

### Common Development Issues

#### Port Conflicts

```bash
# Check what's using ports
lsof -i :3000
lsof -i :3001
lsof -i :5432

# Change ports in .env.local
WEB_PORT=3002
API_PORT=3003
```

#### Dependency Issues

```bash
# Clear all node_modules
npm run clean

# Install fresh dependencies
npm install

# Rebuild packages
npm run build:runtime
```

#### Docker Issues

```bash
# Clean Docker
docker-compose down -v
docker system prune -f
docker volume prune -f

# Rebuild images
docker-compose build --no-cache
```

#### Database Issues

```bash
# Reset database
supabase db reset

# Clear migrations
supabase migration repair --status reverted
supabase migration up
```

### Performance Issues

#### Slow Hot Reload

```bash
# Exclude large directories from watcher
# In .gitignore:
node_modules
dist
build
coverage

# Use faster file watchers
npm install --save-dev chokidar
```

#### Memory Issues

```bash
# Increase Node.js memory limit
NODE_OPTIONS="--max-old-space-size=4096" npm run dev

# Monitor memory usage
npm run monitor:memory
```

## Useful Scripts

Add to `package.json`:

```json
{
  "scripts": {
    "dev:docker": "docker-compose -f docker-compose.yml -f docker-compose.override.yml up",
    "dev:native": "npm run dev",
    "dev:clean": "docker-compose down -v && npm run clean",
    "test:all": "npm run lint && npm run check && npm run test && npm run build",
    "db:reset": "supabase db reset",
    "db:types": "supabase gen types typescript --local > packages/sdk/src/storage/supabase/schema.ts",
    "preview:prod": "NODE_ENV=production npm run build && npm run preview",
    "lint:fix": "npm run lint -- --fix && npm run fmt"
  }
}
```

## Next Steps

After setting up local development:

1. **Create a feature branch** for your changes
2. **Make your changes** with regular testing
3. **Run the pre-deployment checklist**
4. **Push to trigger deployment**
5. **Monitor deployment** in Coolify dashboard
6. **Test in staging/production** environment

This local development setup ensures consistency with the production Coolify deployment while providing fast iteration and debugging capabilities.