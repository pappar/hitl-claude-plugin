---
name: qa-review-tests
description: Formal QA review of test coverage after the TDD RED phase. Verifies every acceptance criterion has a test, every LLD error mode is exercised, and all relevant incident regressions are present. Gates implementation start.
argument-hint: "[feature name, PR link, or LLD path]"
disable-model-invocation: true
---

# Review Test Coverage

Verify that the test suite produced by the TDD cycle is complete before implementation begins. This is a blocking gate — do not approve if coverage gaps exist.

**Input:** $ARGUMENTS (feature name, PR link, or LLD path)

---

## Step 1 — Read the spec

1. Read the GitHub issue to get the PRD reference (FR-<ID>), then read `docs/01-product/prd.md` at that requirement for the acceptance criteria. The PRD is the source of truth — the issue is a pointer.
2. Read the LLD at the path in `.hitl/current-change.yaml` (`source_artifacts.lld`) — note every method signature, error mode, precondition, and boundary entity
3. Read the test plan from `.hitl/current-change.yaml` under `tests.plan` — this is what the developer committed to covering
4. List the test files in `tests/` — read them

---

## Step 2 — Check incident regressions

Query the incident registry for the affected domain — prefer a graph query:
```
/graphify query "past incidents affecting domain: <domain-name>"
/graphify query "incident failure modes in <domain-name> that need regression coverage"
```
Fall back to reading `docs/04-operations/incident-registry.yaml` directly if the graph is unavailable. For each incident relevant to this domain: verify a regression test exists that would have caught it. If no incidents exist for this domain, say so explicitly — do not skip the check.

---

## Step 3 — Coverage matrix

For each item in the spec, confirm test coverage:

| Spec item | Source | Test(s) | Status |
|-----------|--------|---------|--------|
| `<AC from PRD>` | PRD (FR-<ID>) | `<test name>` | ✅ / ❌ |
| `<method + error mode from LLD>` | LLD | `<test name>` | ✅ / ❌ |
| `<incident regression>` | Incident registry | `<test name>` | ✅ / ❌ |

Flag every ❌ as a gap that must be resolved before implementation starts.

---

## Step 4 — Verify measured coverage

Check `.hitl/current-change.yaml` under `required_evidence.coverage_pct`.

**If `coverage_pct` is missing or below 90%:** Block immediately.
> "Coverage gate not met. The TDD cycle must produce ≥90% line coverage before QA review proceeds. Ask the developer to run the coverage check from Phase 6 of `/tdd` and record the result in `.hitl/current-change.yaml` under `required_evidence.coverage_pct`."

**If `coverage_pct` ≥ 90%:** note it in the approval report and proceed to Step 5.

---

## Step 5 — Approve or block

**If no gaps and coverage ≥ 90%:** Update the test registry at `docs/03-engineering/testing/test-registry.yaml` to record the reviewed tests. Report: "Test coverage approved. `<N>` tests cover `<M>` acceptance criteria, `<K>` LLD error modes, and `<J>` incident regressions. Line coverage: `<coverage_pct>`%. Implementation may proceed."

**If gaps exist or coverage < 90%:** List every gap with the specific spec item it fails to cover. Do not approve. Report: "Test coverage blocked. `<N>` gap(s) found — implementation must not start until these are resolved."

