.PHONY: build
build:
	docker image build -t textlint-articles:latest .

.PHONY: lint
lint:
	docker container run --rm -v ${PWD}:/app textlint-articles:latest 

