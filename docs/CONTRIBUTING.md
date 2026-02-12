# Contributing to macOS System and Environment Setup (macSES)

Thank you for your interest in contributing to this dotfiles project! This guide will help you understand the development workflow, testing procedures, and best practices for making changes.

## 🚀 Quick Start for Contributors

### Prerequisites
- macOS 12+ (for testing)
- Git
- Homebrew (for installing development tools)
- Basic familiarity with shell scripting (Bash/Zsh)

### Initial Setup
```bash
# Clone the repository
git clone https://github.com/Baelson/dotfiles.git
cd dotfiles

# Install development dependencies
brew install bats-core

# Run health check to verify setup
./scripts/tools/health-check.sh --full

# Run tests to ensure everything works
./scripts/test/test.sh --quick
```

## 📁 Project Structure

```
dotfiles/
├── setup.sh                         # One-command bootstrap entrypoint
├── home/                            # Chezmoi source-of-truth files
├── scripts/
│   ├── test/                        # Test workflows
│   │   ├── test.sh
│   │   ├── run-critical-tests.sh
│   │   └── validate-test-setup.sh
│   ├── tools/                       # Local utility workflows
│   │   ├── health-check.sh
│   │   ├── ci-local.sh
│   │   └── performance-check.sh
│   └── vm/                          # Local VM IaC workflows
├── infrastructure/vm/               # VM matrix config
├── tests/                           # BATS suites (unit/integration/system)
└── docs/                            # Documentation
```

## 🔧 Development Workflow

### Making Changes

1. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes**
   - Follow the existing code style and patterns
   - Add appropriate debug logging
   - Update documentation if needed

3. **Test your changes**
   ```bash
   # Run quick tests
   ./scripts/test/test.sh --quick

   # Run specific functional requirement tests
   ./scripts/test/test.sh fr1  # For setup changes
   ./scripts/test/test.sh fr3  # For configuration changes

   # Run all tests
   ./scripts/test/test.sh --all
   ```

4. **Validate system health**
   ```bash
   ./scripts/tools/health-check.sh --full
   ```

5. **Commit and push**
   ```bash
   git add .
   git commit -m "feat: add your feature description"
   git push origin feature/your-feature-name
   ```

### Testing Guidelines

#### Test Categories
- **Unit Tests** (`tests/unit/`): Test individual functions and modules
- **Integration Tests** (`tests/integration/`): Test component interactions
- **System Tests** (`tests/system/`): Test end-to-end functionality

#### Running Tests
```bash
# Quick test subset (fastest)
./scripts/test/test.sh --quick

# By category
./scripts/test/test.sh --unit
./scripts/test/test.sh --integration
./scripts/test/test.sh --system

# By functional requirement
./scripts/test/test.sh fr1  # Bootstrap functionality
./scripts/test/test.sh fr2  # Package management
./scripts/test/test.sh fr3  # Configuration management
./scripts/test/test.sh fr4  # Shell environment
./scripts/test/test.sh fr5  # Application preferences
./scripts/test/test.sh fr6  # Environment templating
./scripts/test/test.sh fr7  # Debug capabilities

# With verbose output
./scripts/test/test.sh --all --verbose

# Install BATS if needed
./scripts/test/test.sh --install-bats --quick
```

#### Running Local VM End-to-End Tests
```bash
# Initialize local matrix (gitignored)
./scripts/vm/init-matrix.sh

# Validate host prerequisites and matrix config
./scripts/vm/vmctl.sh --action doctor

# Plan and execute current + beta workflows
./scripts/vm/vm-matrix.sh --action plan
./scripts/vm/vm-matrix.sh --action run-e2e --dry-run
```

#### Writing New Tests
1. **Choose the right category**:
   - Unit tests for individual functions
   - Integration tests for component interactions
   - System tests for end-to-end scenarios

2. **Follow naming conventions**:
   - `test_fr[1-7]_[description].bats`
   - Use descriptive test names

3. **Use the test helper**:
   ```bash
   # At the top of your test file
   load '../lib/test_helper'

   setup() {
       setup_common
   }

   teardown() {
       cleanup_common
   }
   ```

4. **Test structure**:
   ```bash
   @test "FR-X.Y: Description of what is being tested" {
       # Arrange
       local expected="expected_value"

       # Act
       run your_function

       # Assert
       assert_bootstrap_success
       [[ "$output" =~ $expected ]]
   }
   ```

## 🏗️ Code Architecture

### Runtime Model
- **Bootstrap entrypoint**: `setup.sh` handles one-shot setup, dry-run, and debug flows.
- **Configuration source**: `home/` is the chezmoi source-of-truth for managed files and templates.
- **Lifecycle execution**: `home/.chezmoiscripts/darwin/` applies package install, shell setup, and macOS defaults.
- **Test harness**: `scripts/test/` orchestrates BATS suites in `tests/unit`, `tests/integration`, and `tests/system`.
- **Local tooling**: `scripts/tools/` and `scripts/vm/` support health checks, local CI, and VM-based end-to-end runs.

### Extending the System
1. Put behavior changes in `setup.sh` or chezmoi lifecycle templates under `home/.chezmoiscripts/darwin/`.
2. Add/update BATS coverage in the appropriate `tests/*` suite.
3. Keep workflow scripts executable and documented in `docs/`.
4. Validate locally with `./scripts/test/test.sh --all` before committing.

### Error Handling
- Use explicit exit codes and actionable messages.
- Prefer `set -euo pipefail` in shell scripts.
- Keep dry-run paths functional for safe local verification.

## 🐛 Debugging and Troubleshooting

### Common Issues

#### Script Execution Problems
```bash
# Check script syntax
zsh -n setup.sh

# Run with debug output
./setup.sh --debug-verbose

# Check system health
./scripts/tools/health-check.sh --full
```

#### Test Failures
```bash
# Run specific failing test with verbose output
./scripts/test/test.sh --verbose fr1

# Check test helper syntax
bash -n tests/lib/test_helper.bash

# Run tests with debug output
./scripts/test/test.sh --debug --all
```

#### Module Loading Issues
```bash
# Check module syntax
zsh -n setup.sh

# Test module loading
./setup.sh --help
```

### Debug Modes
The setup scripts support multiple debug levels:

- `--dry-run`: Preview operations without executing
- `--debug-trace`: Show control flow and decision points
- `--debug-verbose`: Show detailed execution including variables

## 📝 Documentation Standards

### Code Documentation
- **Function headers**: Describe purpose, parameters, return values
- **Inline comments**: Explain complex logic
- **Debug logging**: Use consistent `debug_trace` patterns

### Documentation Files
- **README.md**: User-facing quick start and overview
- **docs/PRD.md**: Product requirements and use cases
- **docs/SYSTEM_DESIGN.md**: Technical architecture
- **docs/TESTING.md**: Testing procedures and validation
- **docs/DEV_STATUS.md**: Development progress and lessons learned
- **docs/CONTRIBUTING.md**: This file - development workflow

### Commit Messages
Follow conventional commit format:
- `feat:` New features
- `fix:` Bug fixes
- `docs:` Documentation changes
- `test:` Test additions or changes
- `refactor:` Code refactoring
- `chore:` Maintenance tasks

## 🔍 Code Review Process

### Pre-commit Checklist
- [ ] All tests pass (`./scripts/test/test.sh --all`)
- [ ] Health check passes (`./scripts/tools/health-check.sh --full`)
- [ ] Code follows existing patterns and style
- [ ] Documentation is updated if needed
- [ ] Debug logging is appropriate
- [ ] Error handling is comprehensive

### Review Criteria
- **Functionality**: Does it work as intended?
- **Testing**: Are there appropriate tests?
- **Documentation**: Is it well-documented?
- **Error Handling**: Are errors handled gracefully?
- **Performance**: Is it efficient?
- **Maintainability**: Is it easy to understand and modify?

## 🚨 Emergency Procedures

### If Bootstrap Scripts Break
1. **Don't panic** - the scripts are designed to be safe
2. **Check the logs** - look for error messages
3. **Run health check** - identify what's broken
4. **Use dry-run mode** - preview fixes before applying
5. **Rollback if needed** - git can restore previous versions

### If Tests Fail
1. **Run with verbose output** - get detailed failure information
2. **Check test environment** - ensure BATS and dependencies are installed
3. **Isolate the failure** - run specific test categories
4. **Check for environmental issues** - CI vs local differences

## 🤝 Getting Help

### Resources
- **Documentation**: Check the `docs/` directory
- **Health Check**: Run `./scripts/tools/health-check.sh --full`
- **Test Results**: Run `./scripts/test/test.sh --all --verbose`
- **Issue Tracking**: Check `docs/OPEN_ISSUES.md`

### Best Practices
- **Start small**: Make incremental changes
- **Test frequently**: Run tests after each change
- **Document decisions**: Update relevant documentation
- **Ask questions**: Better to ask than to break things

## 📋 Development Checklist

Before submitting changes:

- [ ] Code follows project patterns and style
- [ ] All tests pass (`./scripts/test/test.sh --all`)
- [ ] Health check passes (`./scripts/tools/health-check.sh --full`)
- [ ] Documentation is updated
- [ ] Debug logging is appropriate
- [ ] Error handling is comprehensive
- [ ] Commit message follows conventional format
- [ ] Changes are tested on a clean system (if possible)

---

**Happy contributing!** 🎉

Remember: This is a personal dotfiles repository, but the architecture and patterns are designed to be educational and adaptable. Your contributions help make this a better reference for dotfile management best practices.
