<p align="center">
  <img src="https://img.shields.io/badge/Symfony-7.0-purple?style=for-the-badge&logo=symfony" alt="Symfony 7.0">
  <img src="https://img.shields.io/badge/PHP-8.3-blue?style=for-the-badge&logo=php" alt="PHP 8.3">
  <img src="https://img.shields.io/badge/FrankenPHP-Caddy-green?style=for-the-badge" alt="FrankenPHP">
  <img src="https://img.shields.io/badge/Docker-Compose-2496ED?style=for-the-badge&logo=docker" alt="Docker">
  <img src="https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge" alt="MIT License">
</p>

# ⚡ Symfony Docker Starter

A **zero-config**, production-ready Symfony 7.0 starter template powered by [FrankenPHP](https://frankenphp.dev). Clone → `make up` → start coding. Everything auto-configures.

> **Why this boilerplate?** Most Symfony starters leave you wiring Docker, database connections, Redis, Messenger workers, CI pipelines, and quality tools manually. This one ships with **everything pre-configured** — from Xdebug to production deployment — so you spend time building features, not infrastructure.

---

## 🚀 Quickstart

```bash
git clone https://github.com/nabeeltahir785/symfony6-docker-setup.git my-project
cd my-project
make up
```

Wait ~60 seconds for the first-boot setup, then open **https://localhost** 🎉

> **That's it.** No `composer install`, no `php bin/console`, no database setup. The container handles everything automatically on first boot.

---

## 🔄 What Happens on First Boot

The [docker-entrypoint.sh](frankenphp/docker-entrypoint.sh) orchestrates the entire setup sequence:

| Step | What happens | Automatic? |
|------|-------------|:----------:|
| 1 | Docker builds the FrankenPHP image with PHP 8.3 | ✅ |
| 2 | Starts 5 containers (app, worker, database, redis, mailpit) | ✅ |
| 3 | Detects missing `vendor/` → runs `composer install` | ✅ |
| 4 | Waits for PostgreSQL + Redis to be healthy | ✅ |
| 5 | Creates the database (`doctrine:database:create`) | ✅ |
| 6 | Runs pending migrations (`doctrine:migrations:migrate`) | ✅ |
| 7 | Sets up Messenger transport tables (`messenger:setup-transports`) | ✅ |
| 8 | Serves the app with auto-HTTPS at `https://localhost` | ✅ |

---

## 🏗 Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                      Docker Network (symfony)                        │
│                                                                      │
│  ┌─────────────────┐   ┌────────────────┐   ┌───────────────────┐  │
│  │  app             │   │  worker         │   │  mailpit          │  │
│  │  FrankenPHP      │   │  messenger:     │   │  SMTP  :1025      │  │
│  │  :80 / :443      │   │  consume async  │   │  UI    :8025      │  │
│  │  HTTP/3 (UDP)    │   │  30s graceful   │   │                   │  │
│  └───────┬──────────┘   └───────┬────────┘   └───────────────────┘  │
│          │                      │                                     │
│    ┌─────┴──────────────────────┴───────┐                            │
│    │                                    │                            │
│  ┌─▼──────────────────┐  ┌─────────────▼──┐                         │
│  │  database           │  │  redis          │                        │
│  │  PostgreSQL 16      │  │  Redis 7        │                        │
│  │  :5432              │  │  :6379          │                        │
│  │  Health: pg_isready │  │  Health: ping   │                        │
│  └─────────────────────┘  └────────────────┘                         │
└──────────────────────────────────────────────────────────────────────┘
```

### Multi-Stage Dockerfile

The [Dockerfile](Dockerfile) uses 5 stages optimized for each use case:

| Stage | Purpose | Base |
|-------|---------|------|
| `frankenphp_base` | Shared PHP extensions, Caddy config, healthcheck | `dunglas/frankenphp:1-php8.3` |
| `frankenphp_dev` | Xdebug, PCOV, dev tools, `--watch` hot reload | base |
| `frankenphp_test` | PCOV only (no Xdebug overhead), runs PHPUnit | base |
| `frankenphp_prod_builder` | `composer install --no-dev`, AssetMapper compile | base |
| `frankenphp_prod` | Purged git/cache, non-root `www-data`, minimal | prod_builder |

---

## 📦 What's Included

### Production Bundles

| Bundle | Wired To | Config |
|--------|----------|--------|
| Doctrine ORM 3.0 | PostgreSQL 16 | [`doctrine.yaml`](config/packages/doctrine.yaml) |
| Messenger | Redis (async) + Doctrine (failed) | [`messenger.yaml`](config/packages/messenger.yaml) |
| Cache | Redis (app + sessions) | [`cache.yaml`](config/packages/cache.yaml) |
| Mailer | Mailpit (dev) / configurable (prod) | [`mailer.yaml`](config/packages/mailer.yaml) |
| Security | In-memory (upgradeable to Doctrine) | [`security.yaml`](config/packages/security.yaml) |
| Rate Limiter | API throttle + login protection | [`rate_limiter.yaml`](config/packages/rate_limiter.yaml) |
| Monolog | File (dev) · JSON stderr (prod) · Messenger channel | [`monolog.yaml`](config/packages/monolog.yaml) |
| Twig + AssetMapper + Stimulus | Template rendering + modern JS | [`twig.yaml`](config/packages/twig.yaml) |
| Validator · Serializer · HttpClient | Core Symfony components | — |

### Dev/Test Bundles

| Bundle | Purpose |
|--------|---------|
| [WebProfiler](https://symfony.com/doc/current/profiler.html) | Debug toolbar in browser |
| [MakerBundle](https://symfony.com/bundles/SymfonyMakerBundle) | `make:entity`, `make:controller`, `make:crud` |
| [DoctrineFixtures](https://symfony.com/bundles/DoctrineFixturesBundle) + [Foundry](https://github.com/zenstruck/foundry) | Test data factories |
| [DAMA DoctrineTestBundle](https://github.com/dmaicher/doctrine-test-bundle) | Auto-rollback DB per test |
| [PHPUnit 10](https://phpunit.de/) | Testing framework |
| [PHPStan](https://phpstan.org/) (level 6) + Doctrine + Symfony extensions | Static analysis |
| [PHP-CS-Fixer](https://github.com/PHP-CS-Fixer/PHP-CS-Fixer) | Coding standards (`@Symfony` ruleset) |

### Production Hardening (Pre-Configured)

| Feature | Implementation |
|---------|---------------|
| 🔒 Security headers | X-Frame-Options, nosniff, referrer-policy via [Caddyfile](frankenphp/Caddyfile) |
| 🔒 Trusted proxies | Configurable via `TRUSTED_PROXIES` env var |
| 🔒 Rate limiting | API (100/min) + Login (5/min) throttles |
| 🔒 Non-root production | `USER www-data` in prod Dockerfile |
| 🔒 SUID/SGID bits removed | In prod image for container hardening |
| ⚡ OPcache + JIT | Enabled with preloading in production |
| ⚡ HTTP/3 + zstd/brotli/gzip | Automatic via Caddy |
| ⚡ Worker mode | FrankenPHP persistent workers (boot once, serve many) |
| 📊 JSON structured logging | Monolog JSON formatter to stderr in production |
| 📊 Health endpoint | [`/healthz`](src/Controller/HealthController.php) — DB + Redis connectivity checks |
| 🔄 Graceful worker shutdown | 30s `stop_grace_period` — no message loss |

---

## 🛠 Commands

Run `make help` for the categorized command reference. Highlights:

### Lifecycle

| Command | Description |
|---------|-------------|
| `make up` | **Start everything** (the only command you need) |
| `make down` | Stop all services |
| `make restart` | Restart all services |
| `make build` | Rebuild images (after Dockerfile changes) |
| `make clean` | Stop + destroy all data (hard reset) |
| `make status` | Show container status |

### Code Quality

| Command | Description |
|---------|-------------|
| `make quality` | Run **all** checks (lint + PHPStan + CS-Fixer) |
| `make lint` | Lint containers, YAML, Twig |
| `make phpstan` | PHPStan static analysis (level 6) |
| `make cs-check` | Check coding standards (dry run) |
| `make cs-fix` | Auto-fix coding standards |
| `make security-audit` | Check dependencies for known CVEs |

### Testing

| Command | Description |
|---------|-------------|
| `make test` | Run full test suite |
| `make test-unit` | Run unit tests only |
| `make test-functional` | Run functional tests only |
| `make test-coverage` | Tests + HTML coverage report |

### Database

| Command | Description |
|---------|-------------|
| `make db-reset` | Full cycle: drop → create → migrate → fixtures |
| `make db-migrate` | Run pending migrations |
| `make db-diff` | Generate migration from entity changes |
| `make db-rollback` | Rollback last migration |
| `make db-validate` | Validate schema against entities |
| `make db-fixtures` | Load data fixtures |

### Messenger (Async Workers)

| Command | Description |
|---------|-------------|
| `make worker-logs` | Follow worker container logs |
| `make messenger-failed` | List failed messages |
| `make messenger-retry` | Retry all failed messages |
| `make messenger-stop` | Signal worker to stop gracefully |

### Tools

| Command | Description |
|---------|-------------|
| `make shell` | Bash into the app container |
| `make logs` | Follow all container logs |
| `make doctor` | Health check all services + extensions |
| `make redis-cli` | Open Redis CLI |
| `make console CMD="..."` | Run any Symfony console command |
| `make composer CMD="..."` | Run any Composer command |

### Generators (Symfony Maker)

| Command | Description |
|---------|-------------|
| `make make-entity` | Generate a Doctrine entity |
| `make make-controller` | Generate a controller |
| `make make-crud` | Generate CRUD for an entity |
| `make make-user` | Generate a User entity + security provider |

---

## 🏃 Start Building

### Create your first entity

```bash
make make-entity
# → Follow prompts to define fields
# → Entity + Repository are auto-generated

make db-diff
# → Migration file generated from your entity

make db-migrate
# → Table created in PostgreSQL
```

### Set up authentication

```bash
make make-user
# → Generates User entity with email/password
# → Update config/packages/security.yaml:
#    providers:
#        app_user_provider:
#            entity:
#                class: App\Entity\User
#                property: email
#    firewalls:
#        main:
#            provider: app_user_provider
```

### Test the async pipeline

The boilerplate ships with an example [ExampleNotification](src/Message/ExampleNotification.php) message and [handler](src/MessageHandler/ExampleNotificationHandler.php) that sends an email through Mailpit:

```php
// In any controller or service:
use App\Message\ExampleNotification;
use Symfony\Component\Messenger\MessageBusInterface;

$bus->dispatch(new ExampleNotification('user@example.com', 'Hello!'));
// → Message queued to Redis → Worker picks it up → Email sent to Mailpit
// → Check http://localhost:8025 to see the email
```

---

## 🌐 Services

| Service | URL / Port | Credentials |
|---------|-----------|-------------|
| Application | https://localhost | — |
| Health Check | https://localhost/healthz | — |
| Mailpit UI | http://localhost:8025 | — |
| PostgreSQL | localhost:5432 | `app` / `!ChangeMe!` |
| Redis | localhost:6379 | No password (dev) |

> All ports are configurable via `.env` — see `HTTP_PORT`, `HTTPS_PORT`, `POSTGRES_PORT`, `REDIS_PORT`, `MAILPIT_UI_PORT`.

---

## 🐛 Debugging

### Xdebug

```bash
# Enable Xdebug step debugging
XDEBUG_MODE=debug make up

# For VS Code users, also set:
XDEBUG_IDE_KEY=VSCODE
```

Xdebug is pre-configured in [20-app.dev.ini](frankenphp/conf.d/20-app.dev.ini):
- **Host**: `host.docker.internal` (works on macOS + Windows)
- **Port**: 9003
- **IDE Key**: Configurable via `XDEBUG_IDE_KEY` env var (default: `PHPSTORM`)

### Var Dumper Server

```bash
# Start the dump server (catches dump() output in terminal)
make console CMD="server:dump"
```

### Health Diagnostics

```bash
make doctor
# Checks: PHP, extensions, Composer, Symfony, PostgreSQL, Redis, Mailpit, var/ permissions, quality tools
```

---

## 🚀 Production Deployment

### Build & Deploy

```bash
# Build the production image
docker compose -f docker-compose.yml -f docker-compose.prod.yml build

# Deploy
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

### Production Checklist

Before deploying, update these environment variables in your deployment environment:

```env
APP_ENV=prod
APP_SECRET=<generate-with-openssl-rand-hex-32>
APP_DEBUG=0

POSTGRES_PASSWORD=<strong-password>
REDIS_PASSWORD=<strong-password>

# If behind a reverse proxy / CDN:
TRUSTED_PROXIES=10.0.0.0/8,172.16.0.0/12
SERVER_NAME=your-domain.com
```

### What changes in production

| Feature | Dev | Prod |
|---------|-----|------|
| Dockerfile target | `frankenphp_dev` | `frankenphp_prod` |
| Source code | Bind-mounted (`./:/app`) | Baked into image |
| Xdebug | Available | Not installed |
| OPcache preloading | Disabled | Enabled |
| JIT compilation | Disabled | Enabled |
| Proxy classes | Auto-generated | Pre-compiled |
| Mailpit | Running | Disabled via profile |
| Restart policy | `unless-stopped` | `always` |
| Run as | root | `www-data` |
| FrankenPHP worker | Watch mode (hot reload) | Standard (persistent) |

---

## 🔁 CI/CD Pipeline

The [GitHub Actions workflow](.github/workflows/ci.yml) runs a 3-job pipeline on every push and PR:

```
quality ──→ test ──→ (parallel)
       └──→ docker build
```

| Job | What it does |
|-----|-------------|
| **🔍 Quality** | Container lint · YAML lint · Twig lint · PHPStan (level 6) · PHP-CS-Fixer · `composer audit` |
| **🧪 Test** | Full PHPUnit suite with PostgreSQL + Redis services · PCOV coverage · JUnit + Clover reports |
| **🐳 Docker** | Hadolint Dockerfile lint · Build `prod` + `test` images with GHA cache |

---

## 📁 Project Structure

```
├── bin/console                    # Symfony CLI
├── config/
│   ├── bundles.php                # Bundle registration
│   ├── packages/                  # 15 pre-wired service configs
│   │   ├── cache.yaml             # Redis cache + array for test
│   │   ├── doctrine.yaml          # PostgreSQL ORM + prod cache pools
│   │   ├── framework.yaml         # Sessions (Redis), trusted proxies, CSRF
│   │   ├── messenger.yaml         # Async (Redis) + failed (Doctrine) + test (in-memory)
│   │   ├── monolog.yaml           # Dev (file), test (fingers_crossed), prod (JSON stderr)
│   │   ├── rate_limiter.yaml      # API + login throttles
│   │   ├── security.yaml          # Upgradeable auth (in-memory → Doctrine)
│   │   └── ...                    # mailer, twig, validator, routing, etc.
│   ├── routes.yaml                # Attribute-based routing
│   └── services.yaml              # DI container configuration
├── frankenphp/
│   ├── Caddyfile                  # Caddy + FrankenPHP worker mode config
│   ├── conf.d/                    # Per-environment PHP INI files
│   │   ├── 10-app.ini             # Base (sessions, opcache)
│   │   ├── 20-app.dev.ini         # Xdebug config
│   │   ├── 20-app.prod.ini        # OPcache preloading, JIT
│   │   └── 20-app.test.ini        # Test-optimized settings
│   └── docker-entrypoint.sh       # Zero-config boot orchestrator
├── migrations/                    # Doctrine migrations
├── public/index.php               # FrankenPHP entry point
├── scripts/
│   └── doctor.sh                  # Health check diagnostic tool
├── src/
│   ├── Controller/
│   │   ├── HealthController.php   # /healthz — DB + Redis probe
│   │   └── HomeController.php     # Landing page
│   ├── Entity/                    # Your Doctrine entities
│   ├── Message/
│   │   └── ExampleNotification.php  # Example async message
│   ├── MessageHandler/
│   │   └── ExampleNotificationHandler.php  # Sends email via Mailpit
│   └── Repository/                # Doctrine repositories
├── templates/
│   ├── base.html.twig             # Base layout
│   └── home/index.html.twig       # Styled landing page
├── tests/
│   ├── Functional/                # WebTestCase tests (2 included)
│   └── Unit/                      # Unit tests (1 included)
├── .editorconfig                  # Consistent formatting across editors
├── .env                           # Default env vars (committed)
├── .env.test                      # Test overrides
├── .github/workflows/ci.yml      # 3-job CI pipeline
├── .php-cs-fixer.dist.php         # @Symfony coding standards
├── Dockerfile                     # Multi-stage (5 stages)
├── docker-compose.yml             # 5-service orchestration
├── docker-compose.prod.yml        # Production overrides
├── Makefile                       # 30+ developer commands
├── phpstan.neon.dist              # PHPStan level 6 + Doctrine + Symfony
└── phpunit.xml.dist               # PHPUnit 10 + DAMA extension
```

---

## ⚙️ Environment Variables

All configuration is via `.env` (committed defaults) + `.env.local` (your overrides, gitignored):

| Variable | Default | Purpose |
|----------|---------|---------|
| `APP_ENV` | `dev` | Symfony environment |
| `APP_SECRET` | `change-me-...` | CSRF/encryption key |
| `APP_DEBUG` | `1` | Debug mode |
| `POSTGRES_USER` | `app` | Database user |
| `POSTGRES_PASSWORD` | `!ChangeMe!` | Database password |
| `POSTGRES_DB` | `app` | Database name |
| `REDIS_PASSWORD` | *(empty)* | Redis AUTH password |
| `TRUSTED_PROXIES` | *(empty)* | Reverse proxy IPs/CIDRs |
| `XDEBUG_MODE` | `off` | `off`, `debug`, `coverage`, `profile` |
| `XDEBUG_IDE_KEY` | `PHPSTORM` | `PHPSTORM`, `VSCODE`, etc. |
| `SERVER_NAME` | `localhost` | Caddy server name |
| `HTTP_PORT` | `80` | Host HTTP port |
| `HTTPS_PORT` | `443` | Host HTTPS port |

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing`)
3. Run `make quality` and `make test` to verify
4. Commit (`git commit -m 'feat: add amazing feature'`)
5. Push and open a Pull Request

---

## 📄 License

[MIT](LICENSE) — Use it for anything. Attribution appreciated but not required.