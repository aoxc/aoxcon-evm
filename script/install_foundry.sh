#!/usr/bin/env bash
set -Eeuo pipefail

# AOXCORE Foundry Installer
# - Idempotent installation/update helper for Foundry (forge/cast/anvil/chisel)
# - Supports Linux and macOS
# - Verifies toolchain and prints actionable warnings

log()  { printf '[INFO] %s\n' "$*"; }
ok()   { printf '[OK] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
err()  { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || err "Required command not found: $1"
}

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

OS="$(uname -s || true)"
case "$OS" in
  Linux|Darwin) ;;
  *) err "Unsupported OS: $OS (expected Linux or macOS)" ;;
esac

# 1) Basic prerequisites
need_cmd bash
need_cmd curl
need_cmd git

if ! has_cmd ca-certificates && [ "$OS" = "Linux" ]; then
  warn "ca-certificates package may be missing. HTTPS downloads may fail."
fi

# 2) Ensure foundryup exists
if ! has_cmd foundryup; then
  log "foundryup not found. Installing via https://foundry.paradigm.xyz"
  if ! curl -A "Mozilla/5.0" -fsSL https://foundry.paradigm.xyz | bash; then
    warn "Primary installer endpoint failed. Trying GitHub raw fallback for foundryup."
    mkdir -p "$HOME/.foundry/bin"
    if ! curl -A "Mozilla/5.0" -fsSL       https://raw.githubusercontent.com/foundry-rs/foundry/master/foundryup/foundryup       -o "$HOME/.foundry/bin/foundryup"; then
      err "Unable to download foundryup (both primary and fallback endpoints failed). Check outbound network/proxy/firewall rules."
    fi
    chmod +x "$HOME/.foundry/bin/foundryup"
  fi
else
  ok "foundryup already installed"
fi

# 3) Load profile path for this shell session
# shellcheck disable=SC1090
if [ -f "$HOME/.bashrc" ]; then
  source "$HOME/.bashrc" || true
fi
# shellcheck disable=SC1090
if [ -f "$HOME/.zshrc" ]; then
  source "$HOME/.zshrc" || true
fi
export PATH="$HOME/.foundry/bin:$PATH"

has_cmd foundryup || err "foundryup still not available. Re-open shell or add ~/.foundry/bin to PATH."

# 4) Install/Update stable Foundry toolchain
log "Installing/updating stable Foundry toolchain"
foundryup

# 5) Verify all expected binaries
for bin in forge cast anvil chisel; do
  if has_cmd "$bin"; then
    ok "$("$bin" --version | head -n1)"
  else
    err "Expected binary missing after installation: $bin"
  fi
done

# 6) Optional dependency hints for this repository
if [ -f "foundry.toml" ]; then
  ok "foundry.toml detected in current directory"
else
  warn "No foundry.toml in current directory. If this is a monorepo, cd into the Foundry project root."
fi

if [ -d "lib" ]; then
  for dep in lib/forge-std lib/openzeppelin-contracts lib/openzeppelin-contracts-upgradeable; do
    if [ -d "$dep" ] && [ -z "$(find "$dep" -mindepth 1 -maxdepth 1 2>/dev/null || true)" ]; then
      warn "$dep exists but is empty. Run: git submodule update --init --recursive"
    fi
  done
fi

ok "Foundry installation and verification completed successfully."
