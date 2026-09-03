#!/usr/bin/env bash
# Release the hitl-claude-plugin.
#
# Usage:
#   ./scripts/release.sh [SOURCE_DIR]
#
# What it does (in order):
#   1. Runs build.sh to sync all content from hitl-dev-platform
#   2. Commits the built output as "chore(release): build vX.Y.Z"
#   3. Updates .claude-plugin/marketplace.json source.commit to the build commit SHA
#   4. Creates the Claude-convention plugin tag: hitl--vX.Y.Z
#   5. Commits marketplace.json with the correct SHA
#
# The two-step commit is intentional: the build commit SHA can only be known
# after the build commit exists. Updating marketplace.json in the same commit
# would create a pointer to the commit before it — which installs the wrong version.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_DIR="${HITL_SOURCE_DIR:-${1:-$PLUGIN_DIR/../hitl-dev-platform}}"

# ── Step 0: Release gate ──────────────────────────────────────────────────────
# This script IS the act of publishing. Everything else in HITL — the release workflow, the
# adversarial_review step, /hitl:dev-validate — binds to a change file in the SOURCE repo, and this
# repo has no .hitl at all. So an operator who finishes work under an ordinary development change,
# bumps the version, and runs this script publishes with every tool reporting green and no review
# having happened. That is not a hypothetical: it is how every release to date shipped.
#
# The gate belongs on the action that publishes. Fail closed here, or it does not bind.
#
# HITL_RELEASE_GATE=off is a deliberate, visible escape for bootstrapping — it prints what it
# skipped. It is not a default and it is not quiet.
echo "=== Step 0: Release gate ==="
CHANGE="$SOURCE_DIR/.hitl/current-change.yaml"
GATE="$SOURCE_DIR/ci/adversarial/check_review.py"
if [[ "${HITL_RELEASE_GATE:-on}" == "off" ]]; then
  echo "  SKIPPED — HITL_RELEASE_GATE=off. Publishing with no adversarial-review check." >&2
elif [[ ! -f "$GATE" ]]; then
  echo "ERROR: release gate not found at $GATE — refusing to publish." >&2
  echo "  A missing gate is not a passing gate." >&2
  exit 2
elif [[ ! -f "$CHANGE" ]]; then
  echo "ERROR: no active change in $SOURCE_DIR — refusing to publish." >&2
  echo "  Start one with /hitl:dev-start-change and choose the 'release' workflow." >&2
  exit 2
else
  WF=$(python3 -c "import yaml,sys;d=yaml.safe_load(open('$CHANGE'));print((d.get('workflow') or {}).get('id',''))" 2>/dev/null || echo "")
  if [[ "$WF" != "release" ]]; then
    echo "ERROR: the active change is '${WF:-unknown}', not 'release' — refusing to publish." >&2
    echo "  Publishing under a development change is how a release skips its own gate." >&2
    exit 2
  fi
  python3 "$GATE" --root "$SOURCE_DIR" --change "$CHANGE" --reviews "$SOURCE_DIR/.hitl/reviews" || {
    echo "" >&2
    echo "Refusing to publish: the release gate did not pass." >&2
    exit 2
  }

  # The waiver path above accepts a skip record that the LEDGER validator rejects. Both are
  # fail-closed, both read the same file, and 2.9.0 and 2.9.1 shipped while they disagreed —
  # check_review said ship, check_skips said the record was malformed (no disposition, no
  # waiver_ref), and the release path only ever asked the first. A gate that publishes on a
  # record its own validator refuses is not a gate. Ask both.
  LEDGER="$SOURCE_DIR/ci/first-pass/check_skips.py"
  if [[ -f "$LEDGER" ]]; then
    python3 "$LEDGER" "$CHANGE" || {
      echo "" >&2
      echo "Refusing to publish: the skip ledger did not certify." >&2
      echo "  The release gate accepted this change, but its skip records are not valid." >&2
      exit 2
    }
  else
    echo "  WARNING: $LEDGER not found — skip records are UNCERTIFIED for this release." >&2
  fi
fi
echo ""

# ── Step 1: Build ─────────────────────────────────────────────────────────────
echo "=== Step 1: Build ==="
bash "$SCRIPT_DIR/build.sh" "${SOURCE_DIR}"

# ── Step 2: Read version ──────────────────────────────────────────────────────
VERSION=$(python3 -c "import json; print(json.load(open('$PLUGIN_DIR/.claude-plugin/plugin.json'))['version'])")
echo ""
echo "=== Step 2: Release v${VERSION} ==="

# ── Step 3: Commit built output ───────────────────────────────────────────────
echo "Committing build output..."
git -C "$PLUGIN_DIR" add -A
if git -C "$PLUGIN_DIR" diff --cached --quiet; then
  echo "  Nothing to commit — build output is unchanged."
else
  git -C "$PLUGIN_DIR" commit -m "chore(release): build v${VERSION}"
  echo "  Committed: $(git -C "$PLUGIN_DIR" rev-parse --short HEAD)"
fi

BUILD_SHA=$(git -C "$PLUGIN_DIR" rev-parse HEAD)
echo "  Build commit: $BUILD_SHA"

# ── Step 4: Update marketplace.json with the build commit SHA ─────────────────
echo "Updating marketplace.json source.commit → ${BUILD_SHA:0:12}..."
MARKETPLACE_JSON="$PLUGIN_DIR/.claude-plugin/marketplace.json"
python3 - "$MARKETPLACE_JSON" "$BUILD_SHA" <<'PYEOF'
import json, sys
path, sha = sys.argv[1], sys.argv[2]
with open(path) as f:
    data = json.load(f)
for plugin in data.get("plugins", []):
    if "source" in plugin:
        plugin["source"]["commit"] = sha
with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PYEOF

# ── Step 5: Create plugin tag (Claude convention: {name}--v{version}) ─────────
TAG="hitl--v${VERSION}"
echo "Creating tag: $TAG"
if git -C "$PLUGIN_DIR" tag --list | grep -qxF "$TAG"; then
  echo "  Tag $TAG already exists — skipping tag creation."
else
  git -C "$PLUGIN_DIR" tag "$TAG" "$BUILD_SHA"
  echo "  Tagged $BUILD_SHA as $TAG"
fi

# ── Step 6: Commit marketplace.json ───────────────────────────────────────────
echo "Committing marketplace.json..."
git -C "$PLUGIN_DIR" add .claude-plugin/marketplace.json
git -C "$PLUGIN_DIR" commit -m "chore(release): pin marketplace to v${VERSION} build commit"

echo ""
echo "Release v${VERSION} complete."
echo "  Build commit : $BUILD_SHA"
echo "  Tag          : $TAG"
echo "  To push      : git -C \"$PLUGIN_DIR\" push && git -C \"$PLUGIN_DIR\" push origin $TAG"
