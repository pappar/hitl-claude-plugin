# HITL Dev Platform — Claude Code Plugin

A [Claude Code](https://docs.anthropic.com/en/docs/claude-code) plugin for the **HITL AI-Driven Development** process — a document-driven delivery model for teams using AI heavily in non-trivial software work.

## Prerequisites

| Dependency | Required | Used by |
|---|---|---|
| `bash` | Hard | All hooks |
| `python3` | Hard | All hooks (JSON/YAML parsing) |
| `PyYAML` (`pip install pyyaml`) | Hard | `check-domain-boundary.sh`, `write-session-summary.sh` — hooks silently no-op if missing |
| `git` (inside a git repo) | Hard | `write-session-summary.sh`, overall workflow |
| `gh` (GitHub CLI) | Recommended | Step → issue comment sync; skipped silently if absent |
| `graphify` (`pip install graphifyy`) | Optional | Knowledge graph; skipped silently if absent |

## Install

```bash
claude plugin marketplace add pappar/hitl-claude-plugin
claude plugin install hitl@hitl
```

Restart Claude Code after installing. If `plugin install` fails with a host-key error, see [Troubleshooting](#troubleshooting).

## Release lines

The marketplace serves two lines. Install **one**, not both — they declare the same internal plugin name (`hitl`) and the same `/hitl:*` commands.

| Entry | Version | Served from | Who it's for |
|---|---|---|---|
| `hitl@hitl` | **2.1.1** (current) | `release/2.x` | New projects and teams ready for the 2.x workflow model (step plans derived per change from impact analysis) |
| `hitl-1x@hitl` | 1.1.1 (legacy) | `release/1.x` | Teams staying on the numbered 31-step workflow; feature-frozen except critical fixes |

```bash
# legacy line
claude plugin install hitl-1x@hitl
```

To stay on 1.x when moving off `hitl@hitl`, uninstall it first (`claude plugin uninstall hitl@hitl`), then install `hitl-1x@hitl`. Upgrading 1.x → 2.x is additive: in-flight changes keep their progress and the readiness register carries over unchanged.

Check what you are running with `claude plugin list`. Note for anyone who installed between 2026-07-11 and 2026-07-13: a marketplace pinning defect meant fresh installs in that window received a 2.0.x pre-release build instead of v1.1.0 — run `claude plugin list` and reinstall the line you intended.

## Update

Once installed, update from inside Claude Code:

```
/hitl:dev-update
```

Do not re-run the install commands to update.

## What happens when you install

The plugin installs at the user level. Here's exactly what that means:

**What is global (affects all projects):**
- `/hitl:*` commands appear in Claude Code's command palette in every project. This is a current limitation of how Claude Code loads plugin skills — there is no per-project skill visibility yet. If you run a HITL command in a project that hasn't been set up, the skill detects the missing `.hitl/` directory, outputs a setup prompt, and stops — it does nothing else.

**What is per-project (opt-in only):**
- Enforcement hooks only fire in projects where you ran a start skill. Hooks are wired into `.hitl/hooks/` and `.claude/settings.json` inside the project directory. No `.hitl/` directory means no hooks, no banner, no HITL activity of any kind in that project.

**Net result:** Installing adds commands to your palette. Nothing enforces anything or injects output into any project until you opt that project in.

## What you get

| Component | Contents |
|-----------|----------|
| **Skills** | `/hitl:dev-start-from-prd`, `/hitl:dev-start-brownfield`, `/hitl:dev-start-migration`, `/hitl:dev-practices` (32-step workflow), `/hitl:dev-tdd`, `/hitl:dev-generate-docs`, `/hitl:dev-apply-change`, `/hitl:ta-approve`, and role namespaces `/hitl:architect-*`, `/hitl:pm-*`, `/hitl:qa-*`, `/hitl:ops-*` |
| **Agents** | Architect reviewer, developer implementer, QA reviewer, PM reviewer, ops release reviewer, spec conformance reviewer |
| **Commands** | `/hitl:dev-check-implementation`, `/hitl:architect-review-design`, `/hitl:architect-verify-traceability`, `/hitl:ops-review-release`, `/hitl:ops-monitor-canary` |
| **Hooks** | Welcome banner, HITL context check, domain boundary enforcement, session summary, step→issue sync |

Step 0 of each start skill wires up hooks automatically. Restart Claude Code after Step 0 completes.

### Optional: Graphify (knowledge graph)

```bash
pip install graphifyy
```

**Billing note for Claude subscription users:** The initial build runs LLM extraction. Pass `--backend claude-cli` to use your subscription instead of API credits:

```bash
graphify . --directed --no-viz --backend claude-cli
```

Do **not** put `ANTHROPIC_API_KEY` in `.env` if you are on a subscription. The background rebuild hook never calls an LLM and is always free.

## Troubleshooting

### `claude plugin install` fails with "Host key verification failed"

```
✘ Failed to install plugin "hitl@hitl": No ED25519 host key is known for github.com
```

The repo is public — the error is SSH configuration, not permissions. Fix:

```bash
ssh-keyscan github.com >> ~/.ssh/known_hosts
git config --global --add url."https://github.com/".insteadOf "git@github.com:"
git config --global --add url."https://github.com/".insteadOf "ssh://git@github.com/"
claude plugin install hitl@hitl
```

> Use `--add` on both `git config` calls so the second does not overwrite the first.

### Clean reinstall

If your setup is broken (stale clone paths, missing hooks):

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/pappar/hitl-claude-plugin/main/scripts/reinstall.sh)
```

## Opting a project out

To stop HITL from running in a specific project, remove the two things Step 0 created:

```bash
# Remove hook wiring — hooks stop firing immediately
rm -rf .hitl/hooks/
rm .claude/settings.json   # or edit to remove the "hooks" block if you have other hooks

# Optionally remove all HITL tracking files
rm -rf .hitl/
```

Other opted-in projects are unaffected.

## Removing the plugin entirely

```bash
# 1. Uninstall
claude plugin uninstall hitl@hitl

# 2. Clean up opted-in projects (repeat for each)
rm -rf .hitl/hooks/ .claude/settings.json .hitl/
```

Restart Claude Code after uninstalling. The `/hitl:*` commands disappear from the palette.

## Documentation

Full documentation, playbooks, role guides, and adoption ladder live in the source repo:

**[github.com/Prasad-Apparaju/hitl-dev-platform](https://github.com/Prasad-Apparaju/hitl-dev-platform)**

## Quick start

Once installed, open Claude Code in your project and run the command that matches your situation:

| Situation | Command |
|-----------|---------|
| New project — greenfield from a PRD | `/hitl:dev-start-from-prd` |
| Existing codebase — adopt the process | `/hitl:dev-start-brownfield` |
| Migrating a system | `/hitl:dev-start-migration` |
| Already set up — start a change | `/hitl:dev-practices` |

## Contributing / Building from source

Skills, commands, agents, and templates are authored in the source repo:

**[github.com/Prasad-Apparaju/hitl-dev-platform](https://github.com/Prasad-Apparaju/hitl-dev-platform)** — edit files under `ai/claude/` there.

After updating the source, rebuild this plugin:

```bash
# Clone both repos as siblings
git clone https://github.com/Prasad-Apparaju/hitl-dev-platform
git clone https://github.com/pappar/hitl-claude-plugin

# Rebuild
cd hitl-claude-plugin
./scripts/build.sh
# If 'claude' on your PATH is a broken wrapper, override the binary:
# CLAUDE_BIN=/path/to/claude ./scripts/build.sh

# Review, commit, push
git diff --stat
git add -A && git commit -m "chore: rebuild from hitl-dev-platform"
git push
```

The same source can be used to build plugins for other AI platforms (e.g. Codex) by following the same build pattern with a platform-specific manifest and hooks.

## Known Limitations

**`/hitl:*` commands appear in the palette in all projects.** Claude Code does not yet support per-project plugin skill visibility — skills from a user-scoped plugin are global. All non-setup skills exit immediately with a setup prompt if run outside a HITL project, so nothing unexpected happens, but the commands remain visible everywhere.

Project-scoped install (`claude plugin install hitl@hitl --scope project`) would solve this but has active bugs in Claude Code:

| Upstream issue | Description |
|---|---|
| [anthropics/claude-code#60512](https://github.com/anthropics/claude-code/issues/60512) | `enabledPlugins` silently ignored when Claude Code launches from a subdirectory |
| [anthropics/claude-code#61866](https://github.com/anthropics/claude-code/issues/61866) | Project-scoped plugins not auto-enabled in git worktrees |
| [anthropics/claude-code#14202](https://github.com/anthropics/claude-code/issues/14202) | Project-scoped plugins incorrectly detected as installed globally |

Tracked in [pappar/hitl-claude-plugin#5](https://github.com/pappar/hitl-claude-plugin/issues/5). The README and docs will be updated to recommend `--scope project` once those bugs are resolved.

## License

MIT
