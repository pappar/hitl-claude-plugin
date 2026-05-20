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
# Plugin layout: skills/<role>-<skill>/SKILL.md (flat, one level deep)
#   — Claude Code docs only support skills/<skill-name>/SKILL.md at depth 2;
#     deeper nesting is not discovered as skills. All names use hyphens.
# Mappings:
#   dev-practices/*                → dev-practices/*         (unchanged)
#   migrate/review-external-docs/* → dev-review-external-docs/*
#   architect/<s>/* | pm/<s>/* | qa/<s>/* | ops/<s>/* → <role>-<s>/*
#   <flat-dev-skill>/*             → dev-<skill>/*
echo "Syncing skills..."

# Remove stale nested skill dirs from prior layout (skills/dev/, skills/architect/, etc.)
rm -rf "$PLUGIN_DIR/skills/dev" \
       "$PLUGIN_DIR/skills/architect" \
       "$PLUGIN_DIR/skills/pm" \
       "$PLUGIN_DIR/skills/qa" \
       "$PLUGIN_DIR/skills/ops"
# Remove old flat dev dirs (no dev- prefix) that no longer match
for stale_dir in \
  apply-change check-conventions conclude generate-docs \
  impact-brief migrate review-security start-brownfield start-migration \
  start-prd tdd; do
  rm -rf "$PLUGIN_DIR/skills/$stale_dir"
done

remap_skill_path() {
  local rel="$1"
  local first="${rel%%/*}"   # first path component
  local rest="${rel#*/}"     # remainder after first /
  case "$first" in
    dev-practices) echo "dev-practices/$rest" ;;
    migrate)       echo "dev-review-external-docs/${rest#*/}" ;;  # drop migrate/review-external-docs prefix
    architect|pm|qa|ops)
      local skill="${rest%%/*}"   # role skill name
      local file="${rest#*/}"     # file within skill dir
      echo "${first}-${skill}/$file"
      ;;
    *) echo "dev-${first}/$rest" ;;  # flat dev skill → dev-<name>/
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
# Source layout: ai/claude/commands/<role>/<name>.md (nested for organization)
# Plugin layout: commands/<role>-<name>.md (flat — same depth constraint as skills)
# README.md is excluded. Commands with a matching flat skill are excluded.
echo "Syncing commands..."

# Remove stale nested command subdirs from prior layout
rm -rf "$PLUGIN_DIR/commands"/*/

skill_exists_for_cmd() {
  local name="$1"
  # Direct flat skill match (e.g. dev-practices → skills/dev-practices/)
  [[ -f "$PLUGIN_DIR/skills/$name/SKILL.md" ]] && return 0
  if [[ "$name" == */* ]]; then
    # Nested command: dev/conclude → skills/dev-conclude/
    local first="${name%%/*}"
    local rest="${name#*/}"
    [[ -f "$PLUGIN_DIR/skills/${first}-${rest}/SKILL.md" ]] && return 0
  else
    # Flat command with no role prefix: conclude → skills/dev-conclude/
    [[ -f "$PLUGIN_DIR/skills/dev-${name}/SKILL.md" ]] && return 0
  fi
  return 1
}

flatten_command_path() {
  echo "${1//\//-}"
}

if [[ -d "$SOURCE_DIR/ai/claude/commands" ]]; then
  # Compute expected flat names for stale-removal check
  expected_flat=$(find "$SOURCE_DIR/ai/claude/commands" -name "*.md" ! -name "README.md" | \
    while IFS= read -r s; do
      rel="${s#$SOURCE_DIR/ai/claude/commands/}"
      echo "${rel//\//-}"
    done)

  find "$SOURCE_DIR/ai/claude/commands" -name "*.md" ! -name "README.md" | while read -r src; do
    rel="${src#$SOURCE_DIR/ai/claude/commands/}"
    name="${rel%.md}"
    # Skip if a matching skill exists
    if skill_exists_for_cmd "$name"; then
      continue
    fi
    flat_rel=$(flatten_command_path "$rel")
    dest="$PLUGIN_DIR/commands/$flat_rel"
    cp "$src" "$dest"
    echo "  commands/$flat_rel"
  done
  # Remove any previously synced flat command that now has a matching skill
  find "$PLUGIN_DIR/commands" -maxdepth 1 -name "*.md" ! -name "README.md" | while read -r dest; do
    flat_rel="${dest#$PLUGIN_DIR/commands/}"
    name="${flat_rel%.md}"
    if skill_exists_for_cmd "$name"; then
      rm "$dest"
      echo "  removed duplicate: commands/$flat_rel"
    fi
  done
  # Remove stale plugin commands that no longer exist in source
  find "$PLUGIN_DIR/commands" -maxdepth 1 -name "*.md" ! -name "README.md" | while read -r dest; do
    flat_rel="${dest#$PLUGIN_DIR/commands/}"
    if ! echo "$expected_flat" | grep -qxF "$flat_rel"; then
      rm "$dest"
      echo "  removed stale: commands/$flat_rel"
    fi
  done
fi
# README.md is not a command — remove it if accidentally copied
rm -f "$PLUGIN_DIR/commands/README.md"

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
     \( -name "*.md" -o -name "*.yaml" \) | while read -r f; do
  sed -i '' \
    -e 's|ai/shared/templates/|shared/templates/|g' \
    -e 's|ai/claude/generate-docs/templates/|shared/templates/|g' \
    -e 's|ai/shared/challenge-stance\.md|shared/challenge-stance.md|g' \
    "$f"
done

echo ""
echo "Build complete."
echo "Review changes with: git -C \"$PLUGIN_DIR\" diff --stat"
