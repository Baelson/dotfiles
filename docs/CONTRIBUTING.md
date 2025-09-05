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
./scripts/health-check.sh --full

# Run tests to ensure everything works
./scripts/test.sh --quick
```

## 📁 Project Structure

```
dotfiles/
├── bootstrap/                 # Core bootstrap scripts
│   ├── lib/                  # Modular function libraries
│   │   ├── common.sh         # Shared utilities and logging
│   │   ├── xcode.sh          # Xcode CLI Tools management
│   │   ├── homebrew.sh       # Homebrew installation/management
│   │   ├── packages.sh       # Package management via Brewfile
│   │   ├── chezmoi.sh        # Chezmoi configuration management
│   │   ├── macos.sh          # macOS system configuration
│   │   └── validation.sh     # System validation functions
│   ├── setup.core.sh         # Core bootstrap (Xcode, Homebrew)
│   ├── setup.macos.sh        # macOS-specific setup
│   └── verify.setup.sh       # System validation
├── scripts/                  # Utility scripts
│   ├── health-check.sh       # System health validation
│   ├── test.sh              # Test runner
│   └── run-critical-tests.sh # Pre-commit test runner
├── tests/                    # BATS test suites
│   ├── unit/                # Unit tests
│   ├── integration/         # Integration tests
│   └── system/              # System tests
└── docs/                    # Documentation
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
   ./scripts/test.sh --quick

   # Run specific functional requirement tests
   ./scripts/test.sh fr1  # For bootstrap changes
   ./scripts/test.sh fr3  # For configuration changes

   # Run all tests
   ./scripts/test.sh --all
   ```

4. **Validate system health**
   ```bash
   ./scripts/health-check.sh --full
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
./scripts/test.sh --quick

# By category
./scripts/test.sh --unit
./scripts/test.sh --integration
./scripts/test.sh --system

# By functional requirement
./scripts/test.sh fr1  # Bootstrap functionality
./scripts/test.sh fr2  # Package management
./scripts/test.sh fr3  # Configuration management
./scripts/test.sh fr4  # Shell environment
./scripts/test.sh fr5  # Application preferences
./scripts/test.sh fr6  # Environment templating
./scripts/test.sh fr7  # Debug capabilities

# With verbose output
./scripts/test.sh --all --verbose

# Install BATS if needed
./scripts/test.sh --install-bats --quick
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

### Module System
The project uses a modular architecture where functionality is organized into focused libraries:

- **`lib/common.sh`**: Shared utilities, logging, error handling
- **`lib/xcode.sh`**: Xcode CLI Tools management
- **`lib/homebrew.sh`**: Homebrew installation and configuration
- **`lib/packages.sh`**: Package management via Brewfile
- **`lib/chezmoi.sh`**: Chezmoi configuration management
- **`lib/macos.sh`**: macOS system configuration
- **`lib/validation.sh`**: System validation functions

### Adding New Functions
1. **Choose the appropriate module** based on functionality
2. **Follow the existing patterns**:
   ```bash
   # Function documentation
   function_name() {
       debug_trace "→ Entering: function_name"

       # Function body

       debug_trace "← Exiting: function_name"
   }
   ```
3. **Add validation functions** if applicable
4. **Update module documentation** at the top of the file

### Error Handling
- Use `debug_trace` for function entry/exit logging
- Use `log_error`, `log_warning`, `log_success` for user feedback
- Always provide actionable error messages
- Use `return 0` for success, `return 1` for failure

## 🐛 Debugging and Troubleshooting

### Common Issues

#### Script Execution Problems
```bash
# Check script syntax
bash -n bootstrap/setup.core.sh

# Run with debug output
./bootstrap/setup.core.sh --debug-verbose

# Check system health
./scripts/health-check.sh --full
```

#### Test Failures
```bash
# Run specific failing test with verbose output
./scripts/test.sh --verbose fr1

# Check test helper syntax
bash -n tests/lib/test_helper.bash

# Run tests with debug output
./scripts/test.sh --debug --all
```

#### Module Loading Issues
```bash
# Check module syntax
bash -n bootstrap/lib/common.sh

# Test module loading
source bootstrap/lib/common.sh
```

### Debug Modes
The bootstrap scripts support multiple debug levels:

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
- [ ] All tests pass (`./scripts/test.sh --all`)
- [ ] Health check passes (`./scripts/health-check.sh --full`)
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
- **Health Check**: Run `./scripts/health-check.sh --full`
- **Test Results**: Run `./scripts/test.sh --all --verbose`
- **Issue Tracking**: Check `docs/OPEN_ISSUES.md`

### Best Practices
- **Start small**: Make incremental changes
- **Test frequently**: Run tests after each change
- **Document decisions**: Update relevant documentation
- **Ask questions**: Better to ask than to break things

## 📋 Development Checklist

Before submitting changes:

- [ ] Code follows project patterns and style
- [ ] All tests pass (`./scripts/test.sh --all`)
- [ ] Health check passes (`./scripts/health-check.sh --full`)
- [ ] Documentation is updated
- [ ] Debug logging is appropriate
- [ ] Error handling is comprehensive
- [ ] Commit message follows conventional format
- [ ] Changes are tested on a clean system (if possible)

---

**Happy contributing!** 🎉

Remember: This is a personal dotfiles repository, but the architecture and patterns are designed to be educational and adaptable. Your contributions help make this a better reference for dotfile management best practices.
