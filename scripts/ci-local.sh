#!/usr/bin/env bash
#
# Local CI Orchestrator
# Runs the same core checks as GitHub Actions: pre-commit and full Bats suite.
# Safe to run repeatedly; installs missing tools via Homebrew when available.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "[ci-local] Repo: $ROOT_DIR"
cd "$ROOT_DIR"

need() { command -v "$1" >/dev/null 2>&1; }

ensure_tool() {
  local tool="$1" homebrew_pkg="${2:-}"
  if ! need "$tool"; then
    echo "[ci-local] Missing: $tool"
    if need brew && [[ -n "$homebrew_pkg" ]]; then
      echo "[ci-local] Installing via Homebrew: $homebrew_pkg"
      brew install "$homebrew_pkg"
    else
      echo "[ci-local] Please install '$tool' manually." >&2
      return 1
    fi
  fi
}

echo "[ci-local] Checking prerequisites..."
ensure_tool bats bats-core
ensure_tool pre-commit pre-commit || true  # optional

echo "[ci-local] Running pre-commit hooks (all files)..."
if need pre-commit; then
  pre-commit run --all-files
else
  echo "[ci-local] pre-commit not installed; skipping hooks"
fi

echo "[ci-local] Running full Bats suite..."
chmod +x "$SCRIPT_DIR/test.sh" || true
"$SCRIPT_DIR/test.sh" --all

echo "[ci-local] ✅ All checks completed"
