#!/usr/bin/env bash
# Build the hitl-claude-plugin from hitl-dev-platform source.
#
# Usage:
#   ./scripts/build.sh [SOURCE_DIR]
#
# SOURCE_DIR defaults to the sibling directory ../hitl-dev-platform.
# Override it if your local checkout is elsewhere:
#   HITL_SOURCE_DIR=/path/to/hitl-dev-platform ./scripts/build.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_DIR="${HITL_SOURCE_DIR:-${1:-$PLUGIN_DIR/../hitl-dev-platform}}"

if [[ ! -d "$SOURCE_DIR/ai/claude" ]]; then
  echo "ERROR: hitl-dev-platform not found at: $SOURCE_DIR" >&2
  echo "  Set HITL_SOURCE_DIR or pass the path as the first argument." >&2
  exit 1
fi

echo "Building from: $SOURCE_DIR"
echo "Into:          $PLUGIN_DIR"
echo ""

# ── Skills ────────────────────────────────────────────────────────────────────
# Source layout: ai/claude/<skill>/SKILL.md (flat for dev) or ai/claude/<role>/<skill>/SKILL.md
# Plugin layout: skills/dev/<skill>/ for developer skills; skills/<role>/<skill>/ for role skills
# Special remaps: dev-practices → dev/practices, migrate/review-external-docs → dev/review-external-docs
echo "Syncing skills..."

# Remove stale flat dev skill dirs — they move under skills/dev/
for stale_dir in \
  apply-change check-conventions conclude dev-practices generate-docs \
  impact-brief migrate review-security start-brownfield start-migration \
  start-prd tdd; do
  rm -rf "$PLUGIN_DIR/skills/$stale_dir"
done

remap_skill_path() {
  local rel="$1"
  case "$rel" in
    dev-practices/*)                echo "dev/practices/${rel#dev-practices/}" ;;
    migrate/review-external-docs/*) echo "dev/review-external-docs/${rel#migrate/review-external-docs/}" ;;
    architect/*|pm/*|qa/*|ops/*)    echo "$rel" ;;
    *)                              echo "dev/$rel" ;;
  esac
}

find "$SOURCE_DIR/ai/claude" \( -name "SKILL.md" -o -name "*.md" \) \
  ! -path "*/agents/*" ! -path "*/commands/*" ! -path "*/hooks/*" \
  ! -path "*/plugin/*" ! -path "*/shared/*" \
  ! -path "*/generate-docs/templates/*" \
  ! -name "README.md" | while read -r src; do
  rel="${src#$SOURCE_DIR/ai/claude/}"
  mapped_rel=$(remap_skill_path "$rel")
  dest="$PLUGIN_DIR/skills/$mapped_rel"
  mkdir -p "$(dirname "$dest")"
  cp "$src" "$dest"
  echo "  skills/$mapped_rel"
done

# ── Commands ──────────────────────────────────────────────────────────────────
# Source layout: ai/claude/commands/
# Plugin layout: commands/
# README.md is excluded (not a command).
# Commands that have a matching skill are excluded — the skill is the canonical surface.
# Skill lookup accounts for dev/ remapping: check skills/<name>/, skills/dev/<name>/,
# and the dev-practices → dev/practices rename.
echo "Syncing commands..."

skill_exists_for_cmd() {
  local name="$1"
  [[ -f "$PLUGIN_DIR/skills/$name/SKILL.md" ]] ||
  [[ -f "$PLUGIN_DIR/skills/dev/$name/SKILL.md" ]] ||
  { [[ "$name" == "dev-practices" ]] && [[ -f "$PLUGIN_DIR/skills/dev/practices/SKILL.md" ]]; }
}

if [[ -d "$SOURCE_DIR/ai/claude/commands" ]]; then
  find "$SOURCE_DIR/ai/claude/commands" -name "*.md" ! -name "README.md" | while read -r src; do
    rel="${src#$SOURCE_DIR/ai/claude/commands/}"
    name="${rel%.md}"
    # Skip if a matching skill exists
    if skill_exists_for_cmd "$name"; then
      continue
    fi
    dest="$PLUGIN_DIR/commands/$rel"
    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
    echo "  commands/$rel"
  done
  # Remove any previously synced command that now has a matching skill
  find "$PLUGIN_DIR/commands" -name "*.md" ! -name "README.md" | while read -r dest; do
    rel="${dest#$PLUGIN_DIR/commands/}"
    name="${rel%.md}"
    if skill_exists_for_cmd "$name"; then
      rm "$dest"
      echo "  removed duplicate: commands/$rel"
    fi
  done
  # Remove stale plugin commands that no longer exist in source
  find "$PLUGIN_DIR/commands" -name "*.md" ! -name "README.md" | while read -r dest; do
    rel="${dest#$PLUGIN_DIR/commands/}"
    if [[ ! -f "$SOURCE_DIR/ai/claude/commands/$rel" ]]; then
      rm "$dest"
      echo "  removed stale: commands/$rel"
    fi
  done
fi
# README.md is not a command — remove it from the scanned commands/ directory
rm -f "$PLUGIN_DIR/commands/README.md"
# Remove any empty subdirectories left over from deleted command files
find "$PLUGIN_DIR/commands" -mindepth 1 -type d -empty -delete 2>/dev/null || true

# ── Agents ────────────────────────────────────────────────────────────────────
# Source layout: ai/claude/agents/
# Plugin layout: agents/
echo "Syncing agents..."
if [[ -d "$SOURCE_DIR/ai/claude/agents" ]]; then
  find "$SOURCE_DIR/ai/claude/agents" -name "*.md" ! -name "README.md" | while read -r src; do
    rel="${src#$SOURCE_DIR/ai/claude/agents/}"
    dest="$PLUGIN_DIR/agents/$rel"
    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
    echo "  agents/$rel"
  done
fi

# ── Hooks ─────────────────────────────────────────────────────────────────────
# Source layout: ai/claude/hooks/
# Plugin layout: hooks/
echo "Syncing hooks..."
if [[ -d "$SOURCE_DIR/ai/claude/hooks" ]]; then
  find "$SOURCE_DIR/ai/claude/hooks" -name "*.sh" -o -name "*.json" | while read -r src; do
    rel="${src#$SOURCE_DIR/ai/claude/hooks/}"
    dest="$PLUGIN_DIR/hooks/$rel"
    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
    echo "  hooks/$rel"
  done
fi

# ── Rewrite hooks.json paths for plugin runtime ────────────────────────────────
# Source hooks.json uses "bash ai/claude/hooks/<name>.sh" — those paths don't
# exist in the plugin package. Rewrite to CLAUDE_PLUGIN_ROOT-relative paths.
HOOKS_JSON="$PLUGIN_DIR/hooks/hooks.json"
if [[ -f "$HOOKS_JSON" ]]; then
  echo "Rewriting hook command paths in hooks/hooks.json..."
  python3 - "$HOOKS_JSON" <<'PYEOF'
import json, re, sys
hooks_file = sys.argv[1]

def rewrite(obj):
    if isinstance(obj, dict):
        return {k: rewrite(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [rewrite(v) for v in obj]
    if isinstance(obj, str):
        return re.sub(
            r'bash ai/claude/hooks/(\S+)',
            r'bash "${CLAUDE_PLUGIN_ROOT}/hooks/\1"',
            obj
        )
    return obj

with open(hooks_file) as f:
    data = json.load(f)
data = rewrite(data)
with open(hooks_file, 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
PYEOF

  if grep -q 'ai/claude/hooks/' "$HOOKS_JSON"; then
    echo "ERROR: hooks/hooks.json still contains 'ai/claude/hooks/' paths after rewrite." >&2
    grep -n 'ai/claude/hooks/' "$HOOKS_JSON" >&2
    exit 1
  fi
  echo "  hooks/hooks.json paths rewritten OK"
fi

# ── Shared templates ──────────────────────────────────────────────────────────
# Two source locations feed shared/templates/:
#   ai/shared/templates/      — registry templates, decision packet, issue, training plan, etc.
#   ai/claude/generate-docs/templates/  — CLAUDE.md.template, HLD/LLD/ADR templates, schema
echo "Syncing shared templates..."
mkdir -p "$PLUGIN_DIR/shared/templates"

for src_dir in \
  "$SOURCE_DIR/ai/shared/templates" \
  "$SOURCE_DIR/ai/claude/generate-docs/templates"; do
  if [[ -d "$src_dir" ]]; then
    find "$src_dir" -maxdepth 1 -name "*.md" -o -name "*.yaml" -o -name "*.template" | while read -r src; do
      fname="$(basename "$src")"
      dest="$PLUGIN_DIR/shared/templates/$fname"
      cp "$src" "$dest"
      echo "  shared/templates/$fname"
    done
  fi
done

# ── Shared prose ──────────────────────────────────────────────────────────────
echo "Syncing shared prose..."
if [[ -f "$SOURCE_DIR/ai/shared/challenge-stance.md" ]]; then
  cp "$SOURCE_DIR/ai/shared/challenge-stance.md" "$PLUGIN_DIR/shared/challenge-stance.md"
  echo "  shared/challenge-stance.md"
fi

# ── Normalize internal paths ──────────────────────────────────────────────────
# hitl-dev-platform uses paths rooted at its own repo root (ai/shared/templates/).
# The plugin flattens these into shared/templates/ — fix references in all
# copied skill, command, and agent files.
echo "Normalizing path references..."
find "$PLUGIN_DIR/skills" "$PLUGIN_DIR/commands" "$PLUGIN_DIR/agents" \
     "$PLUGIN_DIR/shared" \
     -name "*.md" -o -name "*.yaml" | while read -r f; do
  sed -i '' \
    -e 's|ai/shared/templates/|shared/templates/|g' \
    -e 's|ai/claude/generate-docs/templates/|shared/templates/|g' \
    -e 's|ai/shared/challenge-stance\.md|shared/challenge-stance.md|g' \
    "$f"
done

echo ""
echo "Build complete."
echo "Review changes with: git -C \"$PLUGIN_DIR\" diff --stat"
