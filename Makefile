.PHONY: ci test precommit help

help:
	@echo "Targets:"
	@echo "  ci         Run pre-commit and full BATS (local CI)"
	@echo "  test       Run full BATS suite"
	@echo "  precommit  Run pre-commit on all files"

ci:
	./scripts/ci-local.sh

test:
	./scripts/test.sh --all

precommit:
	pre-commit run --all-files
