#!/bin/bash
set -e

# ============================================================================
# Docker Entrypoint for Symfony + FrankenPHP
# Zero-config: handles composer install, DB setup, cache warmup automatically.
# Just run "docker compose up" and everything works.
# ============================================================================

# --------------------------------------------------------------------------
# Auto-install: If vendor/ is missing, run composer install
# --------------------------------------------------------------------------
if [ -f composer.json ] && [ ! -d vendor ] && [ "${SKIP_AUTO_INSTALL:-false}" != "true" ]; then
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║  📦 First boot detected — installing dependencies...         ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""
    composer install --prefer-dist --no-interaction --optimize-autoloader
    echo ""
    echo "✅ Dependencies installed."
fi

# --------------------------------------------------------------------------
# Ensure bin/console is executable
# --------------------------------------------------------------------------
if [ -f bin/console ]; then
    chmod +x bin/console
fi

# --------------------------------------------------------------------------
# Wait for PostgreSQL
# --------------------------------------------------------------------------
if [ "${WAIT_FOR_DB:-false}" = "true" ] && [ -n "${DATABASE_URL:-}" ]; then
    echo "⏳ Waiting for database..."
    timeout=30
    counter=0
    until php -r "
        \$url = parse_url(getenv('DATABASE_URL'));
        \$host = \$url['host'] ?? 'database';
        \$port = \$url['port'] ?? 5432;
        @fsockopen(\$host, \$port, \$errno, \$errstr, 2) || exit(1);
    " 2>/dev/null; do
        counter=$((counter + 1))
        if [ $counter -ge $timeout ]; then
            echo "⚠️  Database not reachable after ${timeout}s — starting anyway."
            break
        fi
        sleep 1
    done
    echo "✅ Database is reachable."
fi

# --------------------------------------------------------------------------
# Wait for Redis
# --------------------------------------------------------------------------
if [ "${WAIT_FOR_DB:-false}" = "true" ] && [ -n "${REDIS_URL:-}" ]; then
    echo "⏳ Waiting for Redis..."
    counter=0
    until php -r "
        \$parts = parse_url(getenv('REDIS_URL'));
        @fsockopen(\$parts['host'] ?? 'redis', \$parts['port'] ?? 6379, \$e, \$s, 2) || exit(1);
    " 2>/dev/null; do
        counter=$((counter + 1))
        if [ $counter -ge 15 ]; then
            echo "⚠️  Redis not reachable — starting anyway."
            break
        fi
        sleep 1
    done
    echo "✅ Redis is reachable."
fi

# --------------------------------------------------------------------------
# Symfony setup (only if bin/console exists and vendor is installed)
# --------------------------------------------------------------------------
if [ -f bin/console ] && [ -d vendor ]; then

    # Ensure var/ directories exist with correct permissions
    mkdir -p var/cache var/log
    if [ "$APP_ENV" != 'prod' ]; then
        setfacl -R -m u:www-data:rwX -m u:"$(whoami)":rwX var 2>/dev/null || \
            chmod -R 777 var 2>/dev/null || true
    fi

    # Auto-create database (dev/test only)
    if [ "$APP_ENV" != 'prod' ] && [ "${WAIT_FOR_DB:-false}" = "true" ]; then
        echo "📦 Ensuring database exists..."
        php bin/console doctrine:database:create --if-not-exists --no-interaction 2>/dev/null || true
    fi

    # Run migrations (if flag is set and not a worker container)
    if [ "${RUN_MIGRATIONS:-false}" = "true" ] && [ "${WORKER_CONTAINER:-false}" != "true" ]; then
        echo "🔄 Running database migrations..."
        php bin/console doctrine:migrations:migrate --no-interaction --allow-no-migration 2>/dev/null || true
    fi

    # Warm up cache
    if [ "$APP_ENV" = 'prod' ]; then
        echo "🔥 Warming up production cache..."
        php bin/console cache:warmup --no-interaction || true
    fi
fi

# --------------------------------------------------------------------------
# Execute CMD (FrankenPHP or messenger:consume)
# --------------------------------------------------------------------------
exec docker-php-entrypoint "$@"
