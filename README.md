# HITL Dev Platform — Claude Code Plugin

A [Claude Code](https://docs.anthropic.com/en/docs/claude-code) plugin for the **HITL AI-Driven Development** process — a document-driven delivery model for teams using AI heavily in non-trivial software work.

## Install

```bash
claude plugins install pappar/hitl-claude-plugin
```

## Update

```bash
claude plugins update hitl-claude-plugin
```

## What you get

| Component | Contents |
|-----------|----------|
| **40 skills** | `/start-prd`, `/start-brownfield`, `/start-migration`, `/dev-practices` (32-step workflow), `/tdd`, `/generate-docs`, `/apply-change`, and role namespaces `/architect:*`, `/pm:*`, `/qa:*`, `/ops:*` |
| **6 agents** | Architect reviewer, developer implementer, QA reviewer, PM reviewer, ops release reviewer, spec conformance reviewer |
| **5 commands** | `/check-implementation`, `/architect:review-design`, `/architect:verify-traceability`, `/ops:review-release`, `/ops:monitor-canary` |
| **Hooks** | Welcome banner, HITL context check, domain boundary enforcement, session summary |

## Documentation

Full documentation, playbooks, role guides, and adoption ladder live in the source repo:

**[github.com/Prasad-Apparaju/hitl-dev-platform](https://github.com/Prasad-Apparaju/hitl-dev-platform)**

## Quick start

Once installed, open Claude Code in your project and run the command that matches your situation:

| Situation | Command |
|-----------|---------|
| New project — greenfield from a PRD | `/start-prd` |
| Existing codebase — adopt the process | `/start-brownfield` |
| Migrating a system | `/start-migration` |
| Already set up — start a change | `/dev-practices` |

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

# Review, commit, push
git diff --stat
git add -A && git commit -m "chore: rebuild from hitl-dev-platform"
git push
```

The same source can be used to build plugins for other AI platforms (e.g. Codex) by following the same build pattern with a platform-specific manifest and hooks.

## License

MIT
