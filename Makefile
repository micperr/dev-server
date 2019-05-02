.DEFAULT_GOAL := help
help:
	@grep -E '(^[a-zA-Z_-]+:.*?##.*$$)|(^##)' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}{printf "\033[32m%-30s\033[0m %s\n", $$1, $$2}' | sed -e 's/\[32m##/[33m/'


build: dir-vars-passed dist-copy ## Build server, "--mount" and "--volume" required
	./.venv/bin/python server.py build --mount ${mount} --volume ${volume}

dist-copy: dist-exist ## Derive config files from .dist examples
	cp config/dist/.env.dist config/.env
	cp config/dist/docker-compose.template.yml.dist config/docker-compose.template.yml
	cp config/dist/sites.yml.dist config/sites.yml


dist-exist: config/dist/.env.dist config/dist/docker-compose.template.yml.dist config/dist/sites.yml.dist

dir-vars-passed:
ifndef mount
	$(error mount is undefined)
endif
ifndef volume
	$(error volume is undefined)
endif
