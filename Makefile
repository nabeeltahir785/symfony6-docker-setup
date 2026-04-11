# ============================================================================
#  Symfony 7.0 — Docker Development Toolkit
#  FrankenPHP + PostgreSQL 16 + Redis 7 + Messenger Worker + Mailpit
#
#  QUICKSTART:  make up   (that's it — everything auto-configures)
# ============================================================================

# --- Configuration ---
DOCKER_COMPOSE   := docker compose
PHP_EXEC         := $(DOCKER_COMPOSE) exec app
CONSOLE          := $(PHP_EXEC) php bin/console
COMPOSER         := $(PHP_EXEC) composer

# Colors
GREEN  := \033[0;32m
YELLOW := \033[0;33m
RED    := \033[0;31m
CYAN   := \033[0;36m
NC     := \033[0m

.DEFAULT_GOAL := help

# ============================================================================
#  HELP
# ============================================================================
.PHONY: help
help: ## Show this help
	@echo ""
	@echo "$(CYAN)═══════════════════════════════════════════════════════════════$(NC)"
	@echo "$(CYAN)  ⚡ Symfony Docker — Command Toolkit$(NC)"
	@echo "$(CYAN)═══════════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "  $(GREEN)Quickstart:$(NC)  $(YELLOW)make up$(NC)  ← builds, starts, installs deps, creates DB"
	@echo ""
	@echo "$(GREEN)LIFECYCLE:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | grep -E '(^up:|down|restart|clean|build|status)' | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-24s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(GREEN)CODE QUALITY:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | grep -E '(lint|phpstan|cs|fix|quality)' | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-24s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(GREEN)DATABASE:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | grep -E '(db-)' | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-24s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(GREEN)TESTING:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | grep -E '(test|coverage)' | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-24s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(GREEN)TOOLS:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | grep -vE '(^up:|down|restart|clean|build|status|lint|phpstan|cs|fix|quality|db-|test|coverage)' | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-24s$(NC) %s\n", $$1, $$2}'
	@echo ""

# ============================================================================
#  LIFECYCLE — "make up" is the only command you need
# ============================================================================
.PHONY: up down restart clean build status

up: ## ▶️  Start everything (auto-installs deps + creates DB on first run)
	@if [ ! -f .env.local ] && [ -f .env ]; then \
		echo "$(GREEN)✅ Using default .env$(NC)"; \
	fi
	$(DOCKER_COMPOSE) up -d --build --remove-orphans
	@echo ""
	@echo "$(GREEN)═══════════════════════════════════════════════════════════════$(NC)"
	@echo "$(GREEN)  ⚡ All services are running!$(NC)"
	@echo "$(GREEN)═══════════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "  🌐 Application:   $(CYAN)https://localhost$(NC)"
	@echo "  📧 Mailpit:       $(CYAN)http://localhost:8025$(NC)"
	@echo "  🐘 PostgreSQL:    localhost:5432"
	@echo "  🔴 Redis:         localhost:6379"
	@echo ""
	@echo "  $(YELLOW)First run? The container is installing dependencies.$(NC)"
	@echo "  $(YELLOW)Wait ~60s then refresh the browser.$(NC)"
	@echo ""

down: ## ⏹  Stop all services
	$(DOCKER_COMPOSE) down

restart: ## 🔄 Restart all services
	@$(MAKE) down
	@$(MAKE) up

build: ## 🔨 Rebuild Docker images (use after Dockerfile changes)
	$(DOCKER_COMPOSE) build --pull --no-cache

clean: ## 🧹 Stop services and destroy ALL data (hard reset)
	@echo "$(RED)⚠️  This will destroy all data (database, redis, etc.)$(NC)"
	$(DOCKER_COMPOSE) down -v --remove-orphans
	@echo "$(GREEN)✅ Clean complete. Run 'make up' to start fresh.$(NC)"

status: ## 📋 Show container status
	@$(DOCKER_COMPOSE) ps

# ============================================================================
#  CODE QUALITY
# ============================================================================
.PHONY: lint phpstan cs-check cs-fix quality

lint: ## 🔍 Lint Symfony containers, YAML, and Twig
	$(CONSOLE) lint:container
	$(CONSOLE) lint:yaml config/
	$(CONSOLE) lint:twig templates/ 2>/dev/null || true

phpstan: ## 🔬 Run PHPStan static analysis
	$(PHP_EXEC) vendor/bin/phpstan analyse --memory-limit=512M --no-progress

cs-check: ## 📏 Check coding standards (dry run)
	$(PHP_EXEC) vendor/bin/php-cs-fixer fix --dry-run --diff --verbose

cs-fix: ## ✨ Fix coding standards automatically
	$(PHP_EXEC) vendor/bin/php-cs-fixer fix --diff --verbose

quality: lint phpstan cs-check ## 🏆 Run ALL quality checks

# ============================================================================
#  DATABASE
# ============================================================================
.PHONY: db-create db-drop db-reset db-migrate db-diff db-rollback db-validate db-fixtures

db-create: ## 📦 Create the database
	$(CONSOLE) doctrine:database:create --if-not-exists --no-interaction

db-drop: ## 💀 Drop the database
	$(CONSOLE) doctrine:database:drop --force --if-exists --no-interaction

db-reset: db-drop db-create db-migrate db-fixtures ## ♻️  Full reset: drop → create → migrate → fixtures

db-migrate: ## ⬆️  Run pending migrations
	$(CONSOLE) doctrine:migrations:migrate --no-interaction --allow-no-migration

db-diff: ## 📝 Generate migration from entity changes
	$(CONSOLE) doctrine:migrations:diff --no-interaction

db-rollback: ## ⬇️  Rollback last migration
	$(CONSOLE) doctrine:migrations:migrate prev --no-interaction

db-validate: ## ✅ Validate schema
	$(CONSOLE) doctrine:schema:validate

db-fixtures: ## 🌱 Load fixtures
	$(CONSOLE) doctrine:fixtures:load --no-interaction 2>/dev/null || echo "$(YELLOW)⚠️  No fixtures — skipping.$(NC)"

# ============================================================================
#  TESTING
# ============================================================================
.PHONY: test test-unit test-functional test-coverage

test: ## 🧪 Run full test suite
	$(PHP_EXEC) php bin/phpunit --colors=always

test-unit: ## 🧪 Run unit tests only
	$(PHP_EXEC) php bin/phpunit --colors=always --testsuite=unit

test-functional: ## 🧪 Run functional tests only
	$(PHP_EXEC) php bin/phpunit --colors=always --testsuite=functional

test-coverage: ## 📊 Run tests with HTML coverage report
	$(PHP_EXEC) php -d pcov.enabled=1 bin/phpunit \
		--colors=always \
		--coverage-html var/coverage \
		--coverage-clover var/coverage/clover.xml \
		--coverage-text
	@echo "$(GREEN)📊 Coverage: open var/coverage/index.html$(NC)"

# ============================================================================
#  TOOLS
# ============================================================================
.PHONY: shell logs composer console cache-clear worker-logs redis-cli doctor messenger-failed messenger-retry messenger-stop security-audit

shell: ## 🐚 Open bash in the app container
	$(PHP_EXEC) bash

logs: ## 📜 Follow all container logs
	$(DOCKER_COMPOSE) logs -f --tail=100

composer: ## 🎼 Run Composer (usage: make composer CMD="require package")
	$(COMPOSER) $(CMD)

console: ## 🎮 Run Symfony console (usage: make console CMD="debug:router")
	$(CONSOLE) $(CMD)

cache-clear: ## 🗑  Clear and warmup cache
	$(CONSOLE) cache:clear

worker-logs: ## 📜 Follow Messenger worker logs
	$(DOCKER_COMPOSE) logs -f worker

redis-cli: ## 🔴 Open Redis CLI
	$(DOCKER_COMPOSE) exec redis redis-cli

doctor: ## 🩺 Verify all services are healthy
	@chmod +x scripts/doctor.sh
	$(PHP_EXEC) bash scripts/doctor.sh

messenger-failed: ## 📋 List failed messages
	$(CONSOLE) messenger:failed:show

messenger-retry: ## 🔄 Retry all failed messages
	$(CONSOLE) messenger:failed:retry --force

messenger-stop: ## ⏹  Signal workers to stop gracefully after current message
	$(CONSOLE) messenger:stop-workers

security-audit: ## 🔒 Check dependencies for known security vulnerabilities
	$(COMPOSER) audit --no-interaction

# ============================================================================
#  GENERATORS (Symfony Maker shortcuts)
# ============================================================================
.PHONY: make-entity make-controller make-crud make-user

make-entity: ## 🏗  Generate a Doctrine entity
	$(CONSOLE) make:entity

make-controller: ## 🏗  Generate a controller
	$(CONSOLE) make:controller

make-crud: ## 🏗  Generate CRUD for an entity
	$(CONSOLE) make:crud

make-user: ## 🏗  Generate a User entity + security
	$(CONSOLE) make:user

# ============================================================================
#  CI TARGETS
# ============================================================================
.PHONY: ci-test ci-lint

ci-test: ## 🧪 CI: Run tests
	$(DOCKER_COMPOSE) run --rm -e APP_ENV=test app php bin/phpunit --colors=always

ci-lint: lint phpstan cs-check ## 🔍 CI: All quality checks
