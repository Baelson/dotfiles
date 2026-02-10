# Troubleshooting Guide

This guide helps you diagnose and resolve common issues with the macOS System and Environment Setup (macSES) system.

## 🚨 Quick Diagnostics

### Run Health Check First
```bash
# Quick system health check
./scripts/health-check.sh --quick

# Comprehensive health check
./scripts/health-check.sh --full

# Health check with auto-fix attempts
./scripts/health-check.sh --fix
```

### Check System Status
```bash
# Verify bootstrap scripts work
./setup/setup.core.sh --dry-run

# Check validation
./bootstrap/verify.setup.sh

# Run tests
./scripts/test/test.sh --quick
```

---

## 🔧 Common Issues and Solutions

### Bootstrap Script Issues

#### ❌ "Script failed at line X with exit code Y"
**Symptoms**: Script terminates with line number and exit code
**Causes**: Network issues, permission problems, missing dependencies
**Solutions**:
```bash
# Check network connectivity
ping github.com

# Verify permissions
ls -la setup/setup.core.sh

# Run with debug output
./setup/setup.core.sh --debug-verbose

# Check for missing dependencies
./scripts/health-check.sh --full
```

#### ❌ "Repository clone failed"
**Symptoms**: Cannot clone the dotfiles repository
**Causes**: SSH key issues, network problems, repository access
**Solutions**:
```bash
# Test SSH connection
ssh -T git@github.com

# Check SSH keys
ls -la ~/.ssh/

# Try HTTPS fallback (automatic in script)
# Or manually clone
git clone https://github.com/Baelson/dotfiles.git ~/Git/dotfiles
```

#### ❌ "Xcode CLI Tools installation failed"
**Symptoms**: Xcode CLI Tools installation hangs or fails
**Causes**: Network issues, user interaction required, system problems
**Solutions**:
```bash
# Check if already installed
xcode-select --print-path

# Manual installation
xcode-select --install

# Reset if corrupted
sudo xcode-select --reset

# Check system requirements
sw_vers
```

#### ❌ "Homebrew installation failed"
**Symptoms**: Homebrew installation script fails
**Causes**: Network issues, permission problems, existing installation conflicts
**Solutions**:
```bash
# Check network
curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh

# Check permissions
ls -la /opt/homebrew /usr/local

# Manual installation
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Fix permissions if needed
sudo chown -R $(whoami) /opt/homebrew
```

### Package Management Issues

#### ❌ "Brewfile installation failed"
**Symptoms**: `brew bundle` fails to install packages
**Causes**: Package conflicts, network issues, authentication problems
**Solutions**:
```bash
# Check Homebrew status
brew doctor

# Update Homebrew
brew update

# Check specific package
brew install <package-name>

# Check Mac App Store authentication
mas account

# Sign in to Mac App Store if needed
open -a "App Store"
```

#### ❌ "Package not found" or "Cask not found"
**Symptoms**: Homebrew cannot find a package or cask
**Causes**: Typo in package name, package removed, tap not added
**Solutions**:
```bash
# Search for correct package name
brew search <package-name>

# Check available casks
brew search --cask <package-name>

# Update package database
brew update

# Check taps
brew tap
```

### Configuration Management Issues

#### ❌ "Chezmoi apply failed"
**Symptoms**: `chezmoi apply` fails to apply configurations
**Causes**: Permission issues, file conflicts, missing dependencies
**Solutions**:
```bash
# Check chezmoi status
chezmoi doctor

# Dry run to see what would happen
chezmoi apply --dry-run

# Check for conflicts
chezmoi diff

# Reset if needed
chezmoi unapply
chezmoi apply
```

#### ❌ "External archives not downloaded"
**Symptoms**: Antigen, Oh My Zsh, or Dircolors not found
**Causes**: Network issues, chezmoi configuration problems
**Solutions**:
```bash
# Check chezmoi external configuration
cat .chezmoiexternal.toml

# Force download external archives
chezmoi apply --force

# Check network connectivity
curl -I https://github.com

# Manual download if needed
mkdir -p ~/.local/share
git clone https://github.com/zsh-users/antigen.git ~/.local/share/antigen
```

### Shell Environment Issues

#### ❌ "Zsh not working properly"
**Symptoms**: Shell prompt issues, plugins not loading, configuration errors
**Causes**: Oh My Zsh issues, Antigen problems, configuration conflicts
**Solutions**:
```bash
# Check zsh configuration
zsh -c "echo 'Zsh is working'"

# Check Oh My Zsh
ls -la ~/.oh-my-zsh

# Check Antigen
ls -la ~/.local/share/antigen

# Reload configuration
source ~/.zshrc

# Check for syntax errors
zsh -n ~/.zshrc
```

#### ❌ "Powerlevel10k not working"
**Symptoms**: Prompt not styled, configuration not applied
**Causes**: Installation issues, configuration problems
**Solutions**:
```bash
# Check Powerlevel10k installation
ls -la ~/.p10k.zsh

# Check Oh My Zsh theme
grep ZSH_THEME ~/.zshrc

# Reconfigure Powerlevel10k
p10k configure

# Check font installation
# Install recommended fonts: https://github.com/romkatv/powerlevel10k#meslo-nerd-font-patched-for-powerlevel10k
```

### Testing Issues

#### ❌ "BATS tests failing"
**Symptoms**: Test suite fails to run or individual tests fail
**Causes**: BATS not installed, test environment issues, script problems
**Solutions**:
```bash
# Install BATS
brew install bats-core

# Check BATS installation
bats --version

# Run tests with verbose output
./scripts/test/test.sh --all --verbose

# Run specific test category
./scripts/test/test.sh --unit
./scripts/test/test.sh --integration
./scripts/test/test.sh --system

# Check test helper
bash -n tests/lib/test_helper.bash
```

#### ❌ "Pre-commit hooks failing"
**Symptoms**: Git commits blocked by pre-commit hooks
**Causes**: Test failures, linting issues, script problems
**Solutions**:
```bash
# Run pre-commit manually
pre-commit run --all-files

# Skip hooks temporarily (not recommended)
git commit --no-verify

# Fix specific issues
./scripts/run-critical-tests.sh

# Check pre-commit configuration
cat .pre-commit-config.yaml
```

---

## 🔍 Advanced Debugging

### Debug Modes

#### Bootstrap Script Debugging
```bash
# Dry run (preview without executing)
./setup/setup.core.sh --dry-run

# Trace mode (show control flow)
./setup/setup.core.sh --debug-trace

# Verbose mode (detailed execution)
./setup/setup.core.sh --debug-verbose

# Combined modes
./setup/setup.core.sh --dry-run --debug-verbose
```

#### Test Debugging
```bash
# Run tests with TAP output
./scripts/test/test.sh --debug --all

# Run specific test with verbose output
bats --verbose tests/system/test_fr1_bootstrap.bats

# Run single test
bats tests/system/test_fr1_simple.bats
```

### Log Analysis

#### Check Log Files
```bash
# Bootstrap logs
ls -la ~/Git/*.log

# Performance logs (if debug-verbose was used)
cat /tmp/dotfiles_performance.log

# System logs
tail -f /var/log/system.log

# Homebrew logs
brew config
brew doctor
```

#### Environment Variables
```bash
# Check important environment variables
echo "REPO_DIR: $REPO_DIR"
echo "LOG_DIR: $LOG_DIR"
echo "DEBUG_TRACE: $DEBUG_TRACE"
echo "DEBUG_VERBOSE: $DEBUG_VERBOSE"
echo "DRY_RUN: $DRY_RUN"
```

### System Information

#### Gather System Info
```bash
# macOS version
sw_vers

# Architecture
uname -m

# Shell information
echo $SHELL
zsh --version

# Homebrew information
brew --version
brew config

# Git information
git --version
git config --list
```

---

## 🆘 Emergency Recovery

### If Everything is Broken

#### Complete Reset
```bash
# Backup current state
cp -r ~/Git/dotfiles ~/Git/dotfiles.backup.$(date +%Y%m%d)

# Remove current installation
rm -rf ~/Git/dotfiles

# Fresh clone and setup
git clone https://github.com/Baelson/dotfiles.git ~/Git/dotfiles
cd ~/Git/dotfiles
./setup/setup.core.sh
```

#### Partial Recovery
```bash
# Check what's working
./scripts/health-check.sh --full

# Fix specific components
# Xcode CLI Tools
xcode-select --install

# Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Chezmoi
brew install chezmoi
chezmoi apply
```

### If Scripts Won't Run

#### Manual Recovery Steps
1. **Check basic tools**:
   ```bash
   which curl git zsh bash
   ```

2. **Install missing dependencies**:
   ```bash
   # Xcode CLI Tools
   xcode-select --install

   # Homebrew
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

3. **Clone repository manually**:
   ```bash
   mkdir -p ~/Git
   cd ~/Git
   git clone https://github.com/Baelson/dotfiles.git
   cd dotfiles
   ```

4. **Run setup manually**:
   ```bash
   ./setup/setup.core.sh
   ./bootstrap/setup.macos.sh
   ```

---

## 📞 Getting Help

### Before Asking for Help

1. **Run health check**: `./scripts/health-check.sh --full`
2. **Check logs**: Look for error messages in log files
3. **Try debug modes**: Use `--debug-verbose` flags
4. **Search this guide**: Look for similar issues above
5. **Check documentation**: Review `docs/` directory

### Information to Include

When reporting issues, please include:

- **macOS version**: `sw_vers`
- **Architecture**: `uname -m`
- **Error messages**: Full error output
- **Health check results**: `./scripts/health-check.sh --full`
- **Debug output**: `./setup/setup.core.sh --debug-verbose`
- **Steps to reproduce**: What you did before the error

### Resources

- **Documentation**: `docs/` directory
- **Health Check**: `./scripts/health-check.sh`
- **Test Suite**: `./scripts/test/test.sh`
- **Issue Tracking**: `docs/OPEN_ISSUES.md`

---

## 🎯 Prevention Tips

### Best Practices

1. **Always run health checks** before making changes
2. **Use dry-run mode** to preview operations
3. **Keep backups** of working configurations
4. **Test changes** on a separate system if possible
5. **Read error messages** carefully - they often contain solutions

### Regular Maintenance

```bash
# Weekly health check
./scripts/health-check.sh --full

# Update Homebrew packages
brew update && brew upgrade

# Check for system updates
softwareupdate -l

# Verify configuration
chezmoi doctor
```

---

**Remember**: Most issues can be resolved by running the health check script and following the suggested fixes. The system is designed to be robust and self-healing where possible.
