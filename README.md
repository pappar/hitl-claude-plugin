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

## Update

Once installed, update from inside Claude Code:

```
/hitl:dev-update
```

Do not re-run the install commands to update.

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

## License

MIT
