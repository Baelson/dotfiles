# Testing

What's tested in this repo, and how to run it.

## Layers

| Layer | What it asserts | Runs in |
|---|---|---|
| **Unit** (`tests/unit/`) | Source-tree invariants; template rendering; Brewfile syntax; security/secrets file shape; static checks on `setup.sh`. | Local; CI. |
| **Integration** (`tests/integration/`) | BDD-style "Given/When/Then" tests that render templates with chezmoi and assert on the output. Covers package management, configuration, shell env, application preferences, and lifecycle scripts. | Local; CI. |
| **System (VM)** (manual + `scripts/vm/run-e2e.sh`) | The whole bootstrap end-to-end on a clean macOS VM. The only layer that proves the recipe works on a fresh machine, not just that the ingredients are valid. | Local (Tart on Apple Silicon). |

## Run the test suite

```bash
# Full suite (~124 tests after Phase 5A scrub of vmctl-related tests)
bats tests/unit/ tests/integration/

# Unit only
bats tests/unit/

# Integration only (BDD)
bats tests/integration/

# Single file
bats tests/unit/test_bootstrap_install.bats
```

Fast subset for pre-commit (configured in `.pre-commit-config.yaml`):

```bash
scripts/test/run-critical-tests.sh
```

## Test framework

- **bats-core** for shell tests. Helpers live in `tests/lib/`:
  - `test_helper.bash` — sets `DOTFILES_ROOT`, `DOTFILES_SOURCE_DIR`,
    `BOOTSTRAP_SCRIPT`, etc. Sourced by every test file.
  - `behavioral_helpers.bash` — `assert_template_renders <tmpl> [key=value ...]`
    + `assert_rendered_contains` / `assert_rendered_excludes`. The
    convention for new integration tests.
- **shellcheck** runs in pre-commit on `.bash` files and (via
  `scripts/test/shellcheck-templates.sh`) on rendered chezmoi templates.

## VM end-to-end

The only test layer that proves the bootstrap actually works on a
fresh machine. BATS tests validate templates render and files exist;
they don't catch issues like a `.chezmoiignore` pattern silently
blocking an external download or a TCC-protected `defaults write` call
aborting on a fresh VM.

**Manifest**: `tests/infrastructure/verify-manifest.txt` — line-oriented
post-bootstrap assertions (file exists / is dir / contains substring /
command exits zero). The orchestrator reads this after a successful
`setup.sh` run on the guest VM.

**Orchestrator**: `scripts/vm/run-e2e.sh` (lands via Phase 5x feature-
branch merge — see "Known temporary state" in README). The previous
matrix-driven `vmctl.sh` / `vm-matrix.sh` were removed in Phase 5A
(they had been broken since the legacy `setup.sh` deletion in
ISSUE-019).

Until `run-e2e.sh` lands, run the manual recipe (clone a `tart`
checkpoint, scp `setup.sh` to the guest, run via SSH). The recipe lives
in the project's internal docs.

## What's not covered

- **Real Homebrew installs** — the unit tests mock `brew` to keep tests
  hermetic. Cask/formula availability changes (taps moving, formulae
  renaming) only surface in VM E2E.
- **Real macOS defaults writes** — same. Some `defaults write` calls
  hit TCC-protected domains that fail without Full Disk Access; the
  scripts wrap these in `if ... 2>/dev/null`-style guards, but the
  guards' behavior is only verified in VM E2E.
- **Real age decryption** — encrypted file decryption is exercised
  with PATH-injected fakes in unit tests. Real decryption with the
  staged Keychain identity is only validated in VM E2E.

The pre-commit "Run Critical FR Tests" hook deliberately runs the full
unit + integration suite to catch the things templates can validate; a
green pre-commit doesn't substitute for a VM E2E pass on changes to
lifecycle scripts, `.chezmoiignore`, or `.chezmoi.toml.tmpl`.
