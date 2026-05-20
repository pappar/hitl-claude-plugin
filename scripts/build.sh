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
# Source layout: ai/claude/<skill-name>/SKILL.md
# Plugin layout: skills/<skill-name>/SKILL.md
echo "Syncing skills..."
find "$SOURCE_DIR/ai/claude" \( -name "SKILL.md" -o -name "*.md" \) \
  ! -path "*/agents/*" ! -path "*/commands/*" | while read -r src; do
  rel="${src#$SOURCE_DIR/ai/claude/}"        # e.g. tdd/SKILL.md or qa/plan-tests/SKILL.md
  dest="$PLUGIN_DIR/skills/$rel"
  mkdir -p "$(dirname "$dest")"
  cp "$src" "$dest"
  echo "  skills/$rel"
done

# ── Commands ──────────────────────────────────────────────────────────────────
# Source layout: ai/claude/commands/
# Plugin layout: commands/
echo "Syncing commands..."
if [[ -d "$SOURCE_DIR/ai/claude/commands" ]]; then
  find "$SOURCE_DIR/ai/claude/commands" -name "*.md" | while read -r src; do
    rel="${src#$SOURCE_DIR/ai/claude/commands/}"
    dest="$PLUGIN_DIR/commands/$rel"
    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
    echo "  commands/$rel"
  done
fi

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
