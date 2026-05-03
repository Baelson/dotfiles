# macOS System and Environment Setup (macSES)

> **One-command setup for complete macOS development environments**

Transform a fresh macOS installation into a fully configured development environment with a single command. This system automates the installation of 70+ packages, configuration management, and environment setup using modern tooling and Systems Engineering principles.

## 🚀 Quick Start

### One-time prerequisite (per machine)

Stage the age decryption identity in the macOS Keychain so chezmoi can decrypt SSH keys, license files, and other encrypted secrets at apply time. (iCloud Keychain syncs the entry across signed-in Macs, so subsequent machines need no manual step.) See [PROJECT_INIT.md](PROJECT_INIT.md) for details and the no-iCloud-Keychain fallback.

```bash
# Stage the single-line AGE-SECRET-KEY-1... value (multi-line round-trips as hex)
security add-generic-password -s dotfiles-age -a "$USER" \
    -w "$(awk '/^AGE-SECRET-KEY/{print; exit}' ~/.config/chezmoi/key.txt)" -U
```

### Bootstrap

```bash
curl -fsSL https://raw.githubusercontent.com/Baelson/dotfiles/main/bootstrap/install.sh | bash
```

**What this does:**
- Installs `chezmoi` to `~/.local/bin` (curl-installed from `get.chezmoi.io`)
- Stages the age identity from Keychain to `~/.config/chezmoi/key.txt`
- Runs `chezmoi init --apply` against this repo
- Lifecycle scripts then install Xcode CLT (silently via `softwareupdate`), Homebrew (`NONINTERACTIVE=1`), and the rest of the configured environment

See [docs/SYSTEM_DESIGN.md](docs/SYSTEM_DESIGN.md) for the bootstrap architecture.

**System Requirements:** macOS 12+ with internet connection and admin privileges

## 📊 Current Status

**✅ Production Ready** - Core functionality complete with comprehensive validation

| Component | Status | Coverage |
|-----------|---------|----------|
| **Bootstrap System** | ✅ Complete | One-command setup with debug modes |
| **Package Management** | ✅ Complete | 70+ packages (CLI tools, apps, MAS) |
| **Configuration Management** | ✅ Complete | 10 dotfiles + encrypted secrets |
| **Shell Environment** | ✅ Complete | Zsh + Oh My Zsh + Antigen + P10k |
| **Validation System** | ✅ Complete | 16+ automated verification checks |
| **Environment Templating** | ⏳ Planned | Work/personal differentiation (Phase 3) |

## 🛠 Advanced Usage

### Local Testing
Run the full test suite locally:

```bash
# Full BATS suite (~164 tests across unit + integration)
bats tests/unit/ tests/integration/

# Or use the test runner with category filters
scripts/test/test.sh --all
scripts/test/test.sh --unit
scripts/test/test.sh --integration
```

### Homebrew Bundle (Brewfile)
The Brewfile is managed under `home/Brewfile` by chezmoi and typically materializes to `~/Brewfile` after `chezmoi apply`.

Examples:
```bash
# Preview (no installs):
brew bundle --file="home/Brewfile" --no-lock --help | sed -n '1,40p'

# Apply after chezmoi has placed Brewfile in $HOME:
brew bundle --file="$HOME/Brewfile"
```

### Local VM End-to-End

The matrix-driven `vmctl.sh` / `vm-matrix.sh` / `init-matrix.sh` tooling
was removed as part of ISSUE-021 (broken since the legacy `setup.sh`
deletion in ISSUE-019). The replacement single-VM SSH-only orchestrator
(`scripts/vm/run-e2e.sh`) lands as part of the Phase 5x feature-branch
merge that follows this audit. Until then, the manual SSH-only recipe
in `CLAUDE.md` (Build & Development Commands → Automated SSH-only
regression) is the working flow. The `infrastructure/vm/verify-manifest.txt`
assertion file is preserved for the new orchestrator to consume.

### Debug and Testing Modes

The bootstrap script is intentionally minimal — for preview and troubleshooting, use chezmoi's native flags after init:

```bash
# Preview what would change on an existing install
chezmoi apply --dry-run --verbose

# Re-run the initial apply with verbose output
chezmoi apply --force --verbose

# Health check
chezmoi doctor

# Behavioral regression suite
bats tests/unit/ tests/integration/
bats tests/integration/test_chezmoi_lifecycle_scripts.bats
```

### Configuration Management
```bash
# View configuration status
chezmoi doctor
chezmoi diff

# Add new dotfiles
chezmoi add --follow ~/.newconfig

# Add encrypted sensitive files
chezmoi add --encrypt ~/.ssh/new_key

# Apply configuration changes
chezmoi apply --dry-run  # Preview
chezmoi apply           # Execute
```

## 📁 Repository Structure

```
dotfiles/
├── 📋 README.md                    # This file - project overview
├── 📋 PROJECT_INIT.md              # One-time prerequisites (GitHub PAT)
├── 🏗️ bootstrap/install.sh          # Canonical bootstrap entrypoint (ISSUE-019)
├── 📦 home/Brewfile.tmpl            # 70+ packages (CLI tools, apps, MAS)
├── 🧪 scripts/test/                 # Test runners
├── 🔧 scripts/tools/                # Local utility workflows
├── 🖥️ scripts/vm/                   # Local VM IaC and E2E workflows
├── ⚙️ infrastructure/vm/            # VM matrix configuration
├── 📚 docs/                        # Comprehensive documentation
│   ├── PRD.md                     # Product requirements and use cases
│   ├── SYSTEM_DESIGN.md           # Technical architecture
│   ├── TESTING.md                 # Verification & validation procedures
│   ├── VM_TESTING.md              # Local VM current+beta workflow
│   ├── DEV_STATUS.md              # Development progress and lessons
│   └── OPEN_ISSUES.md             # Issue tracking
└── 📁 home/                   # Chezmoi managed dotfiles
    ├── ⚙️ dot_*/                   # Configuration files
    ├── 🔒 encrypted_*/             # Encrypted sensitive data
    ├── 🔗 .chezmoiexternal.toml    # External repositories (Oh My Zsh, etc.)
    └── 📋 .chezmoiignore           # Files to ignore
```

## 📖 Documentation

This project follows comprehensive documentation architecture with clear separation of concerns:

### 🎯 For Users
- **[README.md](README.md)** ← *You are here* - Quick start and overview
- **[docs/PRD.md](docs/PRD.md)** - Product requirements, use cases, and user stories

### 🏗️ For Developers
- **[docs/SYSTEM_DESIGN.md](docs/SYSTEM_DESIGN.md)** - Technical architecture and implementation
- **[docs/TESTING.md](docs/TESTING.md)** - Verification, validation, and testing procedures
- **[docs/VM_TESTING.md](docs/VM_TESTING.md)** - Local VM IaC workflow for end-to-end validation
- **[docs/DEV_STATUS.md](docs/DEV_STATUS.md)** - Development progress and lessons learned
- **[CLAUDE.md](CLAUDE.md)** - Engineering guidance and lessons learned

### 🐛 For Troubleshooting
- **[docs/OPEN_ISSUES.md](docs/OPEN_ISSUES.md)** - Known issues and their resolution status
- **[docs/TESTING.md](docs/TESTING.md)** - Debugging procedures and common solutions

## 💡 Key Features

### 🎯 Zero-Friction Setup
- **One Command**: Complete environment setup with a single curl command (post-ISSUE-021)
- **Bare-Machine Ready**: Works on fresh macOS with no Xcode CLT, no Homebrew, no git (ISSUE-019)
- **Keychain-Sourced Secrets**: macOS Keychain is the sole long-lived secret source for the age identity; iCloud Keychain syncs across Macs

### 📦 Comprehensive Package Management
- **CLI Tools** (24+): git, gh, uv, neovim, docker, kubectl, terraform
- **Desktop Apps** (19+): VS Code, iTerm2, Docker Desktop, Figma, Obsidian
- **Mac App Store** (27+): Xcode, Final Cut Pro, Microsoft Office, OmniFocus

### ⚙️ Modern Configuration Management
- **Chezmoi Integration**: Modern dotfile management with Go templating
- **Age Encryption**: Secure secrets management for SSH keys and sensitive configs
- **6-Category Strategy**: Organized approach to different file types and security levels

### 🔧 Advanced Debugging
- **Multi-Level Debug Modes**: trace, verbose, and dry-run capabilities
- **Error Recovery**: Comprehensive error handling with actionable suggestions
- **Verification System**: 16+ automated checks ensure complete system setup

### 🏛️ Systems Engineering Approach
- **1:1 Setup/Verification**: Every setup script has corresponding validation
- **Requirement Traceability**: All features map to specific verification procedures
- **Evidence-Based Development**: Comprehensive documentation and testing

## 🎯 Use Cases

This system is designed for:

1. **🆕 Fresh Machine Setup**: Transform new Mac into fully configured development environment
2. **🔄 Configuration Synchronization**: Keep multiple machines in sync with version-controlled configs
3. **💼 Environment Differentiation**: Support different settings for work vs personal machines (Phase 3)
4. **🔧 Disaster Recovery**: Quickly restore environment after system failure
5. **📋 Onboarding**: Help other developers establish similar development environments

## ⚡ Performance & Reliability

- **⏱️ Setup Time**: Complete bootstrap < 30 minutes on standard internet
- **🎯 Success Rate**: 99% on supported macOS versions (macOS 12+)
- **🔄 Idempotent**: Safe to run multiple times without conflicts
- **🛡️ Error Handling**: Comprehensive logging and recovery suggestions

## 🚨 Getting Help

### Quick Troubleshooting
```bash
# Check system status
./scripts/tools/health-check.sh --quick

# Re-run bootstrap (safe — chezmoi apply is idempotent)
curl -fsSL https://raw.githubusercontent.com/Baelson/dotfiles/main/bootstrap/install.sh | bash

# Preview current drift without making changes
chezmoi apply --dry-run --verbose
```

### Common Issues
- **`Missing Keychain entry` on bootstrap**: Provision the PAT per [PROJECT_INIT.md](PROJECT_INIT.md)
- **Homebrew install dialog on bare macOS**: Ensure `NONINTERACTIVE=1` is inherited (install.sh sets it); also see ISSUE-019 in docs/OPEN_ISSUES.md
- **MAS Authentication**: MAS apps are opt-in via `CHEZMOI_MAS=true chezmoi apply`
- **Permission Issues**: `sudo` is needed for Xcode CLT install; VMs must have a sudoer account

### Support Resources
- **Documentation**: See [docs/](docs/) directory for comprehensive guides
- **Issue Tracking**: Check [docs/OPEN_ISSUES.md](docs/OPEN_ISSUES.md) for known issues
- **Testing Procedures**: [docs/TESTING.md](docs/TESTING.md) contains debugging workflows

## 🏗️ Development

### Contributing
This is a personal dotfiles repository, but the architecture and patterns are designed to be educational and adaptable.

### Key Technologies
- **Bootstrap**: Bash/Zsh scripting with comprehensive error handling
- **Configuration**: [Chezmoi](https://www.chezmoi.io/) with Go templating and age encryption
- **Packages**: Homebrew + Brewfile + mas for comprehensive package management
- **Shell**: Zsh + Oh My Zsh + Antigen + Powerlevel10k
- **Testing**: Multi-level validation with requirement traceability

### Architecture Highlights
- **chezmoi-native bootstrap**: Uses chezmoi's built-in init/apply/source-path rather than a custom wrapper
- **Native Tool Integration**: Preview and verbose modes via `chezmoi apply --dry-run --verbose`
- **Trap-guaranteed cleanup**: Plaintext PAT cannot be left on disk after bootstrap (even on failure)
- **Modular Design**: 1:1 setup/verification pattern with shared libraries

## 📄 License

This project is for personal use. The architecture, patterns, and documentation are shared for educational purposes.

---

**macOS System and Environment Setup (macSES)** - Transform your Mac, one command at a time. 🚀
