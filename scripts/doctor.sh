#!/bin/bash
set -e

# ============================================================================
# Environment Health Check (Doctor)
# Verifies all Docker services and Symfony integrations are working
# ============================================================================

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'
PASS="${GREEN}✅ PASS${NC}"
FAIL="${RED}❌ FAIL${NC}"
WARN="${YELLOW}⚠️  WARN${NC}"

echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  🩺 Symfony Docker — Health Check${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

ERRORS=0

# --------------------------------------------------------------------------
# 1. PHP
# --------------------------------------------------------------------------
echo -n "  PHP version ................ "
PHP_VER=$(php -r 'echo PHP_VERSION;' 2>/dev/null)
if [ $? -eq 0 ]; then
    echo -e "${PASS} (${PHP_VER})"
else
    echo -e "${FAIL}"
    ERRORS=$((ERRORS + 1))
fi

# --------------------------------------------------------------------------
# 2. Required PHP Extensions
# --------------------------------------------------------------------------
REQUIRED_EXTS=("pdo_pgsql" "redis" "intl" "opcache" "apcu" "zip")
for ext in "${REQUIRED_EXTS[@]}"; do
    echo -n "  ext-${ext} .................. "
    if php -m 2>/dev/null | grep -qi "^${ext}$"; then
        echo -e "${PASS}"
    else
        echo -e "${FAIL}"
        ERRORS=$((ERRORS + 1))
    fi
done

# --------------------------------------------------------------------------
# 3. Composer
# --------------------------------------------------------------------------
echo -n "  Composer ................... "
COMP_VER=$(composer --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1)
if [ -n "$COMP_VER" ]; then
    echo -e "${PASS} (${COMP_VER})"
else
    echo -e "${FAIL}"
    ERRORS=$((ERRORS + 1))
fi

# --------------------------------------------------------------------------
# 4. Symfony Application
# --------------------------------------------------------------------------
echo -n "  Symfony application ........ "
if [ -f bin/console ]; then
    SF_VER=$(php bin/console --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1)
    if [ -n "$SF_VER" ]; then
        echo -e "${PASS} (${SF_VER})"
    else
        echo -e "${WARN} (bin/console exists but failed to get version)"
    fi
else
    echo -e "${WARN} (no Symfony app yet — run: make scaffold)"
fi

# --------------------------------------------------------------------------
# 5. PostgreSQL connection
# --------------------------------------------------------------------------
echo -n "  PostgreSQL connection ...... "
if [ -n "${DATABASE_URL:-}" ]; then
    RESULT=$(php -r "
        \$url = parse_url(getenv('DATABASE_URL'));
        \$host = \$url['host'] ?? 'database';
        \$port = \$url['port'] ?? 5432;
        \$conn = @fsockopen(\$host, \$port, \$errno, \$errstr, 3);
        if (\$conn) { echo 'OK'; fclose(\$conn); } else { echo 'FAIL'; }
    " 2>/dev/null)
    if [ "$RESULT" = "OK" ]; then
        echo -e "${PASS}"
    else
        echo -e "${FAIL} (cannot reach database)"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo -e "${WARN} (DATABASE_URL not set)"
fi

# --------------------------------------------------------------------------
# 6. Redis connection
# --------------------------------------------------------------------------
echo -n "  Redis connection ........... "
if [ -n "${REDIS_URL:-}" ]; then
    RESULT=$(php -r "
        try {
            \$redis = new Redis();
            \$parts = parse_url(getenv('REDIS_URL'));
            \$redis->connect(\$parts['host'] ?? 'redis', \$parts['port'] ?? 6379, 3);
            echo \$redis->ping() ? 'OK' : 'FAIL';
        } catch (Exception \$e) { echo 'FAIL'; }
    " 2>/dev/null)
    if [ "$RESULT" = "OK" ] || [ "$RESULT" = "+PONG" ] || [ "$RESULT" = "1" ]; then
        echo -e "${PASS}"
    else
        echo -e "${FAIL} (cannot reach redis)"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo -e "${WARN} (REDIS_URL not set)"
fi

# --------------------------------------------------------------------------
# 7. Mailpit SMTP
# --------------------------------------------------------------------------
echo -n "  Mailpit SMTP ............... "
if [ -n "${MAILER_DSN:-}" ]; then
    SMTP_HOST=$(echo "${MAILER_DSN}" | sed -n 's|.*://\([^:]*\).*|\1|p')
    SMTP_PORT=$(echo "${MAILER_DSN}" | sed -n 's|.*:\([0-9]*\)$|\1|p')
    RESULT=$(php -r "
        \$conn = @fsockopen('${SMTP_HOST:-mailpit}', ${SMTP_PORT:-1025}, \$errno, \$errstr, 3);
        if (\$conn) { echo 'OK'; fclose(\$conn); } else { echo 'FAIL'; }
    " 2>/dev/null)
    if [ "$RESULT" = "OK" ]; then
        echo -e "${PASS}"
    else
        echo -e "${WARN} (mailpit not reachable — emails won't be captured)"
    fi
else
    echo -e "${WARN} (MAILER_DSN not set)"
fi

# --------------------------------------------------------------------------
# 8. Writable directories
# --------------------------------------------------------------------------
echo -n "  var/ writable .............. "
if [ -w var/ ] 2>/dev/null; then
    echo -e "${PASS}"
else
    echo -e "${FAIL} (var/ is not writable)"
    ERRORS=$((ERRORS + 1))
fi

# --------------------------------------------------------------------------
# 9. Quality tools
# --------------------------------------------------------------------------
echo -n "  PHPStan .................... "
if [ -f vendor/bin/phpstan ]; then
    echo -e "${PASS}"
else
    echo -e "${WARN} (not installed — run: composer require --dev phpstan/phpstan)"
fi

echo -n "  PHP-CS-Fixer ............... "
if [ -f vendor/bin/php-cs-fixer ]; then
    echo -e "${PASS}"
else
    echo -e "${WARN} (not installed — run: composer require --dev friendsofphp/php-cs-fixer)"
fi

echo -n "  PHPUnit .................... "
if [ -f bin/phpunit ] || [ -f vendor/bin/phpunit ]; then
    echo -e "${PASS}"
else
    echo -e "${WARN} (not installed — run: composer require --dev phpunit/phpunit)"
fi

# --------------------------------------------------------------------------
# Summary
# --------------------------------------------------------------------------
echo ""
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  All checks passed! Your environment is healthy. 🎉${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
else
    echo -e "${RED}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}  ${ERRORS} check(s) failed. Review the errors above.${NC}"
    echo -e "${RED}═══════════════════════════════════════════════════════════════${NC}"
    exit 1
fi
