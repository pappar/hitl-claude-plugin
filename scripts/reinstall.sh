#!/usr/bin/env bash
# HITL plugin clean reinstall.
#
# Removes any hitl-dev-platform clones registered as plugins, cleans up
# project hook wrappers, installs the latest marketplace version, and
# tells you what to do next.
#
# Usage (run from your project directory):
#   bash reinstall.sh
#
# Or via curl (no clone needed):
#   bash <(curl -fsSL https://raw.githubusercontent.com/pappar/hitl-claude-plugin/main/scripts/reinstall.sh)

set -euo pipefail

BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()    { echo -e "${BLUE}▶ $*${NC}"; }
ok()      { echo -e "${GREEN}✓ $*${NC}"; }
warn()    { echo -e "${YELLOW}⚠ $*${NC}"; }
err()     { echo -e "${RED}✗ $*${NC}" >&2; }

CLAUDE_SETTINGS="$HOME/.claude/settings.json"
PROJECT_DIR="$(pwd)"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  HITL plugin — clean reinstall"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ── Step 1: Remove hitl-dev-platform clone paths from ~/.claude/settings.json ──
info "Checking ~/.claude/settings.json for clone-based plugin entries..."

if [[ -f "$CLAUDE_SETTINGS" ]]; then
  REMOVED=$(python3 - "$CLAUDE_SETTINGS" <<'PYEOF'
import json, sys

path = sys.argv[1]
with open(path) as f:
    data = json.load(f)

plugins = data.get("plugins", [])
before = len(plugins)

def is_clone(p):
    p = p if isinstance(p, str) else p.get("path", "")
    # Clone-based entry: references hitl-dev-platform source layout
    return "hitl-dev-platform" in p

kept   = [p for p in plugins if not is_clone(p)]
removed = [p if isinstance(p, str) else p.get("path", "") for p in plugins if is_clone(p)]

data["plugins"] = kept
with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")

for r in removed:
    print(r)
PYEOF
  )

  if [[ -n "$REMOVED" ]]; then
    while IFS= read -r entry; do
      ok "Removed plugin entry: $entry"
    done <<< "$REMOVED"
  else
    ok "No clone-based plugin entries found"
  fi
else
  warn "~/.claude/settings.json not found — skipping"
fi

# ── Step 2: Remove hitl-dev-platform clone directories ─────────────────────
info "Looking for hitl-dev-platform clone directories to remove..."

FOUND_CLONES=0
for candidate in \
  "$HOME/Projects/hitl-dev-platform" \
  "$HOME/tools/hitl-dev-platform" \
  "$HOME/code/hitl-dev-platform" \
  "$HOME/dev/hitl-dev-platform" \
  "$HOME/hitl-dev-platform"; do
  if [[ -d "$candidate" ]]; then
    warn "Found clone: $candidate"
    read -r -p "    Delete it? [y/N] " answer
    if [[ "${answer,,}" == "y" ]]; then
      rm -rf "$candidate"
      ok "Deleted $candidate"
    else
      warn "Skipped — you can delete it manually later"
    fi
    FOUND_CLONES=1
  fi
done

if [[ $FOUND_CLONES -eq 0 ]]; then
  ok "No hitl-dev-platform clone directories found"
fi

# ── Step 3: Clean project hook wrappers ────────────────────────────────────
info "Cleaning project hook wrappers in: $PROJECT_DIR"

if [[ -d "$PROJECT_DIR/.hitl/hooks" ]]; then
  rm -rf "$PROJECT_DIR/.hitl/hooks"
  ok "Removed .hitl/hooks/"
else
  ok ".hitl/hooks/ not present — nothing to remove"
fi

if [[ -f "$PROJECT_DIR/.claude/settings.json" ]]; then
  rm -f "$PROJECT_DIR/.claude/settings.json"
  ok "Removed .claude/settings.json"
else
  ok ".claude/settings.json not present — nothing to remove"
fi

# ── Step 4: Bust plugin catalog cache ─────────────────────────────────────
# The catalog cache (plugin-catalog-cache.json) can hold a stale marketplace_sha
# for days, causing `claude plugin update` to see the old commit and skip the
# update silently. Deleting it forces Claude Code to fetch a fresh catalog.
info "Clearing plugin catalog cache..."
CATALOG_CACHE="$HOME/.claude/plugins/plugin-catalog-cache.json"
if [[ -f "$CATALOG_CACHE" ]]; then
  rm -f "$CATALOG_CACHE"
  ok "Deleted plugin-catalog-cache.json (will re-fetch on next plugin command)"
else
  ok "No catalog cache found — nothing to clear"
fi

# Remove stale hitl marketplace entries pointing at local/tmp paths.
# These were registered by earlier dev installs and will never resolve to the
# latest release. The fresh `marketplace add` below registers the correct source.
MARKETPLACES_FILE="$HOME/.claude/plugins/known_marketplaces.json"
if [[ -f "$MARKETPLACES_FILE" ]]; then
  REMOVED_MKT=$(python3 - "$MARKETPLACES_FILE" <<'PYEOF'
import json, sys
path = sys.argv[1]
with open(path) as f:
    data = json.load(f)
stale = [k for k, v in data.items()
         if 'hitl' in k.lower()
         and v.get('source', {}).get('source') in ('directory', 'local')]
for k in stale:
    del data[k]
    print(k)
with open(path, 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
PYEOF
  )
  if [[ -n "$REMOVED_MKT" ]]; then
    while IFS= read -r entry; do
      ok "Removed stale local marketplace entry: $entry"
    done <<< "$REMOVED_MKT"
  else
    ok "No stale local hitl marketplace entries found"
  fi
fi

# ── Step 5: Install latest plugin via marketplace ──────────────────────────
info "Installing latest HITL plugin from marketplace..."

if ! command -v claude &>/dev/null; then
  err "'claude' not found on PATH. Install Claude Code first."
  exit 1
fi

claude plugin marketplace add pappar/hitl-claude-plugin
claude plugin install hitl@hitl

ok "Plugin installed"

# ── Done ───────────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${GREEN}Clean reinstall complete.${NC}"
echo ""
echo "Next steps:"
echo "  1. Restart Claude Code"
echo "  2. Open your project and run the command that matches your situation:"
echo "       New project (from a PRD)     → /hitl:dev-start-from-prd"
echo "       Existing codebase            → /hitl:dev-start-brownfield"
echo "       Migrating / rewriting        → /hitl:dev-start-migration"
echo "     Step 0 will wire up hooks automatically."
echo "  3. Restart Claude Code again"
echo "  4. The HITL breadcrumb will appear on your first prompt"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
