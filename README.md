# HITL Dev Platform — Claude Code Plugin

A [Claude Code](https://docs.anthropic.com/en/docs/claude-code) plugin for the **HITL AI-Driven Development** process — a document-driven delivery model for teams using AI heavily in non-trivial software work.

## Install

```bash
claude plugin marketplace add pappar/hitl-claude-plugin
claude plugin install hitl@hitl
```

The first command registers the HITL marketplace from the plugin repo. The second installs the plugin from it.

## Update

```bash
claude plugin marketplace add pappar/hitl-claude-plugin
claude plugin install hitl@hitl
```

Re-running install after re-adding the marketplace picks up the latest commit SHA.

## What you get

| Component | Contents |
|-----------|----------|
| **40 skills** | `/hitl:dev-start-prd`, `/hitl:dev-start-brownfield`, `/hitl:dev-start-migration`, `/hitl:dev-practices` (32-step workflow), `/hitl:dev-tdd`, `/hitl:dev-generate-docs`, `/hitl:dev-apply-change`, and role namespaces `/hitl:architect-*`, `/hitl:pm-*`, `/hitl:qa-*`, `/hitl:ops-*` |
| **6 agents** | Architect reviewer, developer implementer, QA reviewer, PM reviewer, ops release reviewer, spec conformance reviewer |
| **5 commands** | `/hitl:dev-check-implementation`, `/hitl:architect-review-design`, `/hitl:architect-verify-traceability`, `/hitl:ops-review-release`, `/hitl:ops-monitor-canary` |
| **Hooks** | Welcome banner, HITL context check, domain boundary enforcement, session summary |

## Documentation

Full documentation, playbooks, role guides, and adoption ladder live in the source repo:

**[github.com/Prasad-Apparaju/hitl-dev-platform](https://github.com/Prasad-Apparaju/hitl-dev-platform)**

## Quick start

Once installed, open Claude Code in your project and run the command that matches your situation:

| Situation | Command |
|-----------|---------|
| New project — greenfield from a PRD | `/hitl:dev-start-prd` |
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
