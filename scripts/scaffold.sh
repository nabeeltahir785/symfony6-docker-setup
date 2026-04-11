#!/bin/bash
set -e

# ============================================================================
# Symfony Project Scaffolding Script
# Creates a full Symfony application with all bundles pre-configured
# for the Docker stack (PostgreSQL, Redis, Messenger, Mailer).
#
# Usage: ./scripts/scaffold.sh [SYMFONY_VERSION]
#   SYMFONY_VERSION: "6.4" or "7.0" (default: "7.0")
# ============================================================================

SYMFONY_VERSION="${1:-7.0}"
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  Symfony ${SYMFONY_VERSION} — Project Scaffolding${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# --------------------------------------------------------------------------
# Guard: Don't overwrite an existing project
# --------------------------------------------------------------------------
if [ -f composer.json ]; then
    echo -e "${YELLOW}⚠️  composer.json already exists — skipping Symfony creation.${NC}"
    echo -e "${YELLOW}   Running composer install instead...${NC}"
    composer install --prefer-dist --no-interaction
    exit 0
fi

# --------------------------------------------------------------------------
# Step 1: Create Symfony skeleton
# --------------------------------------------------------------------------
echo -e "${CYAN}[1/6] Creating Symfony ${SYMFONY_VERSION} project...${NC}"
composer create-project "symfony/skeleton:${SYMFONY_VERSION}.*" /tmp/symfony-app --prefer-dist --no-interaction

# Move everything from temp to /app (preserving Docker config)
shopt -s dotglob
cp -rn /tmp/symfony-app/* /app/ 2>/dev/null || true
rm -rf /tmp/symfony-app
shopt -u dotglob

echo -e "${GREEN}✅ Symfony skeleton created.${NC}"

# --------------------------------------------------------------------------
# Step 2: Install essential bundles (the "battery-included" stack)
# --------------------------------------------------------------------------
echo -e "${CYAN}[2/6] Installing production bundles...${NC}"
composer require --no-interaction --no-scripts \
    symfony/orm-pack \
    symfony/messenger \
    symfony/redis-messenger \
    symfony/mailer \
    symfony/twig-bundle \
    symfony/asset-mapper \
    symfony/stimulus-bundle \
    symfony/security-bundle \
    symfony/validator \
    symfony/serializer \
    symfony/monolog-bundle \
    symfony/cache \
    symfony/http-client \
    symfony/expression-language

echo -e "${GREEN}✅ Production bundles installed.${NC}"

# --------------------------------------------------------------------------
# Step 3: Install dev/test bundles
# --------------------------------------------------------------------------
echo -e "${CYAN}[3/6] Installing dev/test bundles...${NC}"
composer require --dev --no-interaction --no-scripts \
    symfony/debug-bundle \
    symfony/web-profiler-bundle \
    symfony/maker-bundle \
    doctrine/doctrine-fixtures-bundle \
    phpunit/phpunit \
    phpstan/phpstan \
    phpstan/phpstan-symfony \
    phpstan/phpstan-doctrine \
    friendsofphp/php-cs-fixer \
    dama/doctrine-test-bundle \
    zenstruck/foundry

echo -e "${GREEN}✅ Dev/test bundles installed.${NC}"

# --------------------------------------------------------------------------
# Step 4: Apply pre-configured templates for Docker services
# --------------------------------------------------------------------------
echo -e "${CYAN}[4/6] Applying service configurations...${NC}"

# --- Doctrine (PostgreSQL) ---
if [ -d /app/config/packages ]; then
    cat > /app/config/packages/doctrine.yaml << 'YAML'
doctrine:
    dbal:
        url: '%env(resolve:DATABASE_URL)%'
        profiling_collect_backtrace: '%kernel.debug%'
        use_savepoints: true
    orm:
        auto_generate_proxy_classes: true
        enable_lazy_ghost_objects: true
        naming_strategy: doctrine.orm.naming_strategy.underscore_number_aware
        auto_mapping: true
        mappings:
            App:
                type: attribute
                is_bundle: false
                dir: '%kernel.project_dir%/src/Entity'
                prefix: 'App\Entity'
                alias: App
        controller_resolver:
            auto_mapping: true

when@test:
    doctrine:
        dbal:
            dbname_suffix: '_test%env(default::TEST_TOKEN)%'

when@prod:
    doctrine:
        orm:
            auto_generate_proxy_classes: false
            proxy_dir: '%kernel.build_dir%/doctrine/orm/Proxies'
            query_cache_driver:
                type: pool
                pool: doctrine.system_cache_pool
            result_cache_driver:
                type: pool
                pool: doctrine.result_cache_pool
YAML
fi

# --- Messenger (Redis transport) ---
cat > /app/config/packages/messenger.yaml << 'YAML'
framework:
    messenger:
        failure_transport: failed

        transports:
            async:
                dsn: '%env(MESSENGER_TRANSPORT_DSN)%'
                retry_strategy:
                    max_retries: 3
                    multiplier: 2
                    delay: 1000
                    max_delay: 60000
            failed:
                dsn: 'doctrine://default?queue_name=failed'

        routing:
            # Route your messages to the async transport
            # 'App\Message\YourMessage': async
YAML

# --- Cache (Redis) ---
cat > /app/config/packages/cache.yaml << 'YAML'
framework:
    cache:
        # Redis cache adapter
        app: cache.adapter.redis
        default_redis_provider: '%env(REDIS_URL)%'

        # Pools for Doctrine
        pools:
            doctrine.result_cache_pool:
                adapter: cache.app
            doctrine.system_cache_pool:
                adapter: cache.system
YAML

# --- Mailer (Mailpit) ---
cat > /app/config/packages/mailer.yaml << 'YAML'
framework:
    mailer:
        dsn: '%env(MAILER_DSN)%'

when@test:
    framework:
        mailer:
            dsn: 'null://null'
YAML

echo -e "${GREEN}✅ Service configs applied (Doctrine, Messenger, Cache, Mailer).${NC}"

# --------------------------------------------------------------------------
# Step 5: Create quality tool config files
# --------------------------------------------------------------------------
echo -e "${CYAN}[5/6] Creating quality tool configs...${NC}"

# --- PHPStan ---
cat > /app/phpstan.neon.dist << 'NEON'
includes:
    - vendor/phpstan/phpstan-symfony/extension.neon
    - vendor/phpstan/phpstan-doctrine/extension.neon

parameters:
    level: 6
    paths:
        - src
        - tests
    excludePaths:
        - src/Kernel.php
    symfony:
        containerXmlPath: var/cache/dev/App_KernelDevDebugContainer.xml
    doctrine:
        objectManagerLoader: tests/bootstrap.php
NEON

# --- PHP-CS-Fixer ---
cat > /app/.php-cs-fixer.dist.php << 'PHP'
<?php

$finder = (new PhpCsFixer\Finder())
    ->in(__DIR__)
    ->exclude('var')
    ->exclude('vendor')
    ->exclude('node_modules')
;

return (new PhpCsFixer\Config())
    ->setRules([
        '@Symfony' => true,
        '@Symfony:risky' => true,
        'declare_strict_types' => true,
        'native_function_invocation' => ['include' => ['@compiler_optimized'], 'scope' => 'namespaced'],
        'no_unused_imports' => true,
        'ordered_imports' => ['sort_algorithm' => 'alpha'],
        'concat_space' => ['spacing' => 'one'],
        'array_syntax' => ['syntax' => 'short'],
        'phpdoc_align' => ['align' => 'left'],
        'class_attributes_separation' => ['elements' => ['method' => 'one']],
        'trailing_comma_in_multiline' => ['elements' => ['arguments', 'arrays', 'match', 'parameters']],
    ])
    ->setRiskyAllowed(true)
    ->setFinder($finder)
    ->setCacheFile('var/.php-cs-fixer.cache')
;
PHP

echo -e "${GREEN}✅ Quality tools configured (PHPStan level 6, PHP-CS-Fixer @Symfony).${NC}"

# --------------------------------------------------------------------------
# Step 6: Create test structure & example smoke test
# --------------------------------------------------------------------------
echo -e "${CYAN}[6/6] Setting up test infrastructure...${NC}"

mkdir -p /app/tests/Unit /app/tests/Functional

# Example smoke test
cat > /app/tests/Functional/HealthCheckTest.php << 'PHP'
<?php

declare(strict_types=1);

namespace App\Tests\Functional;

use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;

class HealthCheckTest extends WebTestCase
{
    public function testApplicationIsHealthy(): void
    {
        $client = static::createClient();
        $client->request('GET', '/');

        // Any non-500 response means the framework is booting correctly
        self::assertResponseIsSuccessful();
    }
}
PHP

# Create .env.test with DB override
if [ ! -f /app/.env.test ]; then
    cat > /app/.env.test << 'ENV'
# Test environment overrides
KERNEL_CLASS='App\Kernel'
APP_SECRET='test-secret'
SYMFONY_DEPRECATIONS_HELPER=999999
PANTHER_APP_ENV=test
DATABASE_URL="postgresql://app:!ChangeMe!@database:5432/app_test?serverVersion=16&charset=utf8"
MESSENGER_TRANSPORT_DSN=in-memory://
MAILER_DSN=null://null
ENV
fi

# Configure PHPUnit with test suites
cat > /app/phpunit.xml.dist << 'XML'
<?xml version="1.0" encoding="UTF-8"?>
<phpunit xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:noNamespaceSchemaLocation="vendor/phpunit/phpunit/phpunit.xsd"
         colors="true"
         bootstrap="tests/bootstrap.php"
         failOnRisky="true"
         failOnWarning="true"
>
    <php>
        <ini name="display_errors" value="1"/>
        <ini name="error_reporting" value="-1"/>
        <server name="APP_ENV" value="test" force="true"/>
        <server name="SHELL_VERBOSITY" value="-1"/>
        <server name="SYMFONY_PHPUNIT_REMOVE" value=""/>
        <server name="SYMFONY_PHPUNIT_VERSION" value="10"/>
    </php>

    <testsuites>
        <testsuite name="unit">
            <directory>tests/Unit</directory>
        </testsuite>
        <testsuite name="functional">
            <directory>tests/Functional</directory>
        </testsuite>
    </testsuites>

    <coverage>
        <include>
            <directory suffix=".php">src</directory>
        </include>
        <exclude>
            <directory>src/Kernel.php</directory>
        </exclude>
    </coverage>
</phpunit>
XML

echo -e "${GREEN}✅ Test infrastructure ready (unit + functional suites).${NC}"

# --------------------------------------------------------------------------
# Final: Ensure proper var directory
# --------------------------------------------------------------------------
mkdir -p var/cache var/log
chmod -R 777 var 2>/dev/null || true

# Run Composer scripts that were skipped during install
composer run-script post-install-cmd 2>/dev/null || true

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  ✅ Symfony ${SYMFONY_VERSION} project fully scaffolded!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  Bundles installed:"
echo -e "    ✔ Doctrine ORM (PostgreSQL)"
echo -e "    ✔ Messenger (Redis transport)"
echo -e "    ✔ Cache (Redis adapter)"
echo -e "    ✔ Mailer (Mailpit)"
echo -e "    ✔ Twig + AssetMapper + Stimulus"
echo -e "    ✔ Security + Validator + Serializer"
echo -e "    ✔ PHPStan (level 6) + PHP-CS-Fixer"
echo -e "    ✔ PHPUnit + Foundry + DAMA DoctrineTestBundle"
echo ""
echo -e "  Next: Open ${CYAN}https://localhost${NC} in your browser"
echo ""
