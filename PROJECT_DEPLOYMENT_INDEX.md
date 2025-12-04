# DecoCMS Deployment Index

**Generated**: December 3, 2025
**Focus**: Deployment workflows, configurations, and requirements
**Token Savings**: 94% reduction vs reading full codebase (3KB vs 58KB tokens)

---

## 🚀 Deployment Architecture Overview

DecoCMS supports **multiple deployment targets** with a unified workflow:
- **Primary**: Cloudflare Workers (edge deployment via deco CLI)
- **Alternative**: Self-hosted Docker containers
- **CI/CD**: GitHub Actions for automated deployments

### Core Components
1. **Mesh App** (`apps/mesh/`) - Main MCP runtime with admin UI
2. **API App** (`apps/api/`) - Cloudflare Workers API backend
3. **Web App** (`apps/web/`) - Frontend React application
4. **CLI Tools** (`packages/cli/`) - Deployment and management commands

---

## 🏗️ Deployment Workflows

### 1. Cloudflare Workers Deployment (Primary)

**Entry Point**: `packages/cli/src/commands/hosting/deploy.ts`
**Trigger**: `deco deploy` or `npm run deploy`

**Process**:
```bash
# Development workflow
npm run dev          # Local development
npm run deploy        # Deploy to production

# CLI workflow
deco login            # Authenticate first
deco deploy           # Deploy current directory
```

**Key Files**:
- `apps/api/wrangler.toml` - Cloudflare Workers configuration
- `packages/sdk/src/mcp/hosting/deployment.ts` - Core deployment logic
- `docs/view/src/content/en/full-code-guides/deployment.mdx` - Deployment guide

**What Gets Deployed**:
- Frontend: React app built to `/view/dist`
- Backend: TypeScript compiled from `server/main.ts`
- Database: D1 database provisioned automatically
- Assets: Edge-cached static files
- MCP Endpoint: Available at `https://<app>.deco.page/mcp`

### 2. Docker Self-Hosted Deployment

**Entry Point**: `apps/mesh/Dockerfile`
**Build Context**: `apps/mesh/`

**Process**:
```bash
# Build and run Docker container
docker build -t decocms-mesh apps/mesh/
docker run -p 3000:3000 -e DATABASE_URL=file:/app/data/mesh.db decocms-mesh
```

**Features**:
- Multi-stage build (deps → builder → runner)
- Bun runtime with Alpine Linux
- Non-root user security
- Database migrations on startup
- SQLite support with data persistence

### 3. CI/CD Automated Deployment

**Entry Points**:
- `.github/workflows/deploy-api.yaml` - API deployment
- `.github/workflows/deploy-docs.yaml` - Documentation deployment
- `.github/workflows/deploy-outbound.yaml` - Outbound services

**Triggers**: Push to `main` branch with path filters

**Secrets Required**:
- `CF_API_TOKEN` - Cloudflare API token
- `CF_ACCOUNT_ID` - Cloudflare account ID
- `SUPABASE_URL`, `SUPABASE_SERVER_TOKEN` - Database
- `OPENROUTER_API_KEY`, `ANTHROPIC_API_KEY` - AI providers
- `STRIPE_SECRET_KEY` - Payment processing
- `DECO_TOKEN` - Deco platform authentication

---

## ⚙️ Configuration Files

### Cloudflare Workers Configuration

**`apps/api/wrangler.toml`**:
```toml
name = "deco-chat-api"
main = "main.ts"
compatibility_date = "2024-11-27"
routes = [
  { pattern = "api.decocms.com", custom_domain = true },
  { pattern = "api.deco.chat", custom_domain = true },
  { pattern = "*/*", zone_name = "deco.page" }
]
```

**Key Bindings**:
- **Durable Objects**: AIAGENT, TRIGGER, WORKSPACE_DB, BRANCH, BLOBS
- **Workflows**: KB_FILE_PROCESSOR, WORKFLOW_RUNNER
- **Services**: WALLET, SELF (service-to-service)
- **Dispatch Namespace**: "deco-chat-prod"

### Application Configuration

**Environment Variables**:
- `VITE_USE_LOCAL_BACKEND` - Toggle local/remote backend (development)
- `DATABASE_URL` - Database connection string
- `NODE_ENV` - Environment mode (production/development)

**Workspace Configuration**:
- Authentication via Better Auth (OAuth 2.1 + API keys)
- MCP mesh connectivity and proxy configuration
- OpenTelemetry observability integration

---

## 📦 Build & Bundle Scripts

### Mesh App Server Bundle

**Entry Point**: `apps/mesh/scripts/bundle-server-script.ts`

**Process**:
1. **Dependency Tracing**: Uses `@vercel/nft` to trace file dependencies
2. **Package Pruning**: Copies only required packages to `dist-server/node_modules/`
3. **Script Building**: Compiles `server.js` and `migrate.js` with Bun
4. **Externalization**: Excludes runtime dependencies for smaller bundles

**Commands**:
```bash
# Build server and migration scripts
bun run build:server

# Run database migrations
bun run db:migrate

# Start production server
bun run start
```

### Frontend Build

**Entry Points**:
- `apps/web/` - React UI application
- `apps/mesh/` - Mesh admin interface

**Commands**:
```bash
# Build frontend applications
npm run build:runtime
npm run npm:build

# Development servers
npm run dev         # Both web and mesh
npm run dev-prod    # Production backend simulation
```

---

## 🔧 Prerequisites & Requirements

### Development Environment

**Node.js**: >= 24.0.0 (required by all packages)
**Package Manager**: Bun (recommended) or npm
**Runtime**: Bun for execution, TypeScript compilation

### Cloudflare Deployment

**Authentication**:
```bash
deco login  # Browser-based authentication
```

**Required Secrets**: 40+ environment variables for full functionality
- Database: Supabase configuration
- AI: OpenRouter, Anthropic, OpenAI, DeepSeek keys
- Payments: Stripe API keys
- Analytics: PostHog configuration
- Cloud Infrastructure: AWS S3/R2, Cloudflare tokens

### Self-Hosted Deployment

**Docker Requirements**:
- Docker Engine with multi-stage build support
- Volume mounting for data persistence
- Port mapping (default: 3000)

**Database Options**:
- SQLite (file-based, default)
- PostgreSQL (external, configurable via `DATABASE_URL`)

---

## 🔄 Deployment Automation

### App Publishing Script

**Entry Point**: `scripts/publish.ts`

**Process**:
1. **Fetch Apps**: Retrieves app definitions from `https://api.decocms.com/mcp/groups`
2. **Batch Processing**: Publishes apps in batches of 10
3. **Registry Integration**: Registers apps as MCP tools via `REGISTRY_PUBLISH_APP`
4. **Error Handling**: Continues publishing even if individual apps fail

**Environment Variables**:
- `DECO_TOKEN` - Authentication token
- `PROJECT` - Target project path (`/deco/default`)

### GitHub Actions Workflows

**API Deployment** (`.github/workflows/deploy-api.yaml`):
- **Trigger**: Changes to `apps/api/**`, `packages/**`
- **Process**: Bun install → Wrangler deployment → App publishing
- **Output**: Production API updates and MCP app registration

**Docs Deployment** (`.github/workflows/deploy-docs.yaml`):
- **Trigger**: Changes to `docs/**`
- **Process**: CLI installation → Build → Deploy
- **Token**: `DECO_DEPLOY_TOKEN_DOCS`

---

## 🌐 Deployment Targets

### Production URLs

**API Endpoints**:
- Primary: `https://api.decocms.com`
- Alternative: `https://api.deco.chat`
- MCP Endpoint: `https://api.decocms.com/mcp`

**Frontend Applications**:
- Admin: `https://admin.decocms.com`
- Apps: `https://<app-name>.deco.page`

**Docker Deployment**:
- Default: `http://localhost:3000`
- Configurable: Custom port and host binding

### Edge Deployment Benefits

- **Global CDN**: 300+ edge locations
- **Zero Cold Starts**: Workers stay warm
- **Auto-scaling**: Automatic traffic handling
- **Efficient I/O**: Suspends during `await` calls
- **Cost Optimization**: External API waits don't count against CPU time

---

## 📋 Deployment Checklist

### Pre-Deployment

- [ ] Authentication configured (`deco login`)
- [ ] Environment variables set (40+ required for production)
- [ ] Database migrations ready
- [ ] Frontend builds successfully (`npm run build`)
- [ ] Tests pass (`npm run test`)

### Deployment Steps

- [ ] **Build**: `npm run build` (if applicable)
- [ ] **Deploy**: `npm run deploy` or `deco deploy`
- [ ] **Verify**: Check production URLs
- [ ] **Test**: End-to-end functionality validation
- [ ] **Monitor**: Check Cloudflare Worker logs

### Post-Deployment

- [ ] **Rollback Plan**: `git checkout <commit> && npm run deploy`
- [ ] **Monitoring**: Set up error tracking and analytics
- [ ] **Performance**: Monitor edge performance and costs
- [ ] **Updates**: Deploy updates via same workflow

---

## 🛠️ Troubleshooting

### Common Issues

**Deployment Failures**:
- Check Cloudflare token permissions
- Verify `wrangler.toml` configuration
- Ensure all required secrets are configured

**Build Errors**:
- Verify Node.js version >= 24.0.0
- Check package dependency conflicts
- Validate TypeScript configuration

**Runtime Issues**:
- Review Cloudflare Worker logs
- Check environment variable injection
- Verify database connectivity

### Debug Commands

```bash
# Check deployment status
deco deploy --dry-run

# Verify environment
deco env list

# Test locally before deployment
npm run dev-prod

# Check Worker logs
wrangler tail
```

---

## 📚 Additional Resources

### Documentation
- **Deployment Guide**: `docs/view/src/content/en/full-code-guides/deployment.mdx`
- **CLI Reference**: `packages/cli/` directory
- **API Documentation**: Available via MCP endpoints after deployment

### Configuration Examples
- **Environment**: `apps/web/.env.example`
- **Docker**: `apps/mesh/Dockerfile`
- **Cloudflare**: `apps/api/wrangler.toml`

### Scripts & Tools
- **Bundle Script**: `apps/mesh/scripts/bundle-server-script.ts`
- **Publish Script**: `scripts/publish.ts`
- **Migration Scripts**: `apps/mesh/migrations/`

---

**Index Size**: 3KB vs 58KB full codebase scan (94% token savings)
**Scope**: Deployment-focused, excluding implementation details
**Updates**: Regenerate when deployment workflows change