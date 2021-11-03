# define some defaults https://tech.davis-hansson.com/p/make/
SHELL := bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules

DOCKER_COMPOSE ?= /usr/local/bin/docker-compose

DOCKER_REPO := fbartels
APP_VERSION := $(shell jq -r .version CloudronManifest.json)
CLOUDRON_APP ?= id
CLOUDRON_ID := $(shell jq -r .id CloudronManifest.json)
CLOUDRON_SERVER ?= my.9wd.eu
CLOUDRON_TOKEN ?=123

VCS_REF := $(shell git rev-parse --short HEAD)
TAG := $(shell date '+%Y%m%d%H%M%S')

IDM_VERSION := $(shell git -C idm describe)
LICO_VERSION := $(shell git -C lico describe)
KWEB_VERSION := $(shell git -C kweb describe)

.PHONY: build
build:
# for more caching this should specify --cache-to=type=registry,mode=max. but its not supported with the docker driver
ifeq (,$(wildcard ./.netrc))
	touch .netrc
endif
	docker buildx build --platform linux/amd64 --rm \
		--build-arg IDM_VERSION=$(IDM_VERSION) \
		--build-arg LICO_VERSION=$(LICO_VERSION) \
		--build-arg KWEB_VERSION=$(KWEB_VERSION) \
		--build-arg VCS_REF=$(VCS_REF) \
		--cache-from $(DOCKER_REPO)/cloudron-id:ci \
		-t $(DOCKER_REPO)/cloudron-id:latest .
	docker tag $(DOCKER_REPO)/cloudron-id:latest $(DOCKER_REPO)/cloudron-id:$(APP_VERSION)-$(TAG)

# some things like openid will not work locally because of missing https
.PHONY: test-local
test-local:
	$(DOCKER_COMPOSE) -f docker-compose.yml up

.PHONY: test-enter
test-enter:
	$(DOCKER_COMPOSE) -f docker-compose.yml exec cloudron-id bash

.PHONY: test-version
test-version:
	docker run --rm $(DOCKER_REPO)/cloudron-id cat /app/pkg/.version

.PHONY: update-submodules
update-submodules:
	git submodule foreach bash ../update-submodules.sh

.PHONY: publish
publish: build
	docker push $(DOCKER_REPO)/cloudron-id:$(APP_VERSION)-$(TAG)

.PHONY: publish-latest
publish-latest: publish
	docker push $(DOCKER_REPO)/cloudron-id:latest

.PHONY: update
update: build publish
	cloudron update --app ${CLOUDRON_APP} --image $(DOCKER_REPO)/cloudron-id:$(APP_VERSION)-$(TAG)

.PHONY: update-ci
update-ci:
	cloudron update --server ${CLOUDRON_SERVER} --image $(DOCKER_REPO)/cloudron-id:$(APP_VERSION)-$(TAG) --token ${CLOUDRON_TOKEN} --app ${CLOUDRON_APP}

.PHONY: install
install: publish
	cloudron install --location ${CLOUDRON_APP} --image $(DOCKER_REPO)/cloudron-id:$(APP_VERSION)-$(TAG)

.PHONY: uninstall
uninstall:
	cloudron uninstall --app ${CLOUDRON_APP}

.PHONY: install-debug
install-debug:
	cloudron install --location ${CLOUDRON_APP} --debug

.PHONY: exec
exec:
	cloudron exec --app ${CLOUDRON_APP}

.PHONY: logs
logs:
	cloudron logs -f --app ${CLOUDRON_APP}
