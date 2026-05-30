---
name: orchestrate
description: Generic recipe-driven orchestrator — dispatch stateless agents (Writer/Reviewer/Retro/etc.) against a manifest via a named recipe. Use when a phased plan needs multi-agent execution with a retro.
---

# Orchestrate

## Trigger

**Use when:** executing a phased plan with write/review cycles, a feature-scoping loop, or any multi-agent recipe that ends in a retro. **Do not use when:** the task is a hotfix, exploratory spike, one-off script, aesthetic cleanup (renaming/formatting), or anything you'd finish in under ~30 minutes faster without the overhead. **Inputs accepted:** a free-form goal, a plan file path, an openspec spec path, or a valid `manifest.md` path — plus an optional recipe name. Step 0 handles intake interactively when either is missing or unvalidated. **Outputs produced:** `manifest.md` (with Decision Log), `learnings.md`, and `retro.md` under `{artifact_root}/runs/<session_id>/`. **Capture learnings:** after a session with this skill, log signals via: `clog LEARNING "<observation>" --family orchestrate --kpi <failure|prompt_gap|token_waste|effective|format_issue>`

> **Last Reviewed**: 2026-05-30 **Refresh Rule**: Event-driven — update when a new recipe topology, agent, or handler is added, or when the config schema changes.

## Related Skills

- `dev-orchestrate` — the predecessor; `code-writer` recipe is the generalized equivalent
- `orchestrate-recipe` — interactively author a new recipe before invoking the orchestrator
- `worktree` — create a git worktree before orchestration when working in isolation
- `plan-workflow` — produce the manifest that feeds orchestration

---

## Invocation

```
/orchestrate [recipe-name] [manifest-path-or-input]
```

Examples:

```
/orchestrate code-writer ~/Code/_notes/orchestra/my-feature/manifest.md
/orchestrate feature-scoper ~/Code/_notes/plans/2026-06-01-new-feature.md
/orchestrate code-writer-once ~/Code/_notes/orchestra/quick-fix/manifest.md
/orchestrate "add rate limiting to the payments API"
/orchestrate ~/Code/_notes/plans/2026-05-30-my-feature.local.md
```

---

## Step 0: Intake

Step 0 fires whenever either arg is missing or the input is not a validated manifest. It is a blocking conversational gate — execution does not proceed until the user confirms at each step.

### 0a — Manifest gate

Inspect the provided path or goal:

- If the file exists **and** contains all four headings (`## Requirements`, `## Approach`, `## Operations`, `## Safeguards`) → skip to **0b**.
- Otherwise → the input needs to be converted. Ask first:

> "Your input (`<path or goal summary>`) is a `<plan / spec / prompt>`, not a manifest. I'll run `/orchestrate-manifest` to translate it into a structured manifest with Requirements, Approach, Operations (with file scopes), and Safeguards. Shall I proceed?"

Wait for confirmation. Then invoke `/orchestrate-manifest <input>`. After it completes, open the result:

```bash
code ~/.orchestrate/runs/<session_id>/manifest.md
```

Then ask:

> "Here's the generated manifest at `<path>`. Does this look right? (yes / edit first / cancel)"

Do not advance to 0b until the user says yes.

### 0b — Recipe gate

If a recipe was named and resolves (`recipes/local/<name>.json` or `recipes/<name>.example.json` exists) → skip to **0c**.

Otherwise, present the available recipes:

| Recipe | Topology | Best for |
| --- | --- | --- |
| `code-writer` | loop ≤3 cycles | Feature work that may need iteration |
| `code-writer-once` | single pass | Well-defined change, clear acceptance criteria |
| `feature-scoper` | loop ≤3 cycles | Spec/scoping with product review |

Ask:

> "Which recipe should I use? (or describe what you need and I'll suggest one)"

After the user picks, confirm the selection before moving on.

### 0c — Launch confirmation

Before dispatching, show a summary block:

> **Recipe:** `<name>` (`<topology>`)
> **Manifest:** `<path>`
> **Artifacts will land in:** `{artifact_root}/runs/<session_id>/`
>
> Ready to proceed?

Do not dispatch until the user confirms.

---

## Inputs

- **`[recipe-name]`** *(optional)* — name of a recipe resolved as `recipes/local/<name>.json` then `recipes/<name>.example.json`. If omitted or unresolvable, Step 0b prompts for selection.
- **`[manifest-path-or-input]`** *(optional)* — absolute path to a valid `manifest.md`, a plan file, an openspec spec, or a free-form goal string. If not a valid manifest, Step 0a handles conversion via `/orchestrate-manifest`.

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
