IMAGE ?= pssa-lint:latest
DOCKERFILE ?= Dockerfile.psscriptanalyzer

.PHONY: build run-lint lint rebuild clean lifecycle full-lifecycle

build:
	docker build --pull -f $(DOCKERFILE) -t $(IMAGE) .

rebuild:
	docker build --pull --no-cache -f $(DOCKERFILE) -t $(IMAGE) .

run-lint:
	docker run --rm -v "$$(pwd):/workspace" $(IMAGE)

lint: build run-lint

lifecycle: lint

full-lifecycle: clean rebuild run-lint

clean:
	-docker image rm $(IMAGE)
