CURRENT_DIR := $(shell pwd)

list:
	@echo "\n==========================="
	@echo "==    Swift Scripting    =="
	@echo "==========================="
	@echo "==     Commands list     =="
	@echo "==========================="
	@echo "build"
	@echo "build_and_run"
	@echo "tests"

build:
	@swift build --configuration release
	@cp -f .build/release/XcodeGroupSync ./XcodeGroupSync

build_and_run:
	@make build
	@./XcodeGroupSync

test:
	@swift test