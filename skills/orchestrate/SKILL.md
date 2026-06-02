---
name: orchestrate
description: Generic recipe-driven orchestrator — dispatch stateless agents (Writer/Reviewer/Retro/etc.) against a brief via a named recipe. Use when a phased plan needs multi-agent execution with a retro.
---

# Orchestrate

## Trigger

**Use when:** executing a phased plan with write/review cycles, a feature-scoping loop, or any multi-agent recipe that ends in a retro. **Do not use when:** the task is a hotfix, exploratory spike, one-off script, aesthetic cleanup (renaming/formatting), or anything you'd finish in under ~30 minutes faster without the overhead. **Inputs accepted:** a free-form goal string, a plan file path, an openspec path, or an existing `brief.md` path — plus an optional recipe name. Step 0 classifies the input and handles intake. **Outputs produced:** `brief.md` (with Decision Log), `learnings.md`, and `retro.md` under `{artifact_root}/runs/<session_id>/`. **Capture learnings:** after a session with this skill, log signals via: `clog LEARNING "<observation>" --family orchestrate --kpi <failure|prompt_gap|token_waste|effective|format_issue>`

> **Last Reviewed**: 2026-05-30 **Refresh Rule**: Event-driven — update when a new recipe topology, agent, or handler is added, or when the config schema changes.

## Related Skills

- `dev-orchestrate` — the predecessor; `code-writer` recipe is the generalized equivalent
- `orchestrate-brief` — generate a structured `brief.md` with explicit file scoping, for large or parallel work
- `orchestrate-recipe` — interactively author a new recipe before invoking the orchestrator
- `worktree` — create a git worktree before orchestration when working in isolation
- `plan-workflow` — lightweight planning; output can feed `/orchestrate` directly as a goal

---

## Invocation

```
/orchestrate [recipe-name] [brief-path-or-goal]
```

Examples:

```
/orchestrate code-writer ~/.orchestrate/runs/my-feature/brief.md
/orchestrate feature-scoper ~/Code/_notes/plans/2026-06-01-new-feature.md
/orchestrate code-writer-once "add OAuth token refresh to the payments API"
/orchestrate "add rate limiting to the payments API"
/orchestrate ~/Code/_notes/plans/2026-05-30-my-feature.local.md
```

---

## Step 0: Intake

> **`{artifact_root}`** defaults to `~/.orchestrate/` and is configurable via `config.json`. All run artifacts land in `{artifact_root}/runs/<session_id>/`.

Step 0 fires whenever either arg is missing or the input has not been classified. It is a blocking conversational gate — execution does not proceed until the user confirms at each step.

### 0a — Brief gate

Inspect the provided path or goal:

- **Free-form goal string** (no file path) → skip directly to **0b**. The orchestrator runs three-question intake (goal confirmation, constraints, acceptance criteria) and writes `brief.md` in Step 4 before any agent fires. No action needed here.
- **Existing `brief.md`** (file exists and contains `## Goal`, `## Constraints`, `## Acceptance criteria`) → skip to **0b**. Used as-is.
- **File path that is not a brief** (plan, openspec, other doc) → ask: "I can run `/orchestrate-brief` first to generate a structured brief with explicit file scoping (recommended for large or parallel work), or proceed directly using this file as the goal and run three-question intake. Which do you prefer?" Wait for answer.

### 0b — Recipe gate

If a recipe was named and resolves (`recipes/local/<name>.json` or `recipes/<name>.example.json` exists) → skip to **0c**.

Otherwise, present the available recipes:

| Recipe | When to use | Example |
| --- | --- | --- |
| `code-writer` | Multi-step feature where you expect reviewer pushback or need multiple iterations | `/orchestrate code-writer ~/Code/_notes/plans/my-feature.local.md` |
| `code-writer-once` | Well-scoped change with clear acceptance criteria — one pass is enough | `/orchestrate code-writer-once ~/Code/_notes/plans/quick-fix.local.md` |
| `feature-scoper` | Turning a rough idea into a technical spec, with product-level review cycles | `/orchestrate feature-scoper "add rate limiting to the payments API"` |

Ask:

> "Which recipe should I use? (or describe what you need and I'll suggest one)"

After the user picks, confirm the selection before moving on.

### 0c — Launch confirmation

Before dispatching, show a summary block:

> **Recipe:** `<name>` (`<topology>`)
> **Brief:** `<path or "inline — three-question intake">`
> **Artifacts will land in:** `{artifact_root}/runs/<session_id>/`
>
> Ready to proceed?

Do not dispatch until the user confirms. Once confirmed, the orchestrator writes `brief.md` to `{artifact_root}/runs/<session_id>/` before any agent fires — capturing recipe, session ID, goal, constraints, and acceptance criteria. This is the start-state artifact and Decision Log sink for the entire run.

---

## Inputs

- **`[recipe-name]`** *(optional)* — name of a recipe resolved as `recipes/local/<name>.json` then `recipes/<name>.example.json`. If omitted or unresolvable, Step 0b prompts for selection.
- **`[brief-path-or-goal]`** *(optional)* — absolute path to an existing `brief.md`, a plan file, an openspec spec, or a free-form goal string. Step 0a classifies the input; free-form goals go directly to three-question intake.

---

## What it produces

All artifacts resolve from `artifact_root` (default: `~/.orchestrate/runs/`, configurable in `config.json`):

| File | Description |
| --- | --- |
| `runs/<session_id>/brief.md` | Goal, constraints, acceptance criteria, and Decision Log — written before any agent fires; Decision Log appended during the run |
| `runs/<session_id>/learnings.md` | Progressive learnings from all agents, written after each step. Each cycle follows the structure: `## Cycle N` → `### Writer` → `### Reviewer` |
| `runs/<session_id>/retro.md` | Run report + recommended improvements (always present, even on failure) |

All clog entries carry `--session <session_id>` for full traceability.

---

## Available example recipes

| Recipe | When to use | Topology |
| --- | --- | --- |
| `code-writer` | Multi-step feature where you expect iteration | loop (≤3 cycles) |
| `code-writer-once` | Well-scoped change, one pass is enough | sequential |
| `feature-scoper` | Rough idea → technical spec with product review | loop (≤3 cycles) |

These ship as `recipes/*.example.json`. Copy one to `recipes/local/<name>.json` to run or customize it. Add a recipe: drop a JSON file in `recipes/local/`. No code changes needed. Use `/orchestrate-recipe` to author one interactively.

---

## When NOT to orchestrate

- **Hotfixes** — a one-line bug fix; faster to edit directly.
- **Exploratory spikes** — goal unclear; explore first, orchestrate when you can state a clear goal.
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

orchestrate, recipe, brief, writer, reviewer, retro, stateless agents, code-writer, feature-scoper, loop topology, fanout, sequential, orchestrate-recipe, orchestrate-agent, orchestrate-brief
