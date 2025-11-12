# 🔧 Guia de Configuração de Variáveis de Ambiente

Este guia explica todas as variáveis de ambiente usadas no DecoCMS e como configurá-las.

---

## 📋 Índice

1. [Setup Rápido](#setup-rápido)
2. [Variáveis Obrigatórias](#variáveis-obrigatórias)
3. [Variáveis Opcionais](#variáveis-opcionais)
4. [Ambientes Diferentes](#ambientes-diferentes)
5. [Segurança](#segurança)
6. [Troubleshooting](#troubleshooting)

---

## Setup Rápido

### Para Desenvolvimento Local

```bash
# 1. Copie o exemplo
cp .env.local.example .env

# 2. Gere uma chave de criptografia
echo "ENCRYPTION_KEY=$(openssl rand -base64 32)" >> .env

# 3. Pronto! Agora pode rodar:
cd apps/mesh
bun run dev
```

### Para Produção

```bash
# 1. Copie o exemplo de produção
cp .env.production.example .env

# 2. Gere chaves seguras
echo "ENCRYPTION_KEY=$(openssl rand -base64 32)" >> .env
echo "BETTER_AUTH_SECRET=$(openssl rand -hex 32)" >> .env

# 3. Edite o arquivo e preencha:
nano .env
```

---

## Variáveis Obrigatórias

### 🔧 `PORT`
- **Padrão:** `3000`
- **Descrição:** Porta onde o servidor mesh vai rodar
- **Exemplo:** `PORT=3000`

### 🌐 `BASE_URL`
- **Obrigatório em produção**
- **Descrição:** URL completa do seu servidor (com protocolo)
- **Desenvolvimento:** `http://localhost:3000`
- **Produção:** `https://seu-dominio.com`

### 💾 `DATABASE_URL`
- **Obrigatório**
- **Descrição:** String de conexão do banco de dados

**Opções:**

```bash
# SQLite (desenvolvimento)
DATABASE_URL=file:./data/mesh.db

# PostgreSQL (produção)
DATABASE_URL=postgresql://usuario:senha@localhost:5432/decocms

# Supabase
DATABASE_URL=postgresql://postgres:senha@db.projeto.supabase.co:5432/postgres
```

### 🔐 `ENCRYPTION_KEY`
- **Obrigatório**
- **Descrição:** Chave de 32 bytes para criptografar credenciais no vault
- **Como gerar:** `openssl rand -base64 32`
- **Importante:** Não perca essa chave! Sem ela você não consegue decriptar os dados.

---

## Variáveis Opcionais

### Autenticação

#### `BETTER_AUTH_SECRET`
- **Descrição:** Secret para assinar JWT tokens
- **Como gerar:** `openssl rand -hex 32`
- **Quando usar:** Sempre em produção

#### `BETTER_AUTH_URL`
- **Descrição:** URL base do Better Auth (geralmente igual ao `BASE_URL`)
- **Padrão:** Usa `BASE_URL` se não definido

---

### Supabase

#### `SUPABASE_URL`
- **Padrão:** `https://auth.deco.cx`
- **Descrição:** URL da API Supabase
- **Exemplo:** `https://seu-projeto.supabase.co`

#### `SUPABASE_SERVER_TOKEN`
- **Descrição:** Service role key do Supabase
- **Onde encontrar:** Dashboard do Supabase > Project Settings > API
- **Importante:** Use o `service_role` key, não o `anon` key

#### `SUPABASE_SERVICE_ROLE_KEY`
- **Descrição:** Alias para operações admin (geralmente igual ao `SUPABASE_SERVER_TOKEN`)

---

### Stripe (Pagamentos)

#### `STRIPE_SECRET_KEY`
- **Descrição:** Chave secreta da API Stripe
- **Onde encontrar:** Dashboard Stripe > Developers > API keys
- **Desenvolvimento:** Use `sk_test_...`
- **Produção:** Use `sk_live_...`

#### `STRIPE_WEBHOOK_SECRET`
- **Descrição:** Secret para validar webhooks do Stripe
- **Onde encontrar:** Dashboard Stripe > Developers > Webhooks
- **Formato:** `whsec_...`

---

### Email (Resend)

#### `RESEND_API_KEY`
- **Descrição:** API key do Resend para envio de emails
- **Onde obter:** [resend.com](https://resend.com)
- **Formato:** `re_...`
- **Usado para:** Convites de equipe, notificações

---

### Provedores de IA

#### `OPENAI_API_KEY`
- **Descrição:** API key da OpenAI
- **Usado para:** Embeddings (knowledge base), chat
- **Formato:** `sk-proj-...` ou `sk-...`

#### `ANTHROPIC_API_KEY`
- **Descrição:** API key da Anthropic (Claude)
- **Formato:** `sk-ant-...`

#### `GOOGLE_API_KEY`
- **Descrição:** API key do Google (Gemini)

#### `GROK_API_KEY`
- **Descrição:** API key do Grok

---

### Observabilidade

#### `OTEL_EXPORTER_OTLP_ENDPOINT`
- **Descrição:** Endpoint para exportar traces OpenTelemetry
- **Padrão:** `http://localhost:4318`
- **Formato:** URL completa sem path
- **Exemplos:**
  - Local: `http://localhost:4318`
  - Datadog: `https://trace.agent.datadoghq.com:4318`
  - Jaeger: `http://jaeger:4318`

#### `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT`
- **Descrição:** Endpoint específico para traces (sobrescreve o anterior)
- **Formato:** URL completa com path `/v1/traces`
- **Exemplo:** `http://localhost:4318/v1/traces`

#### `DD_API_KEY` (Datadog)
- **Descrição:** API key do Datadog

#### `DD_SITE` (Datadog)
- **Padrão:** `datadoghq.com`
- **Opções:** `datadoghq.eu`, `us3.datadoghq.com`, etc.

---

### Frontend (Vite)

#### `VITE_USE_LOCAL_BACKEND`
- **Descrição:** Se o frontend deve usar API local ou remota
- **Valores:** `true` ou `false`
- **Desenvolvimento:** `true`
- **Produção:** `false`

#### `VITE_PUBLIC_POSTHOG_KEY`
- **Descrição:** Project API Key do PostHog para analytics
- **Onde encontrar:** PostHog > Project Settings

#### `VITE_PUBLIC_POSTHOG_HOST`
- **Descrição:** URL da instância PostHog
- **Padrão:** `https://app.posthog.com`
- **Self-hosted:** `https://seu-posthog.com`

#### `VITE_FEATURE_THREADS_PROJECT`
- **Descrição:** Feature flag para threads

---

### Desenvolvimento

#### `NODE_ENV`
- **Valores:** `development` | `production`
- **Importante:** Sempre use `production` em produção!
- **Afeta:** Logs, cache, otimizações

#### `DEBUG`
- **Descrição:** Ativa logs de debug detalhados
- **Valores:** `true` ou deixe vazio/undefined

#### `DECO_TOKEN`
- **Descrição:** Token de autenticação da CLI Deco
- **Usado para:** Deploy via CLI

#### `DECO_TUNNEL_SERVER_TOKEN`
- **Descrição:** Token para tunnel de desenvolvimento remoto

#### `DECO_CLI_UPDATE_CHECKED`
- **Descrição:** Desabilita checagem de updates da CLI
- **Valores:** `true` para desabilitar

---

## Ambientes Diferentes

### Desenvolvimento Local
```bash
PORT=3000
BASE_URL=http://localhost:3000
NODE_ENV=development
DATABASE_URL=file:./data/mesh.db
ENCRYPTION_KEY=...
VITE_USE_LOCAL_BACKEND=true
```

### Staging/Homologação
```bash
PORT=3000
BASE_URL=https://staging.seu-dominio.com
NODE_ENV=production
DATABASE_URL=postgresql://...staging
ENCRYPTION_KEY=...
VITE_USE_LOCAL_BACKEND=false
STRIPE_SECRET_KEY=sk_test_...
```

### Produção
```bash
PORT=3000
BASE_URL=https://seu-dominio.com
NODE_ENV=production
DATABASE_URL=postgresql://...production
ENCRYPTION_KEY=...
VITE_USE_LOCAL_BACKEND=false
STRIPE_SECRET_KEY=sk_live_...
OTEL_EXPORTER_OTLP_ENDPOINT=https://...
```

---

## Segurança

### ✅ Boas Práticas

1. **NUNCA commite o arquivo `.env`**
   - Já está no `.gitignore`
   - Use `.env.example` para documentar

2. **Use secrets fortes**
   ```bash
   # Gerar chave base64 (32 bytes)
   openssl rand -base64 32

   # Gerar chave hex (32 bytes)
   openssl rand -hex 32

   # Gerar UUID
   uuidgen
   ```

3. **Rotacione secrets periodicamente**
   - Especialmente `ENCRYPTION_KEY` e `BETTER_AUTH_SECRET`
   - Tenha um plano de rotação em produção

4. **Use ferramentas de gestão de secrets**
   - Desenvolvimento: arquivo `.env` local
   - Produção: Vault, AWS Secrets Manager, etc.

5. **Diferentes secrets por ambiente**
   - Dev, staging e produção devem ter secrets diferentes
   - Nunca use o mesmo `ENCRYPTION_KEY` em múltiplos ambientes

6. **Backup do `ENCRYPTION_KEY`**
   - Guarde em local seguro (1Password, Bitwarden, etc.)
   - Sem ele você perde acesso aos dados criptografados

### ❌ O que NÃO fazer

- ❌ Commitar `.env` no git
- ❌ Compartilhar secrets via email/chat
- ❌ Usar secrets fracos ou óbvios
- ❌ Deixar secrets hardcoded no código
- ❌ Expor secrets em logs
- ❌ Usar o mesmo secret em dev e produção

---

## Troubleshooting

### Erro: "ENCRYPTION_KEY not set"
```bash
# Solução: Gere e configure a chave
echo "ENCRYPTION_KEY=$(openssl rand -base64 32)" >> .env
```

### Erro: "Database connection failed"
```bash
# SQLite: Verifique se o diretório data/ existe
mkdir -p apps/mesh/data

# PostgreSQL: Teste a conexão
psql "postgresql://usuario:senha@localhost:5432/decocms"
```

### Erro: "STRIPE_SECRET_KEY is not set"
```bash
# Se não for usar Stripe, pode ignorar
# Se for usar, configure:
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...
```

### Frontend não conecta ao backend
```bash
# Verifique se está usando o backend correto
# Development:
VITE_USE_LOCAL_BACKEND=true

# Production:
VITE_USE_LOCAL_BACKEND=false
```

### Observabilidade não funciona
```bash
# Verifique se o endpoint OTLP está acessível
curl http://localhost:4318/v1/traces

# Ou desabilite temporariamente
# (comente as linhas OTEL_*)
```

---

## Hierarquia de Configuração

O projeto carrega variáveis nesta ordem (última sobrescreve):

1. Valores padrão no código
2. Arquivo `.env`
3. Variáveis de ambiente do sistema
4. Arquivo `wrangler.toml` (apenas Cloudflare Workers)

---

## Validação

Para verificar se suas variáveis estão corretas:

```bash
# Ver variáveis carregadas (sem mostrar valores sensíveis)
cd apps/mesh
bun run dev

# Deve mostrar:
# ✅ MCP Mesh starting...
# 📋 Health check: http://localhost:3000/health
# ...
```

Teste o health check:
```bash
curl http://localhost:3000/health
# Deve retornar: {"status":"ok"}
```

---

## Recursos Adicionais

- [Better Auth Docs](https://www.better-auth.com/docs)
- [OpenTelemetry Docs](https://opentelemetry.io/docs/)
- [Stripe API Docs](https://stripe.com/docs/api)
- [Supabase Docs](https://supabase.com/docs)
- [Resend Docs](https://resend.com/docs)

---

**Dúvidas?** Abra uma issue no GitHub ou consulte a [documentação oficial](https://docs.decocms.com).
