include Makefile.conf
# Variables
EXEC = docker exec -w /var/www/project www_$(PROJECTNAME)_$(ENV)
EXECINIT = docker exec -w /var/www www_$(PROJECTNAME)_$(ENV)
PHP = $(EXEC) php
COMPOSER = $(EXEC) composer
NPM = $(EXEC) npm
SYMFONY_CONSOLE = $(PHP) bin/console
DATABASE_URL= "mysql://$(DBUSER):$(DBPASS)@$(PROJECTNAME).test:3306/$(DBNAME)?serverVersion=8&charset=utf8mb4"
NOTSETERROR="is not set in Makefile.conf"
# Colors
GREEN = /bin/echo -e "\x1b[32m\#\# $1\x1b[0m"
RED = /bin/echo -e "\x1b[31m\#\# $1\x1b[0m"
WHITEONRED = /bin/echo -e "\033[41m----- $1 -----\033[m"
GREENBG = /bin/echo -e "\033[42m----- $1 -----\033[m"

## —— 🔥 Init a new symfony project ——
check-config: ## Check if required variables are set in Makefile.conf
ifndef PROJECTNAME
	$(error PROJECTNAME $(NOTSETERROR))
endif
ifndef ENV
	$(error ENV $(NOTSETERROR))
endif
ifndef DBNAME
	$(error DBNAME $(NOTSETERROR))
endif
ifndef DBUSER
	$(error DBUSER $(NOTSETERROR))
endif
ifndef MAILPORT
	$(error MAILPORT $(NOTSETERROR))
endif
ifndef PHPMYADMINPORT
	$(error PHPMYADMINPORT $(NOTSETERROR))
endif
ifndef WWWPORT
	$(error WWWPORT $(NOTSETERROR))
endif

load-config: ## Import config from Makefile.conf
    export $(shell sed 's/=.*//' Makefile.conf)

new-project: load-config check-config ## Create a new Symfony project
ifneq ("$(shell id -u)", "0")
	@$(call WHITEONRED,"You must be root to run this command. Please try with sudo.")
else
	sed 's/PROJECTNAME/$(PROJECTNAME)_$(ENV)/g; s/DBNAME/$(DBNAME)/g; s/DBUSER/$(DBUSER)/g; s/DBPASS/$(DBPASS)/g; s/DBROOTPASS/$(DBROOTPASS)/g; s/MAILPORT/$(MAILPORT)/g; s/PHPMYADMINPORT/$(PHPMYADMINPORT)/g; s/WWWPORT/$(WWWPORT)/g' docker-compose.yml.sample > docker-compose.yml
	sed 's/PROJECTNAME/$(PROJECTNAME)/g' docker/vhosts/vhosts.conf.sample > docker/vhosts/vhosts.conf
	docker-compose up -d
	$(EXECBIS) composer create-project symfony/website-skeleton project --no-interaction
	chown -R $(SUDO_USER) ./
	touch ./project/.env.$(ENV)
	echo 'APP_ENV=$(ENV)' >> ./project/.env.$(ENV)
	echo 'DATABASE_URL=$(DATABASE_URL)' >> ./project/.env.$(ENV)
	$(COMPOSER) require vich/uploader-bundle
	$(COMPOSER) require symfony/webpack-encore-bundle
	echo $(shell docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' www_$(PROJECTNAME)_$(ENV))	$(PROJECTNAME).test >> /etc/hosts
	@$(call GREENBG,"Your project is ready at http://$(PROJECTNAME).test")
	@$(call GREENBG,"Your mailer is available at http://127.0.0.1:$(MAILPORT)")
	@$(call GREENBG,"Your PhpMyAdmin is available at http://127.0.0.1:$(PHPMYADMINPORT)")
endif

get-ip:
	docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' www_$(PROJECTNAME)_$(ENV)

write-ip:

## —— 🔥 App ——
init: ## Init the project
	$(MAKE) start
	$(MAKE) composer-install
	$(MAKE) npm-install
	@$(call GREEN,"The application is available at: http://127.0.0.1:8000/.")

cache-clear: load-config ## Clear cache
	$(SYMFONY_CONSOLE) cache:clear

## —— ✅ Test ——
.PHONY: tests
tests: load-config ## Run all tests
	$(MAKE) database-init-test
	$(PHP) bin/phpunit --testdox tests/Unit/
	$(PHP) bin/phpunit --testdox tests/Functional/
	$(PHP) bin/phpunit --testdox tests/E2E/

database-init-test: load-config ## Init database for test
	$(SYMFONY_CONSOLE) d:d:d --force --if-exists --env=test
	$(SYMFONY_CONSOLE) d:d:c --env=test
	$(SYMFONY_CONSOLE) d:m:m --no-interaction --env=test
	$(SYMFONY_CONSOLE) d:f:l --no-interaction --env=test

unit-test: load-config ## Run unit tests
	$(MAKE) database-init-test
	$(PHP) bin/phpunit --testdox tests/Unit/

functional-test: load-config ## Run functional tests
	$(MAKE) database-init-test
	$(PHP) bin/phpunit --testdox tests/Functional/

# PANTHER_NO_HEADLESS=1 ./bin/phpunit --filter LikeTest --debug to debug with Chrome
e2e-test: load-config ## Run E2E tests
	$(MAKE) database-init-test
	$(PHP) bin/phpunit --testdox tests/E2E/

## —— 🐳 Docker ——
start: load-config ## Start app
	$(MAKE) docker-start

docker-start: load-config
	docker-compose up -d

stop: load-config ## Stop app
	$(MAKE) docker-stop

docker-stop: load-config
	docker-compose stop
	@$(call RED,"The containers are now stopped.")

## —— 🎻 Composer ——
composer-install: load-config ## Install dependencies
	$(COMPOSER) install

composer-update: load-config ## Update dependencies
	$(COMPOSER) update

composer-require: load-config ## Install new bundle
	$(COMPOSER) require $(BUNDLE)

## —— 🐈 NPM —————————————————————————————————————————————————————————————————
npm-install: load-config ## Install all npm dependencies
	$(NPM) install

npm-update: load-config ## Update all npm dependencies
	$(NPM) update

npm-watch: load-config ## Update all npm dependencies
	$(NPM) run watch

## —— 📊 Database ——
database-init: load-config ## Init database
	$(MAKE) database-drop
	$(MAKE) database-create
	$(MAKE) database-migrate
	$(MAKE) database-fixtures-load

database-drop: load-config ## Create database
	$(SYMFONY_CONSOLE) d:d:d --force --if-exists

database-create: load-config ## Create database
	$(SYMFONY_CONSOLE) d:d:c --if-not-exists

database-remove: load-config ## Drop database
	$(SYMFONY_CONSOLE) d:d:d --force --if-exists

database-migration: load-config ## Make migration
	$(SYMFONY_CONSOLE) make:migration

migration: load-config ## Alias : database-migration
	$(MAKE) database-migration

database-migrate: load-config ## Migrate migrations
	$(SYMFONY_CONSOLE) d:m:m --no-interaction

migrate: load-config ## Alias : database-migrate
	$(MAKE) database-migrate

database-fixtures-load: load-config ## Load fixtures
	$(SYMFONY_CONSOLE) d:f:l --no-interaction

fixtures: load-config ## Alias : database-fixtures-load
	$(MAKE) database-fixtures-load

## —— 🛠️  Others ——
help: load-config ## List of commands
	@grep -E '(^[a-zA-Z0-9_-]+:.*?##.*$$)|(^##)' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}{printf "\033[32m%-30s\033[0m %s\n", $$1, $$2}' | sed -e 's/\[32m##/[33m/'





