# Local CI Setup Guide

This guide provides step-by-step instructions for setting up and using the local CI/CD testing infrastructure.

## Prerequisites

### 1. Install Required Tools

```bash
# Install BATS testing framework
brew install bats-core

# Install pre-commit framework (optional but recommended)
pip install pre-commit

# Install act for local GitHub Actions testing (optional)
brew install act

# Install ShellCheck for linting (used by pre-commit)
brew install shellcheck
```

### 2. Verify Installation

```bash
# Verify BATS installation
bats --version
# Expected: Bats 1.12.0 (or newer)

# Verify other tools
pre-commit --version
act --version
shellcheck --version
```

## Local Testing

### Running BATS Tests

**Important**: Always run tests from the repository root directory (`/Users/baelson/Git/dotfiles`)

```bash
# Navigate to repository root
cd /Users/baelson/Git/dotfiles

# Run all tests
bats tests/**/*.bats

# Run specific test suite
bats tests/system/test_fr1_bootstrap.bats
bats tests/integration/test_fr2_package_management.bats

# Run with verbose output
bats tests/system/test_fr1_bootstrap.bats --verbose-run

# Run specific test by name filter
bats tests/system/test_fr7_debug_capabilities.bats --filter "FR-7.1"

# Count tests without running
bats tests/ --count
```

### Test Categories

```
tests/
├── system/                      # End-to-end system tests
│   ├── test_fr1_bootstrap.bats      # FR-1: One-Command Bootstrap (10 tests)
│   └── test_fr7_debug_capabilities.bats # FR-7: Debug Capabilities (18 tests)
├── integration/                 # Cross-component tests
│   ├── test_fr2_package_management.bats # FR-2: Package Management (10 tests)
│   ├── test_fr3_configuration_management.bats # FR-3: Configuration (12 tests)
│   ├── test_fr4_shell_environment.bats # FR-4: Shell Environment (15 tests)
│   └── test_fr5_application_preferences.bats # FR-5: App Preferences (14 tests)
└── unit/                        # Individual component tests
    └── test_fr6_environment_templating.bats # FR-6: Templating (14 tests)
```

**Total**: 93 automated tests across all functional requirements

## Pre-commit Hooks Setup

### 1. Install Pre-commit Hooks

```bash
# From repository root
cd /Users/baelson/Git/dotfiles

# Install the hooks
pre-commit install

# Run hooks manually on all files
pre-commit run --all-files

# Run hooks on specific files
pre-commit run --files tests/system/test_fr1_bootstrap.bats
```

### 2. What the Pre-commit Hooks Do

- **ShellCheck Linting**: Validates all shell scripts for syntax and best practices
- **Critical Tests**: Runs subset of BATS tests for quick validation
- **Performance Check**: Validates bootstrap dry-run completes in < 120 seconds
- **Syntax Validation**: Checks test helper and bootstrap script syntax
- **File Formatting**: Trailing whitespace, end-of-file fixes, YAML validation

### 3. Pre-commit Hook Scripts

```bash
# Run critical tests only (faster feedback)
./scripts/run-critical-tests.sh

# Run performance validation
./scripts/performance-check.sh

# Validate complete test setup
./scripts/validate-test-setup.sh
```

## Local GitHub Actions Testing with act

### 1. Setup act

```bash
# Install act
brew install act

# Verify installation
act --version

# List available workflows
act --list
```

### 2. Run GitHub Actions Locally

```bash
# Run the entire CI pipeline locally
act pull_request

# Run specific jobs
act pull_request -j setup-validation
act pull_request -j test-fr7-debug-matrix
act pull_request -j test-functional-requirements

# Run with specific event data
act pull_request --eventpath .github/workflows/test-event.json

# Dry run (show what would be executed)
act pull_request --dry-run
```

### 3. Create Test Event File (Optional)

```bash
# Create .github/workflows/test-event.json
{
  "pull_request": {
    "number": 1,
    "head": {
      "ref": "feature/phase2.5-ci-cd-pipeline"
    },
    "base": {
      "ref": "main"
    }
  }
}
```

## Understanding Test Results

### BATS Output Format

```bash
# Standard TAP output
1..10
ok 1 FR-1.1: setup.core.sh executes without errors in dry-run mode
ok 2 FR-1.2: Bootstrap provides clear progress feedback
not ok 3 FR-1.8: Dry-run shows complete setup plan
# (in test file tests/system/test_fr1_bootstrap.bats, line 101)
#   `[[ "$output" =~ "Xcode" ]] && ((components_found++))' failed
```

### Test Status Indicators

- ✅ **ok**: Test passed
- ❌ **not ok**: Test failed
- **#**: Comments showing failure location and reason

### Common Test Issues and Solutions

| Issue | Symptoms | Solution |
|-------|----------|----------|
| **Wrong Directory** | `cd: tests/system: No such file or directory` | Run from `/Users/baelson/Git/dotfiles` root |
| **BATS Not Found** | `command not found: bats` | Install with `brew install bats-core` |
| **Test Timeouts** | Test hangs or times out | Check for infinite loops, use `--timeout` |
| **Permission Errors** | Scripts not executable | Run `chmod +x scripts/*.sh` |

## Performance Testing

### Timing Validation

```bash
# Manual performance test
time ./setup/setup.core.sh --dry-run --debug-verbose

# Automated performance validation
./scripts/performance-check.sh

# Expected: Dry-run completes in < 120 seconds
```

## CI/CD Integration Verification

### Local Test Before Push

```bash
# 1. Run critical tests
bats tests/system/test_fr1_bootstrap.bats

# 2. Run performance check
./scripts/performance-check.sh

# 3. Run pre-commit validations
pre-commit run --all-files

# 4. (Optional) Run full local CI with act
act pull_request -j setup-validation
```

### GitHub Actions Status

Once you push to a PR, the GitHub Actions workflow will:

1. **Setup Validation**: Install BATS and verify repository structure
2. **FR-7 Matrix Testing**: Run 18 command-line argument variations
3. **Functional Requirements**: Test all FR-1 through FR-7
4. **Performance Integration**: Validate timing and benchmarks
5. **Security Quality**: Run ShellCheck, secret scanning
6. **Test Summary**: Generate PR comment with results

## Troubleshooting

### Test Environment Issues

```bash
# Reset test environment
rm -rf /tmp/bats-*
unset TEST_MODE DRY_RUN_TESTS DEBUG_TESTS

# Verify test helper
bash -n tests/lib/test_helper.bash

# Check file permissions
ls -la scripts/
chmod +x scripts/*.sh
```

### BATS Common Issues

```bash
# If tests show syntax errors
bash -n tests/system/test_fr1_bootstrap.bats

# If load paths fail
export BATS_TEST_DIRNAME="$(pwd)/tests/system"
export DOTFILES_ROOT="$(pwd)"

# Debug test execution
BATS_VERBOSE_RUN=1 bats tests/system/test_fr1_bootstrap.bats
```

## Next Steps

1. **Start with Basic Testing**: Run `bats tests/system/test_fr1_bootstrap.bats`
2. **Set Up Pre-commit**: Run `pre-commit install`
3. **Test Performance**: Run `./scripts/performance-check.sh`
4. **Create a PR**: Push changes and verify GitHub Actions workflow

The local CI infrastructure provides comprehensive testing capabilities that mirror the GitHub Actions pipeline, enabling fast feedback and reliable validation before pushing changes.
## Local CI Runner (No GitHub Actions)

Run the same core checks locally without incurring Actions minutes:

```bash
# From repo root
./scripts/ci-local.sh
```

What it does:
- Ensures `bats` and optionally `pre-commit` are installed (via Homebrew if present)
- Runs `pre-commit run --all-files`
- Runs the full BATS suite via `scripts/test/test.sh --all`

Tip: Add a shell alias `ci=./scripts/ci-local.sh` for convenience.

### Optional: Short aliases for make-based CI

To add `ci`, `t` (tests), and `pc` (pre-commit) shortcuts:

```bash
echo "source \"$(pwd)/scripts/dev-aliases.sh\"" >> "$HOME/.zshrc"
```
