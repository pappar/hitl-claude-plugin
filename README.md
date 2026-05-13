# HITL Dev Platform — Claude Code Plugin

A [Claude Code](https://docs.anthropic.com/en/docs/claude-code) plugin for the **HITL AI-Driven Development** process — a document-driven delivery model for teams using AI heavily in non-trivial software work.

## Install

```bash
claude plugins install pappar/hitl-claude-plugin
```

## What you get

| Component | Contents |
|-----------|----------|
| **29 skills** | `/start-prd`, `/start-brownfield`, `/start-migration`, `/dev-practices` (31-step workflow), `/tdd`, `/generate-docs`, `/apply-change`, and role namespaces `/architect:*`, `/pm:*`, `/qa:*`, `/ops:*` |
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

## License

MIT
