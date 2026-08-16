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
       "$PLUGIN_DIR/skills/ops" \
       "$PLUGIN_DIR/skills/hooks" \
       "$PLUGIN_DIR/skills/shared"
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
    ta-approve)    echo "ta-approve/$rest" ;;  # TA role — keep prefix as-is
    help)          echo "help/$rest" ;;         # meta skill — no role prefix
    skills)        echo "$rest" ;;              # ai/claude/skills/<name>/ = a top-level role-less skill → skills/<name>/ (e.g. agentic-intake)
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
# skills/README.md is source-repo documentation, not a skill — remove if present
rm -f "$PLUGIN_DIR/skills/README.md"

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

# ── Plugin manifest ───────────────────────────────────────────────────────────
# Sync description and version from source plugin.json to keep the installed manifest current.
echo "Syncing plugin manifest..."
SOURCE_PLUGIN_JSON="$SOURCE_DIR/ai/claude/plugin/plugin.json"
DIST_PLUGIN_JSON="$PLUGIN_DIR/.claude-plugin/plugin.json"
if [[ -f "$SOURCE_PLUGIN_JSON" ]] && [[ -f "$DIST_PLUGIN_JSON" ]]; then
  python3 - "$DIST_PLUGIN_JSON" "$SOURCE_PLUGIN_JSON" <<'PYEOF'
import json, sys
dist_file, src_file = sys.argv[1], sys.argv[2]
with open(dist_file) as f:
    dist = json.load(f)
with open(src_file) as f:
    src = json.load(f)
for field in ('description', 'version'):
    if field in src:
        dist[field] = src[field]
with open(dist_file, 'w') as f:
    json.dump(dist, f, indent=2)
    f.write('\n')
PYEOF
  echo "  .claude-plugin/plugin.json synced"
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

# ── Shared CI tooling ─────────────────────────────────────────────────────────
# Python tooling that product repos copy in during onboarding and reference by
# repo path from the copied ci/workflows/*.yml templates. Shipped as assets under
# shared/ci/ so /hitl:dev-start-brownfield and /hitl:dev-start-from-prd can copy them.
echo "Syncing shared CI tooling..."
if [[ -d "$SOURCE_DIR/ci/manifest-drift" ]]; then
  mkdir -p "$PLUGIN_DIR/shared/ci/manifest-drift"
  find "$SOURCE_DIR/ci/manifest-drift" -maxdepth 1 ! -name "test_*" ! -name "conftest.py" \( -name "*.py" -o -name "*.md" \) | while read -r src; do
    fname="$(basename "$src")"
    cp "$src" "$PLUGIN_DIR/shared/ci/manifest-drift/$fname"
    echo "  shared/ci/manifest-drift/$fname"
  done
fi
# Compound-agentic surface (#10): the fail-closed validators + generator that product
# repos copy in to govern a graph of deterministic services + simple/deep agents. Ships
# the same way as manifest-drift so onboarding can copy it.
if [[ -d "$SOURCE_DIR/ci/manifest-agentic" ]]; then
  mkdir -p "$PLUGIN_DIR/shared/ci/manifest-agentic"
  find "$SOURCE_DIR/ci/manifest-agentic" -maxdepth 1 ! -name "test_*" ! -name "conftest.py" \( -name "*.py" -o -name "*.md" -o -name "*.yaml" \) | while read -r src; do
    fname="$(basename "$src")"
    cp "$src" "$PLUGIN_DIR/shared/ci/manifest-agentic/$fname"
    echo "  shared/ci/manifest-agentic/$fname"
  done
fi
if [[ -d "$SOURCE_DIR/tools/manifest-agentic" ]]; then
  mkdir -p "$PLUGIN_DIR/shared/tools/manifest-agentic"
  find "$SOURCE_DIR/tools/manifest-agentic" -maxdepth 1 -name "*.py" ! -name "test_*" ! -name "conftest.py" | while read -r src; do
    fname="$(basename "$src")"
    cp "$src" "$PLUGIN_DIR/shared/tools/manifest-agentic/$fname"
    echo "  shared/tools/manifest-agentic/$fname"
  done
fi
# Agentic Design Advisor (#35): the recommend/record/hand-off tools + curated catalog that the
# hitl:agentic-intake skill runs. Ships the same way as manifest-agentic so onboarding can copy it.
# The tools/../.. -> ci/manifest-agentic relative import is preserved under shared/ (shared/tools/
# agentic-advisor/../../ci/manifest-agentic = shared/ci/manifest-agentic), so #10's FIELD_SPEC derivation
# keeps working; the at-parity static fallback covers a missing #10.
if [[ -d "$SOURCE_DIR/tools/agentic-advisor" ]]; then
  mkdir -p "$PLUGIN_DIR/shared/tools/agentic-advisor"
  find "$SOURCE_DIR/tools/agentic-advisor" -maxdepth 1 -name "*.py" ! -name "test_*" ! -name "conftest.py" | while read -r src; do
    fname="$(basename "$src")"
    cp "$src" "$PLUGIN_DIR/shared/tools/agentic-advisor/$fname"
    echo "  shared/tools/agentic-advisor/$fname"
  done
fi
# CLAUDE.md HITL-block upsert: dev-update Step 4.8 runs this from the installed plugin, and
# init-project.sh runs the same file from source. One implementation, two callers.
# Hashes of every test file HITL has ever synced into a product repo. dev-update deletes a stale
# synced test only on an exact content match, so a team's same-named file is never destroyed.
# Release gate: the adversarial-review validator, shipped so a product repo's CI can run it the
# same way it runs the First Pass validator.
if [[ -d "$SOURCE_DIR/ci/adversarial" ]]; then
  mkdir -p "$PLUGIN_DIR/shared/ci/adversarial"
  find "$SOURCE_DIR/ci/adversarial" -maxdepth 1 -name "*.py" ! -name "test_*" ! -name "conftest.py" | while read -r src; do
    cp "$src" "$PLUGIN_DIR/shared/ci/adversarial/$(basename "$src")"
    echo "  shared/ci/adversarial/$(basename "$src")"
  done
fi
if [[ -f "$SOURCE_DIR/ci/retired-tests.sha256" ]]; then
  mkdir -p "$PLUGIN_DIR/shared/ci"
  cp "$SOURCE_DIR/ci/retired-tests.sha256" "$PLUGIN_DIR/shared/ci/retired-tests.sha256"
  echo "  shared/ci/retired-tests.sha256"
fi
if [[ -d "$SOURCE_DIR/tools/hitl-onboarding" ]]; then
  mkdir -p "$PLUGIN_DIR/shared/tools/hitl-onboarding"
  find "$SOURCE_DIR/tools/hitl-onboarding" -maxdepth 1 -name "*.py" ! -name "test_*" ! -name "conftest.py" | while read -r src; do
    fname="$(basename "$src")"
    cp "$src" "$PLUGIN_DIR/shared/tools/hitl-onboarding/$fname"
    echo "  shared/tools/hitl-onboarding/$fname"
  done
fi
if [[ -d "$SOURCE_DIR/ci/agentic-advisor" ]]; then
  mkdir -p "$PLUGIN_DIR/shared/ci/agentic-advisor"
  find "$SOURCE_DIR/ci/agentic-advisor" -maxdepth 1 -name "*.py" ! -name "test_*" ! -name "conftest.py" | while read -r src; do
    fname="$(basename "$src")"
    cp "$src" "$PLUGIN_DIR/shared/ci/agentic-advisor/$fname"
    echo "  shared/ci/agentic-advisor/$fname"
  done
fi
if [[ -f "$SOURCE_DIR/ai/shared/agentic/catalog.yaml" ]]; then
  mkdir -p "$PLUGIN_DIR/shared/agentic"
  cp "$SOURCE_DIR/ai/shared/agentic/catalog.yaml" "$PLUGIN_DIR/shared/agentic/catalog.yaml"
  echo "  shared/agentic/catalog.yaml"
fi
# Semgrep convention rules (issue #47). These were NEVER packaged: init-project.sh copies .semgrep/
# from a hitl-dev-platform checkout, so a plugin-onboarded repo had no rules at all and
# `/hitl:dev-check-conventions` failed with "unable to find a config; path `.semgrep` does not exist".
# Shipped under shared/semgrep/ (dot-prefixed dirs are awkward as plugin assets) and installed to
# .semgrep/ by the onboarding skills, preserving the category subdirectories.
if [[ -d "$SOURCE_DIR/.semgrep" ]]; then
  find "$SOURCE_DIR/.semgrep" -type f \( -name "*.yaml" -o -name "*.yml" -o -name ".semgrepignore" \) | while read -r src; do
    rel="${src#"$SOURCE_DIR"/.semgrep/}"
    mkdir -p "$PLUGIN_DIR/shared/semgrep/$(dirname "$rel")"
    cp "$src" "$PLUGIN_DIR/shared/semgrep/$rel"
    echo "  shared/semgrep/$rel"
  done
fi
# The installer the onboarding skills invoke — shipped beside the rules it copies.
if [[ -f "$SOURCE_DIR/ai/shared/semgrep/install.sh" ]]; then
  mkdir -p "$PLUGIN_DIR/shared/semgrep"
  cp "$SOURCE_DIR/ai/shared/semgrep/install.sh" "$PLUGIN_DIR/shared/semgrep/install.sh"
  chmod 755 "$PLUGIN_DIR/shared/semgrep/install.sh"
  echo "  shared/semgrep/install.sh"
fi

# First Pass (#FR-29): the fail-closed skip-ledger validator + library and its prose. Ships the same way
# as manifest-agentic so onboarding can copy it into a product repo (ci/first-pass + the CI template).
if [[ -d "$SOURCE_DIR/ci/first-pass" ]]; then
  mkdir -p "$PLUGIN_DIR/shared/ci/first-pass"
  find "$SOURCE_DIR/ci/first-pass" -maxdepth 1 -name "*.py" ! -name "test_*" ! -name "conftest.py" | while read -r src; do
    fname="$(basename "$src")"
    cp "$src" "$PLUGIN_DIR/shared/ci/first-pass/$fname"
    echo "  shared/ci/first-pass/$fname"
  done
fi
if [[ -d "$SOURCE_DIR/ai/shared/first-pass" ]]; then
  mkdir -p "$PLUGIN_DIR/shared/first-pass"
  find "$SOURCE_DIR/ai/shared/first-pass" -maxdepth 1 -name "*.md" | while read -r src; do
    fname="$(basename "$src")"
    cp "$src" "$PLUGIN_DIR/shared/first-pass/$fname"
    echo "  shared/first-pass/$fname"
  done
fi
if [[ -f "$SOURCE_DIR/ai/shared/skip-record.md" ]]; then
  cp "$SOURCE_DIR/ai/shared/skip-record.md" "$PLUGIN_DIR/shared/skip-record.md"
  echo "  shared/skip-record.md"
fi
if [[ -f "$SOURCE_DIR/ci/workflows/first-pass-check.yml" ]]; then
  mkdir -p "$PLUGIN_DIR/shared/ci-workflows"
  cp "$SOURCE_DIR/ci/workflows/first-pass-check.yml" "$PLUGIN_DIR/shared/ci-workflows/first-pass-check.yml"
  echo "  shared/ci-workflows/first-pass-check.yml"
fi

# ── Shared prose ──────────────────────────────────────────────────────────────
SHARED_PROSE=(challenge-stance.md adversarial-review.md skip-record.md personas.md)
echo "Syncing shared prose..."
for prose in "${SHARED_PROSE[@]}"; do
  if [[ -f "$SOURCE_DIR/ai/shared/$prose" ]]; then
    cp "$SOURCE_DIR/ai/shared/$prose" "$PLUGIN_DIR/shared/$prose"
    echo "  shared/$prose"
  fi
done
if [[ -f "$SOURCE_DIR/CHANGELOG.md" ]]; then
  cp "$SOURCE_DIR/CHANGELOG.md" "$PLUGIN_DIR/CHANGELOG.md"
  echo "  CHANGELOG.md"
fi
# Canonical workflow catalog — consumed at runtime by /hitl:dev-start-change and /hitl:dev-update
# to seed and migrate the embedded `workflow` block in .hitl/current-change.yaml.
if [[ -f "$SOURCE_DIR/ai/shared/workflows.yaml" ]]; then
  cp "$SOURCE_DIR/ai/shared/workflows.yaml" "$PLUGIN_DIR/shared/workflows.yaml"
  echo "  shared/workflows.yaml"
fi

# ── Shared workflow docs ──────────────────────────────────────────────────────
# Reference docs from docs/ that are useful to plugin users at runtime.
echo "Syncing shared workflow docs..."
for fname in getting-started.md command-map.md usage-guide.md workflow-prd.md workflow-brownfield.md workflow-migration.md; do
  if [[ -f "$SOURCE_DIR/docs/$fname" ]]; then
    cp "$SOURCE_DIR/docs/$fname" "$PLUGIN_DIR/shared/$fname"
    echo "  shared/$fname"
  fi
done

# ── Normalize internal paths ──────────────────────────────────────────────────
# Two-pass rewrite (idempotent):
# Pass 1 — flatten source-relative paths to plugin-relative paths:
#   ai/shared/templates/             → shared/templates/
#   ai/claude/generate-docs/templates/ → shared/templates/
#   ai/shared/challenge-stance.md    → shared/challenge-stance.md
#   ai/claude/dev-practices/         → skills/dev-practices/
#   ai/claude/apply-change/          → skills/dev-apply-change/
# Pass 2 — add ${CLAUDE_PLUGIN_ROOT}/ prefix to all plugin-bundled refs so
#   Claude resolves them relative to the installed plugin, not the user's project.
#   Strip any existing prefix first (idempotency), then add it.
echo "Normalizing path references..."
find "$PLUGIN_DIR/skills" "$PLUGIN_DIR/commands" "$PLUGIN_DIR/agents" \
     "$PLUGIN_DIR/shared" \
     \( -name "*.md" -o -name "*.yaml" \) | while read -r f; do
  # Pass 1: flatten source-relative → plugin-relative
  sed -i '' \
    -e 's|ai/shared/templates/|shared/templates/|g' \
    -e 's|ai/claude/generate-docs/templates/|shared/templates/|g' \
    -e 's|ai/claude/dev-practices/|skills/dev-practices/|g' \
    -e 's|ai/claude/apply-change/|skills/dev-apply-change/|g' \
    "$f"
  # Pass 2: add ${CLAUDE_PLUGIN_ROOT}/ prefix to plugin-bundled paths.
  # Strip any existing prefix first (idempotency — makes this safe to re-run),
  # then add. \b not available in BSD sed, so we rely on pass 1 having
  # reduced all occurrences to bare plugin-relative paths before we prefix them.
  sed -i '' \
    -e 's|\${CLAUDE_PLUGIN_ROOT}/shared/|shared/|g' \
    -e 's|\${CLAUDE_PLUGIN_ROOT}/skills/|skills/|g' \
    -e 's|shared/templates/|${CLAUDE_PLUGIN_ROOT}/shared/templates/|g' \
    -e 's|skills/dev-practices/|${CLAUDE_PLUGIN_ROOT}/skills/dev-practices/|g' \
    -e 's|skills/dev-apply-change/|${CLAUDE_PLUGIN_ROOT}/skills/dev-apply-change/|g' \
    "$f"
  # Every top-level shared prose file, flattened then prefixed. A hardcoded per-file list is how
  # adversarial-review.md shipped with a bare path that resolved against the user's project.
  for prose in "${SHARED_PROSE[@]}"; do
    sed -i '' \
      -e "s|ai/shared/${prose}|shared/${prose}|g" \
      -e "s|\${CLAUDE_PLUGIN_ROOT}/shared/${prose}|shared/${prose}|g" \
      -e "s|shared/${prose}|\${CLAUDE_PLUGIN_ROOT}/shared/${prose}|g" \
      "$f"
  done
  # Pass 3: collapse double prefixes. Source text that already carries a
  # "$PLUGIN_ROOT/shared/..." runtime path gets ${CLAUDE_PLUGIN_ROOT}/ inserted by
  # pass 2, producing "$PLUGIN_ROOT/${CLAUDE_PLUGIN_ROOT}/shared/..." — a path that
  # resolves nowhere in the installed layout (found by the 2026-07-12 v1.1.0 round-5
  # validation). ${CLAUDE_PLUGIN_ROOT} alone is the canonical installed-plugin form.
  sed -i '' \
    -e 's|\$[A-Za-z_][A-Za-z_0-9]*/\${CLAUDE_PLUGIN_ROOT}/|${CLAUDE_PLUGIN_ROOT}/|g' \
    -e 's|\${CLAUDE_PLUGIN_ROOT}/\${CLAUDE_PLUGIN_ROOT}/|${CLAUDE_PLUGIN_ROOT}/|g' \
    "$f"
done

# ── Post-build checks ────────────────────────────────────────────────────────

# Guard: mangled relative+CLAUDE_PLUGIN_ROOT links (e.g. ../../../${CLAUDE_PLUGIN_ROOT}/...)
echo "Checking for mangled relative plugin paths..."
mangled=$(grep -rlE -e '\.\./.*\$\{CLAUDE_PLUGIN_ROOT\}' -e '\$[A-Za-z_][A-Za-z_0-9]*/\$\{CLAUDE_PLUGIN_ROOT\}' \
  "$PLUGIN_DIR/skills" "$PLUGIN_DIR/commands" "$PLUGIN_DIR/agents" 2>/dev/null || true)
if [[ -n "$mangled" ]]; then
  echo "ERROR: found relative paths combined with \${CLAUDE_PLUGIN_ROOT}:" >&2
  echo "$mangled" >&2
  grep -rn '\.\./.*\${CLAUDE_PLUGIN_ROOT}' \
    "$PLUGIN_DIR/skills" "$PLUGIN_DIR/commands" "$PLUGIN_DIR/agents" >&2
  exit 1
fi
echo "  no mangled paths found"

# Validate plugin structure (frontmatter, manifest, skill layout) via the
# canonical Claude Code validator — no extra Python dependencies required.
# Override the binary with CLAUDE_BIN=/path/to/claude if your working claude
# is not first on PATH (e.g. a broken wrapper shadows the real binary).
echo "Validating plugin structure..."
CLAUDE_BIN="${CLAUDE_BIN:-$(command -v claude 2>/dev/null || true)}"
if [[ -n "$CLAUDE_BIN" ]]; then
  echo "  using: $CLAUDE_BIN"
  "$CLAUDE_BIN" plugin validate "$PLUGIN_DIR"
  echo "  plugin validation passed"
else
  echo "  SKIP: 'claude' not on PATH — run 'claude plugin validate $PLUGIN_DIR' before release"
  echo "  Tip:  set CLAUDE_BIN=/path/to/claude to specify the binary explicitly"
fi

# NOTE: marketplace.json source.commit is NOT updated here.
# Updating it before the build commit exists would pin to the previous HEAD.
# Run scripts/release.sh after committing to update the pin and create the tag.

echo ""
# ── Post-build assertion ──────────────────────────────────────────────────────
# build.sh copies but does not prune, so a file removed from the source survives in shared/ from an
# earlier build — which is exactly how the issue-#29 test suites kept shipping after the filter was
# added. Nothing checked the packaged result, so fail the build on anything a consumer cannot run.
stray=$(find "$PLUGIN_DIR/shared" \( -name "test_*" -o -name "conftest.py" -o -name "__pycache__" -o -name "*.pyc" \) 2>/dev/null)
if [[ -n "$stray" ]]; then
  echo "BUILD FAILED — these would ship to every consumer and cannot run there:" >&2
  echo "$stray" | sed 's/^/  /' >&2
  echo "Delete them from $PLUGIN_DIR/shared (the build does not prune) and re-run." >&2
  exit 1
fi
echo "Packaging check: no test/conftest/bytecode under shared/"

echo "Build complete."
echo "Review changes with: git -C \"$PLUGIN_DIR\" diff --stat"
