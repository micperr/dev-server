.DEFAULT_GOAL := help
help:
	@grep -E '(^[a-zA-Z_-]+:.*?##.*$$)|(^##)' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}{printf "\033[32m%-30s\033[0m %s\n", $$1, $$2}' | sed -e 's/\[32m##/[33m/'

install: venv dist build ## Do everything

venv: ## Install python virtual environment
	python3 -m venv .venv
	.venv/bin/pip3 install --upgrade pip -r requirements.txt

dist: dist-exists ## Derive config files from .dist examples
	test -f .env || cp config/dist/.env.dist .env
	test -f config/docker-compose.template.yml || cp config/dist/docker-compose.template.yml.dist config/docker-compose.template.yml
	# test -f config/sites.yml || cp config/dist/sites.yml.dist config/sites.yml

build: ## Build server
	./.venv/bin/python server.py build

dist-exists: config/dist/.env.dist config/dist/docker-compose.template.yml.dist config/dist/sites.yml.dist
