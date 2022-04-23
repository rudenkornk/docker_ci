SHELL = /usr/bin/env bash

VCS_REF ?= $(shell git rev-parse HEAD)
VCS_REF := $(VCS_REF)
BUILD_DATE ?= $(shell date --rfc-3339=date)
BUILD_DATE := $(BUILD_DATE)
BUILD_DIR ?= build
BUILD_DIR := $(BUILD_DIR)
TESTS_DIR ?= tests
TESTS_DIR := $(TESTS_DIR)
CI_BIND_MOUNT ?= $(shell pwd)
CI_BIND_MOUNT := $(CI_BIND_MOUNT)
DOCKER_IMAGE_VERSION ?= 0.1.0
DOCKER_IMAGE_VERSION := $(DOCKER_IMAGE_VERSION)
DOCKER_BASE_NAME ?= docker_ci
DOCKER_BASE_NAME := $(DOCKER_BASE_NAME)
DOCKER_IMAGE_NAME := rudenkornk/$(DOCKER_BASE_NAME)
DOCKER_IMAGE_TAG := $(DOCKER_IMAGE_NAME):$(DOCKER_IMAGE_VERSION)
DOCKER_IMAGE := $(BUILD_DIR)/$(DOCKER_BASE_NAME)_image_$(DOCKER_IMAGE_VERSION)
DOCKER_CACHE_FROM ?=
DOCKER_CACHE_FROM := $(DOCKER_CACHE_FROM)
DOCKER_CONTAINER_NAME ?= $(DOCKER_BASE_NAME)_container
DOCKER_CONTAINER_NAME := $(DOCKER_CONTAINER_NAME)
DOCKER_CONTAINER := $(BUILD_DIR)/$(DOCKER_CONTAINER_NAME)_$(DOCKER_IMAGE_VERSION)
DOCKER_TEST_CONTAINER_NAME := $(DOCKER_BASE_NAME)_test_container
DOCKER_TEST_CONTAINER := $(BUILD_DIR)/$(DOCKER_TEST_CONTAINER_NAME)_$(DOCKER_IMAGE_VERSION)

DOCKER_DEPS :=
DOCKER_DEPS += Dockerfile
DOCKER_DEPS += entrypoint.sh
DOCKER_DEPS += entrypoint_usermod.sh
DOCKER_DEPS += entrypoint_continue.sh

.PHONY: $(DOCKER_IMAGE_NAME)
$(DOCKER_IMAGE_NAME): $(DOCKER_IMAGE)

.PHONY: docker_image_name
docker_image_name:
	$(info $(DOCKER_IMAGE_NAME))

.PHONY: docker_image_tag
docker_image_tag:
	$(info $(DOCKER_IMAGE_TAG))

.PHONY: docker_image_version
docker_image_version:
	$(info $(DOCKER_IMAGE_VERSION))

DOCKER_IMAGE_ID = $(shell docker images --quiet $(DOCKER_IMAGE_TAG))
DOCKER_IMAGE_CREATE_STATUS = $(shell [[ -z "$(DOCKER_IMAGE_ID)" ]] && echo "$(DOCKER_IMAGE)_not_created")
DOCKER_CACHE_FROM_COMMAND = $(shell [[ ! -z "$(DOCKER_CACHE_FROM)" ]] && echo "--cache-from $(DOCKER_CACHE_FROM)")
.PHONY: $(DOCKER_IMAGE)_not_created
$(DOCKER_IMAGE): $(DOCKER_DEPS) $(DOCKER_IMAGE_CREATE_STATUS)
	docker build \
		$(DOCKER_CACHE_FROM_COMMAND) \
		--build-arg IMAGE_NAME="$(DOCKER_IMAGE_NAME)" \
		--build-arg VERSION="$(DOCKER_IMAGE_VERSION)" \
		--build-arg VCS_REF="$(VCS_REF)" \
		--build-arg BUILD_DATE="$(BUILD_DATE)" \
		--tag $(DOCKER_IMAGE_TAG) .
	mkdir --parents $(BUILD_DIR) && touch $@

.PHONY: $(DOCKER_CONTAINER_NAME)
$(DOCKER_CONTAINER_NAME): $(DOCKER_CONTAINER)

DOCKER_CONTAINER_ID = $(shell docker container ls --quiet --all --filter name=^/$(DOCKER_CONTAINER_NAME)$)
DOCKER_CONTAINER_STATE = $(shell docker container ls --format {{.State}} --all --filter name=^/$(DOCKER_CONTAINER_NAME)$)
DOCKER_CONTAINER_RUN_STATUS = $(shell [[ "$(DOCKER_CONTAINER_STATE)" != "running" ]] && echo "$(DOCKER_CONTAINER)_not_running")
.PHONY: $(DOCKER_CONTAINER)_not_running
$(DOCKER_CONTAINER): $(DOCKER_IMAGE) $(DOCKER_CONTAINER_RUN_STATUS)
ifneq ($(DOCKER_CONTAINER_ID),)
	docker container rename $(DOCKER_CONTAINER_NAME) $(DOCKER_CONTAINER_NAME)_$(DOCKER_CONTAINER_ID)
endif
	docker run --interactive --tty --detach \
		--user ci_user \
		--env CI_UID="$$(id --user)" --env CI_GID="$$(id --group)" \
		--name $(DOCKER_CONTAINER_NAME) \
		--mount type=bind,source="$(CI_BIND_MOUNT)",target=/home/repo \
		$(DOCKER_IMAGE_TAG)
	sleep 1
	mkdir --parents $(BUILD_DIR) && touch $@

.PHONY: $(DOCKER_TEST_CONTAINER_NAME)
$(DOCKER_TEST_CONTAINER_NAME): $(DOCKER_TEST_CONTAINER)

DOCKER_TEST_CONTAINER_ID = $(shell docker container ls --quiet --all --filter name=^/$(DOCKER_TEST_CONTAINER_NAME)$)
DOCKER_TEST_CONTAINER_STATE = $(shell docker container ls --format {{.State}} --all --filter name=^/$(DOCKER_TEST_CONTAINER_NAME)$)
DOCKER_TEST_CONTAINER_RUN_STATUS = $(shell [[ "$(DOCKER_TEST_CONTAINER_STATE)" != "running" ]] && echo "$(DOCKER_TEST_CONTAINER)_not_running")
.PHONY: $(DOCKER_TEST_CONTAINER)_not_running
$(DOCKER_TEST_CONTAINER): $(DOCKER_IMAGE) $(DOCKER_TEST_CONTAINER_RUN_STATUS)
ifneq ($(DOCKER_TEST_CONTAINER_ID),)
	docker container rename $(DOCKER_TEST_CONTAINER_NAME) $(DOCKER_TEST_CONTAINER_NAME)_$(DOCKER_TEST_CONTAINER_ID)
endif
	docker run --interactive --tty --detach \
		--user ci_user \
		--env CI_UID="$$(id --user)" --env CI_GID="$$(id --group)" \
		--name $(DOCKER_TEST_CONTAINER_NAME) \
		--mount type=bind,source="$$(pwd)",target=/home/repo \
		$(DOCKER_IMAGE_TAG)
	sleep 1
	mkdir --parents $(BUILD_DIR) && touch $@

$(BUILD_DIR)/env_test: $(DOCKER_IMAGE) $(DOCKER_TEST_CONTAINER)
	docker exec \
		--user ci_user \
		$(DOCKER_TEST_CONTAINER_NAME) \
		bash -c "source ~/.profile && pwd" | grep --quiet /home/repo
	docker run \
		--user ci_user \
		--name $(DOCKER_TEST_CONTAINER_NAME)_tmp_$$RANDOM \
		$(DOCKER_IMAGE_TAG) \
		pwd | grep --quiet /home/repo
	
	mkdir --parents $(BUILD_DIR) && touch $@

$(BUILD_DIR)/ci_id_test: $(DOCKER_IMAGE) $(TESTS_DIR)/id_test.sh
	docker run \
		--user ci_user \
		--env CI_UID="1234" --env CI_GID="1432" \
		--name $(DOCKER_TEST_CONTAINER_NAME)_tmp_$$RANDOM \
		--mount type=bind,source="$$(pwd)",target=/home/repo \
		$(DOCKER_IMAGE_TAG) \
		./$(TESTS_DIR)/id_test.sh &> $(BUILD_DIR)/ci_id
	sed -n "1p" < $(BUILD_DIR)/ci_id | grep --quiet "1234:1432"
	sed -n "2p" < $(BUILD_DIR)/ci_id | grep --quiet "ci_user:ci_user"
	sed -n "3p" < $(BUILD_DIR)/ci_id | grep --quiet --invert-match "sudo"
	sed -n "3p" < $(BUILD_DIR)/ci_id | grep --quiet --invert-match "docker"
	docker run \
		--user ci_user \
		--name $(DOCKER_TEST_CONTAINER_NAME)_tmp_$$RANDOM \
		--mount type=bind,source="$$(pwd)",target=/home/repo \
		$(DOCKER_IMAGE_TAG) \
		./$(TESTS_DIR)/id_test.sh &> $(BUILD_DIR)/ci_id
	sed -n "2p" < $(BUILD_DIR)/ci_id | grep --quiet "ci_user:ci_user"
	sed -n "3p" < $(BUILD_DIR)/ci_id | grep --quiet --invert-match "sudo"
	sed -n "3p" < $(BUILD_DIR)/ci_id | grep --quiet --invert-match "docker"
	mkdir --parents $(BUILD_DIR) && touch $@

# Check we did not change host directory ownership
$(BUILD_DIR)/ownership_test: $(DOCKER_IMAGE)
	stat --format="%U:%G %n" * > $(BUILD_DIR)/file_stat
	stat --format="%U:%G %n" */* >> $(BUILD_DIR)/file_stat
	GREP_COUNT=$$(grep --count $$(id --user --name):$$(id --group --name) $(BUILD_DIR)/file_stat); \
	TOTAL_COUNT=$$(wc --lines < $(BUILD_DIR)/file_stat); \
	[[ $$GREP_COUNT == $$TOTAL_COUNT ]] || exit 1
	mkdir --parents $(BUILD_DIR) && touch $@

.PHONY: check
check: \
	$(BUILD_DIR)/env_test \
	$(BUILD_DIR)/ci_id_test \
	$(BUILD_DIR)/ownership_test \

.PHONY: clean
clean:
	docker container ls --quiet --filter name=$(DOCKER_TEST_CONTAINER_NAME)_ | \
		ifne xargs docker stop
	docker container ls --quiet --filter name=$(DOCKER_TEST_CONTAINER_NAME)_ --all | \
		ifne xargs docker rm

