# syntax=docker/dockerfile:1

# ============================================================================
# Symfony 6.4/7.0 — Production-Ready Multi-Stage Dockerfile
# Server: FrankenPHP (Caddy embedded) | PHP 8.3 | Debian Bookworm
# Stages: base → dev | test | prod_builder → prod
# ============================================================================

# ---------------------------------------------------------------------------
# Stage 0: Upstream — Pin the FrankenPHP base image version
# ---------------------------------------------------------------------------
FROM dunglas/frankenphp:1-php8.3 AS frankenphp_upstream

# ---------------------------------------------------------------------------
# Stage 1: BASE — Shared foundation for all environments
# ---------------------------------------------------------------------------
FROM frankenphp_upstream AS frankenphp_base

SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

WORKDIR /app

VOLUME /app/var/

# System deps + PHP extensions required by Symfony + PostgreSQL + Redis
# hadolint ignore=DL3008
RUN <<-EOF
	apt-get update
	apt-get install -y --no-install-recommends \
		acl \
		file \
		gettext \
		git
	install-php-extensions \
		@composer \
		amqp \
		apcu \
		intl \
		opcache \
		pdo_pgsql \
		redis \
		zip
	rm -rf /var/lib/apt/lists/*
EOF

# Allow Composer to run as root inside the container
# https://getcomposer.org/doc/03-cli.md#composer-allow-superuser
ENV COMPOSER_ALLOW_SUPERUSER=1

# Custom PHP configuration directory
ENV PHP_INI_SCAN_DIR=":$PHP_INI_DIR/app.conf.d"

# Copy FrankenPHP / Caddy configuration
COPY --link frankenphp/conf.d/10-app.ini $PHP_INI_DIR/app.conf.d/
COPY --link --chmod=755 frankenphp/docker-entrypoint.sh /usr/local/bin/docker-entrypoint
COPY --link frankenphp/Caddyfile /etc/frankenphp/Caddyfile

ENTRYPOINT ["docker-entrypoint"]

HEALTHCHECK --start-period=60s CMD php -r 'exit(false === @file_get_contents("http://localhost:2019/metrics", context: stream_context_create(["http" => ["timeout" => 5]])) ? 1 : 0);'
CMD ["frankenphp", "run", "--config", "/etc/frankenphp/Caddyfile"]

# ---------------------------------------------------------------------------
# Stage 2: DEV — Development image with Xdebug & debugging tools
# ---------------------------------------------------------------------------
FROM frankenphp_base AS frankenphp_dev

ENV APP_ENV=dev \
    XDEBUG_MODE=off \
    FRANKENPHP_WORKER_CONFIG=watch

# hadolint ignore=DL3008
RUN <<-EOF
	mv "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini"
	apt-get update
	apt-get install -y --no-install-recommends \
		curl \
		iproute2 \
		jq \
		sudo \
		unzip
	install-php-extensions \
		pcov \
		xdebug
	rm -rf /var/lib/apt/lists/*
	# Create non-root user for dev container
	useradd -m -s /bin/bash developer
	echo "developer ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/developer
	git config --system --add safe.directory /app
EOF

COPY --link frankenphp/conf.d/20-app.dev.ini $PHP_INI_DIR/app.conf.d/

CMD ["frankenphp", "run", "--config", "/etc/frankenphp/Caddyfile", "--watch"]

# ---------------------------------------------------------------------------
# Stage 3: TEST — CI image for automated testing (no Xdebug overhead)
# ---------------------------------------------------------------------------
FROM frankenphp_base AS frankenphp_test

ENV APP_ENV=test

RUN <<-EOF
	mv "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini"
	install-php-extensions pcov
EOF

COPY --link frankenphp/conf.d/20-app.test.ini $PHP_INI_DIR/app.conf.d/

# Install ALL dependencies (including require-dev) for tests
COPY --link composer.* symfony.* ./
RUN composer install --no-cache --prefer-dist --no-autoloader --no-scripts --no-progress

COPY --link . ./

RUN <<-EOF
	mkdir -p var/cache var/log
	composer dump-autoload --classmap-authoritative
	chmod +x bin/console; sync
EOF

CMD ["php", "bin/phpunit"]

# ---------------------------------------------------------------------------
# Stage 4: PROD BUILDER — Build the production artifact
# ---------------------------------------------------------------------------
FROM frankenphp_base AS frankenphp_prod_builder

ENV APP_ENV=prod

RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

COPY --link frankenphp/conf.d/20-app.prod.ini $PHP_INI_DIR/app.conf.d/

# Install production dependencies only (maximise layer cache)
COPY --link composer.* symfony.* ./
RUN composer install --no-cache --prefer-dist --no-dev --no-autoloader --no-scripts --no-progress

# Copy full application source
COPY --link . ./

RUN <<-EOF
	mkdir -p var/cache var/log
	composer dump-autoload --classmap-authoritative --no-dev
	composer dump-env prod
	composer run-script --no-dev post-install-cmd || true
	# Compile AssetMapper if present
	if [ -f importmap.php ]; then
		php bin/console asset-map:compile
	fi
	chmod +x bin/console; sync
EOF

# ---------------------------------------------------------------------------
# Stage 5: PROD — Minimal production image
# ---------------------------------------------------------------------------
FROM frankenphp_prod_builder AS frankenphp_prod

# Remove build-time packages not needed at runtime
# hadolint ignore=DL3008
RUN <<-EOF
	apt-get purge -y --auto-remove git
	rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
	# Remove setuid/setgid bits for security hardening
	find / -perm /6000 -type f -exec chmod a-s {} + 2>/dev/null || true
EOF

# Drop to non-root
USER www-data

HEALTHCHECK --start-period=60s CMD php -r 'exit(false === @file_get_contents("http://localhost:2019/metrics", context: stream_context_create(["http" => ["timeout" => 5]])) ? 1 : 0);'
CMD ["frankenphp", "run", "--config", "/etc/frankenphp/Caddyfile"]
