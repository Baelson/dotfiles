# XDG Base Directory Migration Plan

## Overview
Migrate dot directories from `$HOME` to appropriate XDG Base Directory locations to reduce clutter and follow standards.

## XDG Base Directory Specification

### Core Directories
- `XDG_CONFIG_HOME` = `~/.config` (configuration files)
- `XDG_DATA_HOME` = `~/.local/share` (application data)
- `XDG_CACHE_HOME` = `~/.cache` (cache files)
- `XDG_RUNTIME_DIR` = `/run/user/$UID` (runtime files)

## Migration Targets

### High Priority (Easy Migration)
| Current | Target | Type | Notes |
|---------|--------|------|-------|
| `~/.antigen/` | `~/.config/antigen/` | Config | Zsh plugin manager |
| `~/.cisco/` | `~/.config/cisco/` | Config | Cisco tools |
| `~/.claude/` | `~/.config/claude/` | Config | Claude AI settings |
| `~/.cursor/` | `~/.config/cursor/` | Config | Cursor IDE settings |
| `~/.docker/` | `~/.config/docker/` | Config | Docker settings |
| `~/.iterm2/` | `~/.config/iterm2/` | Config | iTerm2 settings |

### Medium Priority (May Need App Configuration)
| Current | Target | Type | Notes |
|---------|--------|------|-------|
| `~/.npm/` | `~/.local/share/npm/` | Data | Node.js packages |
| `~/.oh-my-zsh/` | `~/.local/share/oh-my-zsh/` | Data | Zsh framework |

### Already XDG Compliant ✅
- `~/.cache/` - Already in correct location
- `~/.config/` - Already in correct location  
- `~/.local/` - Already in correct location

### Special Cases (Symlinks)
- `~/.ipython/` → Already symlinked to Mackup
- `~/.jupyter/` → Already symlinked to Mackup
- `~/.mackup/` → Already symlinked to Mackup

## Migration Strategy

### Phase 1: Research Application Support
For each application, check if it supports XDG directories:

```bash
# Example research commands
man application-name
application-name --help | grep -i config
application-name --help | grep -i xdg
```

### Phase 2: Test Migration
1. Create backup of current directory
2. Move directory to XDG location
3. Test application functionality
4. Rollback if issues occur

### Phase 3: Update Environment Variables
Set XDG environment variables in shell configuration:

```bash
# Add to ~/.zshrc
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"
```

### Phase 4: Create Symlinks (if needed)
For applications that don't support XDG but you want to organize:

```bash
# Example: Move .antigen to .config and symlink back
mv ~/.antigen ~/.config/antigen
ln -s ~/.config/antigen ~/.antigen
```

## Implementation Script

```bash
#!/bin/bash
# xdg-migration.sh

# Backup function
backup_dir() {
    local src="$1"
    local backup="${src}.backup.$(date +%Y%m%d_%H%M%S)"
    if [ -d "$src" ]; then
        echo "Backing up $src to $backup"
        cp -r "$src" "$backup"
    fi
}

# Migration function
migrate_config() {
    local app="$1"
    local src="$HOME/.$app"
    local target="$HOME/.config/$app"
    
    if [ -d "$src" ] && [ ! -L "$src" ]; then
        echo "Migrating $app..."
        backup_dir "$src"
        mkdir -p "$(dirname "$target")"
        mv "$src" "$target"
        ln -s "$target" "$src"
        echo "✅ $app migrated to $target"
    fi
}

# Execute migrations
migrate_config "antigen"
migrate_config "cisco"
migrate_config "claude"
migrate_config "cursor"
migrate_config "docker"
migrate_config "iterm2"
```

## Benefits of Migration

1. **Reduced Clutter**: Fewer dot directories in `$HOME`
2. **Standard Compliance**: Follows XDG Base Directory spec
3. **Better Organization**: Clear separation of config vs data
4. **Easier Backup**: Can backup config separately from data
5. **Cross-Platform**: Consistent with Linux systems

## Risks and Considerations

1. **Application Compatibility**: Some apps may not support XDG
2. **Symlink Complexity**: May need to maintain symlinks
3. **Backup Strategy**: Need to update backup scripts
4. **Documentation**: Update any documentation referencing old paths

## Next Steps

1. Research each application's XDG support
2. Create test environment for migration
3. Implement migration script
4. Update environment variables
5. Test all applications thoroughly
6. Update backup and documentation
