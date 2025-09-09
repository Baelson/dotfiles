# Repository Guidelines

This repository manages a macOS developer environment using chezmoi-managed dotfiles, setup scripts, and a Bats-based test suite. Follow these guidelines to contribute safely and consistently.

## Project Structure & Module Organization
- `desired_state/`: Source of truth for dotfiles managed by chezmoi (e.g., `dot_zshrc`, `dot_config/...`, `private_*/`, `encrypted_*.age`). Never commit decrypted secrets.
- `setup/`: Machine setup and verification scripts (e.g., `setup.macos.sh`, `verify.macos.sh`).
- `scripts/`: Helper automation (e.g., `test.sh`, `run-critical-tests.sh`, `health-check.sh`).
- `tests/`: Bats tests organized by `unit/`, `integration/`, `system/` (e.g., `tests/system/test_fr1_bootstrap.bats`).
- `docs/`: Developer docs (e.g., `TESTING.md`, `CONTRIBUTING.md`, `TROUBLESHOOTING.md`).

## Build, Test, and Development Commands
- `./bootstrap.sh`: One-line installer that hands off to `setup/`.
- `scripts/test.sh`: Runs the full Bats suite.
- `scripts/run-critical-tests.sh`: Executes high-signal smoke/critical tests.
- `scripts/health-check.sh`: Quick repo health/prereq check.
- `scripts/validate-test-setup.sh`: Verifies local Bats setup.
- Examples: `bats tests/unit`, `bats tests/integration/test_fr2_package_management.bats`.

## Coding Style & Naming Conventions
- Shell: Prefer POSIX-compatible shell, `set -euo pipefail`; 2-space indentation.
- Names: lowercase with hyphens for scripts (e.g., `performance-check.sh`); functions `snake_case`.
- Chezmoi: keep `desired_state/` names consistent: `dot_*`, `private_*`, `encrypted_*.age`.
- Formatting/Linting (recommended): `shfmt -i 2 -ci`, `shellcheck` before committing.

## Testing Guidelines
- Framework: Bats; name tests `test_*.bats` and place in `unit/`, `integration/`, or `system/` as appropriate.
- Principles: idempotent, hermetic, and safe on a developer laptop and CI.
- Run locally: `scripts/test.sh` or target a file/dir with `bats`.

## Commit & Pull Request Guidelines
- Commit style: Conventional-ish types appear in history (e.g., `FEAT:`, `FIX:`, `DOCS:`, `CHORE:`, `SECURITY:`, `MAJOR:`). Use imperative subjects and include context in the body; link issues.
- PRs: describe intent, scope, risk, and test coverage; include logs/screenshots where helpful; call out affected paths (e.g., `desired_state/`, `setup/`).

## Security & Configuration Tips
- Keep secrets encrypted (`*.age`); never commit decrypted content.
- Changes to `private_*` paths should be minimal and justified.
- When in doubt, update `docs/` and add/adjust tests to cover behavior.
