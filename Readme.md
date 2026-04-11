# ⚡ Symfony 7.0 — Production-Ready Docker Starter

A batteries-included Symfony 7.0 (PHP 8.3) starter template powered by **FrankenPHP**. Clone it, run one command, and start coding. Everything is pre-configured.

## Quickstart

```bash
git clone https://github.com/nabeeltahir785/symfony6-docker-setup.git my-project
cd my-project
docker compose up -d
```

Wait ~60 seconds for the first-boot setup, then open **https://localhost** 🎉

> **That's it.** No `composer install`, no `php bin/console`, no database setup. The container handles everything automatically on first boot.

## What Happens on First Boot

1. ✅ Docker builds the FrankenPHP image with PHP 8.3
2. ✅ Starts 5 containers (app, worker, database, redis, mailpit)
3. ✅ Detects missing `vendor/` → runs `composer install` automatically
4. ✅ Waits for PostgreSQL + Redis to be healthy
5. ✅ Creates the database automatically
6. ✅ Runs any pending migrations
7. ✅ Serves the app at `https://localhost`

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Docker Network (symfony)                      │
│                                                                  │
│  ┌────────────────┐  ┌──────────────┐  ┌────────────────────┐  │
│  │  app            │  │  worker       │  │  mailpit           │  │
│  │  FrankenPHP     │  │  messenger:   │  │  SMTP :1025        │  │
│  │  :80 / :443     │  │  consume      │  │  UI   :8025        │  │
│  └───────┬────────┘  └──────┬───────┘  └────────────────────┘  │
│          │                  │                                    │
│    ┌─────┴──────────────────┴──────┐                            │
│    │                               │                            │
│  ┌─▼───────────────┐  ┌──────────▼──┐                          │
│  │  database        │  │  redis       │                         │
│  │  PostgreSQL 16   │  │  Redis 7     │                         │
│  │  :5432           │  │  :6379       │                         │
│  └─────────────────┘  └─────────────┘                          │
└─────────────────────────────────────────────────────────────────┘
```

## What's Pre-Configured

### Production Bundles
Doctrine ORM (PostgreSQL) · Messenger (Redis) · Cache (Redis) · Mailer (Mailpit) · Twig · AssetMapper · Stimulus · Security · Validator · Serializer · Monolog · HttpClient

### Dev/Test Bundles
WebProfiler · DebugBundle · MakerBundle · DoctrineFixtures · Foundry · DAMA DoctrineTestBundle · PHPUnit · PHPStan (level 6) · PHP-CS-Fixer

### Service Configs Already Wired
| Service | Config | Connected To |
|---------|--------|-------------|
| Doctrine | `config/packages/doctrine.yaml` | PostgreSQL via `DATABASE_URL` |
| Messenger | `config/packages/messenger.yaml` | Redis via `MESSENGER_TRANSPORT_DSN` |
| Cache | `config/packages/cache.yaml` | Redis via `REDIS_URL` |
| Sessions | `config/packages/framework.yaml` | Redis via `REDIS_URL` |
| Mailer | `config/packages/mailer.yaml` | Mailpit via `MAILER_DSN` |
| Logs | `config/packages/monolog.yaml` | File (dev), JSON stderr (prod) |

## Commands

Run `make help` for the full list. Highlights:

| Command | What it does |
|---------|-------------|
| `make up` | **Start everything** (the only command you need) |
| `make down` | Stop all services |
| `make shell` | Bash into the app container |
| `make test` | Run PHPUnit test suite |
| `make quality` | Run lint + PHPStan + CS-Fixer |
| `make db-reset` | Drop → create → migrate → fixtures |
| `make doctor` | Health check all services |
| `make make-entity` | Symfony Maker: generate entity |
| `make make-controller` | Symfony Maker: generate controller |
| `make console CMD="..."` | Run any Symfony console command |

## Start Building

```bash
# Generate an entity
make make-entity

# Generate a controller
make make-controller

# Generate CRUD
make make-crud

# Create a User entity + auth
make make-user

# Run any console command
make console CMD="debug:router"
```

## Services

| Service | URL / Port |
|---------|-----------|
| Application | https://localhost |
| Mailpit UI | http://localhost:8025 |
| PostgreSQL | localhost:5432 |
| Redis | localhost:6379 |

## Xdebug

```bash
XDEBUG_MODE=debug docker compose up -d
```

## Production

```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --build
```

## Project Structure

```
├── bin/console                # Symfony CLI
├── config/
│   ├── bundles.php            # Bundle registration
│   ├── packages/              # All service configs (pre-wired)
│   ├── routes.yaml            # Attribute-based routing
│   └── services.yaml          # DI container
├── migrations/                # Doctrine migrations
├── public/index.php           # FrankenPHP entry point
├── src/
│   ├── Controller/            # Your controllers (HomeController included)
│   ├── Entity/                # Doctrine entities
│   ├── Message/               # Messenger messages
│   └── Repository/            # Doctrine repositories
├── templates/                 # Twig templates (landing page included)
├── tests/
│   ├── Functional/            # WebTestCase tests (example included)
│   └── Unit/                  # Unit tests
├── Dockerfile                 # Multi-stage (base/dev/test/prod)
├── docker-compose.yml         # 5-service orchestration
├── Makefile                   # Developer toolkit
├── composer.json              # All deps declared
├── phpunit.xml.dist           # PHPUnit config
├── phpstan.neon.dist          # PHPStan level 6
└── .php-cs-fixer.dist.php     # CS-Fixer @Symfony rules
```

## License

MIT