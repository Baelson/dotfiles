- When defining CLI arguments for scripts/tools, always provide a short single letter option along with a more verbose option (e.g. curl -fsSL is equivalent to curl --fail --silent --show-error --location).
- When you are calling/shelling out to other scripts and tools from within a script, always use the more verbose command line options on multiple lines. Each verbose option should have a comment at the end that either describes the option if it is not obvious from the name or provides concise rational why that option is used. In a comment before that script or tool call, provide the equivalent single line CLI call that is functionally equivalent to the verbose option.

E.g. Instead of the below:
```
# Install Homebrew using the official installer
/bin/zsh -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
    log_error "Failed to install Homebrew"
    exit 1
}
```

Do the following instead:
```
# Install Homebrew using the official installer
# single-line CLI: `/bin/zsh -c "$(curl -fsSL ${HOMEBREW_INSTALL_SCRIPT})"
/bin/zsh -c "$(curl \
    --fail \       # HTTP error response content suppressed and exits with non-zero shell status 
    --silent \     # Suppress progress, transfer stats
    --show-error \ # Show error messages (overrides --silent behavior that also suppresses errors)
    --location \   # Enables following redirects (e.g. HTTP Status Codes 301, 302, etc.)
    ${HOMEBREW_INSTALL_SCRIPT} || {
    log_error "Failed to install Homebrew"
    exit 1
}
```
- Do not delete any git branches, even smaller fix/* branches; If there is a mistake or clutter, suggest it and allow me to explicity ask you to git branch -d.
- Always remember to exclude OS system files from git (e.g. .DS_Store). Double check online for common, well-known, and documented exclusions to .gitignore
- When authoring scripts/code that is not dependent on the order of functions in a file, keep the "main()" function near the top of the code/script so it's easy to get an overview of the logic and flow. All subsequent functions should come after that.