---
name: orchestrate
description: Generic recipe-driven orchestrator — dispatch stateless agents (Writer/Reviewer/Retro/etc.) against a manifest via a named recipe. Use when a phased plan needs multi-agent execution with a retro.
---

# Orchestrate

## Trigger

**Use when:** executing a phased plan with write/review cycles, a feature-scoping loop, or any multi-agent recipe that ends in a retro. **Do not use when:** the task is a hotfix, exploratory spike, one-off script, aesthetic cleanup (renaming/formatting), or anything you'd finish in under ~30 minutes faster without the overhead. If there's no manifest yet, run the planner first. **Inputs expected:** a recipe name (resolved from `recipes/local/` then `recipes/*.example.json`) and an absolute path to a `manifest.md`. **Outputs produced:** `manifest.md` (with Decision Log), `learnings.md`, and `retro.md` under `{artifact_root}/runs/<session_id>/`. **Capture learnings:** after a session with this skill, log signals via: `clog LEARNING "<observation>" --family orchestrate --kpi <failure|prompt_gap|token_waste|effective|format_issue>`

> **Last Reviewed**: 2026-05-29 **Refresh Rule**: Event-driven — update when a new recipe topology, agent, or handler is added, or when the config schema changes.

## Related Skills

- `dev-orchestrate` — the predecessor; `code-writer` recipe is the generalized equivalent
- `orchestrate-recipe` — interactively author a new recipe before invoking the orchestrator
- `worktree` — create a git worktree before orchestration when working in isolation
- `plan-workflow` — produce the manifest that feeds orchestration

---

## Invocation

```
/orchestrate <recipe-name> <manifest-path>
```

Examples:

```
/orchestrate code-writer ~/Code/_notes/orchestra/my-feature/manifest.md
/orchestrate feature-scoper ~/Code/_notes/plans/2026-06-01-new-feature.md
/orchestrate code-writer-once ~/Code/_notes/orchestra/quick-fix/manifest.md
```

---

## Inputs

- **`<recipe-name>`** — name of a recipe resolved as `recipes/local/<name>.json` (your own) then `recipes/<name>.example.json` (shipped example), or an inline JSON blob. If neither file exists, the orchestrator lists available examples and exits.
- **`<manifest-path>`** — absolute path to a `manifest.md` with four required sections: `Requirements`, `Approach`, `Operations`, `Safeguards`. Produced by the planner or written manually. A pre-written spec passes through directly.

To produce a manifest first:

```
/orchestrate-manifest <goal>
/orchestrate-manifest <path-to-existing-plan-or-spec>
```

---

## What it produces

All artifacts resolve from `artifact_root` (default: `~/.orchestrate/runs/`, configurable in `config.json`):

| File | Description |
| --- | --- |
| `runs/<session_id>/manifest.md` | Input manifest stamped with `recipeVersion`; Decision Log appended during the run |
| `runs/<session_id>/learnings.md` | Progressive learnings from all agents, written after each step |
| `runs/<session_id>/retro.md` | Run report + recommended improvements (always present, even on failure) |

All clog entries carry `--session <session_id>` for full traceability.

---

## Available example recipes

| Recipe | Topology | Description |
| --- | --- | --- |
| `code-writer` | loop (≤3 cycles) | Write/review cycles then retro |
| `code-writer-once` | sequential | Single write/review pass then retro |
| `feature-scoper` | loop (≤3 cycles) | Technical-writer/product-lead cycles then retro |

These ship as `recipes/*.example.json`. Copy one to `recipes/local/<name>.json` to run or customize it. Add a recipe: drop a JSON file in `recipes/local/`. No code changes needed. Use `/orchestrate-recipe` to author one interactively.

---

## When NOT to orchestrate

- **Hotfixes** — a one-line bug fix; faster to edit directly.
- **Exploratory spikes** — goal unclear; explore first, orchestrate when you have a manifest.
- **One-off scripts** — throwaway code with no need for review history.
- **Aesthetic work** — renaming, formatting, comment cleanup.
- **Anything under ~30 minutes** — if overhead exceeds the task, skip it.
- **Context black holes** — deep interactive debugging that can't be decomposed upfront.

---

## If a recipe or agent can't be found

User recipes live in `recipes/local/` (gitignored); the repo ships reference examples in `recipes/*.example.json`. User agents live in `prompts/agents/local/` (gitignored); the repo ships reference templates in `prompts/agents/*.example.md`.

**If the orchestrator reports a missing recipe** — run `/orchestrate-recipe`. Suggested opening prompt:

```
I want to [describe what you're trying to do]. The target is [backend/web/other].
I need [loop until approved / single pass / parallel subtasks].
```

**If the orchestrator reports a missing agent** — run `/orchestrate-agent`. Suggested opening prompt:

```
I need a [producer/critic] agent called '<name>' for [describe the domain and what it should do].
```

---

## Signal Keywords

<!-- Comma-separated terms the skills collector uses to attribute learnings to this skill -->

orchestrate, recipe, manifest, writer, reviewer, retro, stateless agents, code-writer, feature-scoper, loop topology, fanout, sequential, orchestrate-recipe, orchestrate-agent
