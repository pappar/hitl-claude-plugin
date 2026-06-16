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
