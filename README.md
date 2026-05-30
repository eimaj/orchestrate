# orchestrate

A generic, recipe-driven orchestrator for Claude Code. One orchestrator, a library of stateless agents, and a declarative recipe for any multi-agent workflow.

The core idea is separation of concerns: the **orchestrator** is the only stateful actor and holds the full mental model across the run. **Agents** are stateless workers. Each agent receives a fully self-contained prompt, returns a structured result, and retains no context between dispatches. The **recipe** declares which agents to use, in what topology (loop / once / fanout), with which exit conditions. Adding a new workflow means adding a JSON file to `recipes/` — no orchestration logic changes.

The invariant across every recipe: **Act → Learn → Retro**. Every run ends in a reflection pass, regardless of whether it succeeded or failed. See [`PATTERN.md`](PATTERN.md) for the full contract.

---

## Quick Start

Install the skills (see [Install](#install)), then invoke from Claude Code:

```
/orchestrate
```

That's it. Step 0 walks you through everything:

1. **What do you want to build?** — paste a goal, a plan file path, or an openspec path. If it's not already a structured manifest, `/orchestrate` will offer to generate one via `/orchestrate-manifest` and show it to you before proceeding.
2. **Which recipe?** — if you didn't name one, you'll be shown the available recipes and asked to pick. `code-writer-once` is a good default for well-scoped work; `code-writer` if you expect the reviewer to iterate.
3. **Confirm the run** — you'll see a summary (recipe, manifest path, artifact destination) before any agents are dispatched.

You can also skip ahead by providing args directly:

```
/orchestrate code-writer-once ~/Code/_notes/plans/my-feature.local.md
/orchestrate "add rate limiting to the payments API"
/orchestrate ~/Code/my-repo/openspec/changes/JIRA-1234.md
```

Providing both args and a valid manifest skips Step 0 entirely — the run dispatches immediately after the final confirmation.

### The other skills

| Skill | When to use |
| --- | --- |
| `/orchestrate-manifest` | Generate a structured manifest from a goal, plan, or spec before running |
| `/orchestrate-recipe` | Build a new recipe interactively (topology, agents, exit guards) |
| `/orchestrate-agent` | Build a new agent interactively (Writer, Reviewer, or custom critic) |

---

## Why it works this way

**Stateless agents** eliminate a class of subtle bugs where an agent's earlier context bleeds into later decisions. By forcing every dispatch to be fully self-contained, you get consistent, auditable behavior — and the ability to swap agent implementations without side effects.

**The manifest as source of truth** means the orchestrator never holds intent purely in memory between cycles. The manifest is re-read fresh at each cycle start. Agents propose changes via `decision_log_entries`; the orchestrator applies them sequentially. The manifest + its Decision Log is the complete audit trail of how intent evolved during the run.

**Recipes as data, not code** means the topology (loop guards, transition states, model assignments, skill composition) is declared in a JSON file that can be read, diffed, and shared without touching any prompt. The extension point is explicit: drop a file in `recipes/`.

**Retro always runs** — including on failure exits — because the most useful signal about what went wrong comes from synthesizing the full run's learnings against the original intent, not from the failure message alone.

---

## Install

```bash
git clone https://github.com/eimaj/orchestrate ~/Code/orchestrate
cd ~/Code/orchestrate
bash install.sh
```

To preview without making changes:

```bash
bash install.sh --dry-run
```

`install.sh` symlinks the repo into `~/.claude` and creates a local config:

- `~/.claude/skills/orchestrate` → `skills/orchestrate/` (exposes the `/orchestrate` skill)
- `~/.claude/skills/orchestrate-manifest` → `skills/orchestrate-manifest/` (exposes `/orchestrate-manifest`)
- `~/.claude/skills/orchestrate-recipe` → `skills/orchestrate-recipe/` (exposes `/orchestrate-recipe`)
- `~/.claude/skills/orchestrate-agent` → `skills/orchestrate-agent/` (exposes `/orchestrate-agent`)
- `config.json` — copied from `config.example.json` into the repo root (gitignored; stays local)

### Logging (optional)

Orchestrate integrates with [clog](https://github.com/eimaj/clog) for structured run logging. When clog is present, every dispatch, join, learning, and commit is logged in real time with a `--session` ID that links all entries for a run. When clog is absent the orchestrator falls back to direct JSONL append — runs never fail due to missing logging.

```bash
bash install-clog.sh --path ~/Code/clog
```

---

## Configure

`install.sh` creates `config.json` from the example template. Edit it to match your environment:

```json
{
  "artifact_root": "~/.orchestrate/runs",
  "clog": {
    "enabled": null,
    "bin": "~/.claude/hooks/clog.sh",
    "repo": "https://github.com/eimaj/clog",
    "fallback": {
      "jsonl": "{artifact_root}/logs/YYYYMMDD.jsonl"
    }
  }
}
```

**`artifact_root`** — where run artifacts (manifest, learnings, retro) are written. Supports `~` expansion. Change it to wherever you keep orchestration notes (e.g. `~/Code/_notes/orchestra`).

**`clog.enabled`** — logging mode. `null` = auto-detect: checks for `clog` on PATH, then `~/.claude/hooks/clog.sh`. Set to `true` to force clog on (fails if not installed), `false` to force it off and always use the JSONL fallback.

**`clog.bin`** — path to the clog executable. Resolved at startup when `enabled` is `null` or `true`. Only needs to change if you installed clog somewhere non-standard.

**`clog.repo`** — upstream clog source, used by `install-clog.sh` to clone. No effect at runtime.

**`clog.fallback.jsonl`** — path template for the JSONL fallback log, used when clog is absent or disabled. `{artifact_root}` is substituted at runtime. `YYYYMMDD` is substituted with the current date, producing one file per day.

---

## Run

Before running, you need a manifest — a structured document with four sections: `Requirements`, `Approach`, `Operations` (with a `files` scope per sub-task), and `Safeguards`. The orchestrator copies the file into the run directory and stamps it with `recipeVersion`, but it does not generate or rewrite the content. What you pass in is what it works from.

Three ways to get a manifest:

**1. Generate one** — give `/orchestrate-manifest` a goal, a plan file, or an openspec path:

```bash
/orchestrate-manifest "add rate limiting to the payments API"
/orchestrate-manifest ~/Code/_notes/plans/2026-05-29-my-feature.local.md
```

**2. Pass a plan or openspec directly** — a `/plan-workflow` plan or an openspec document works as a manifest if it already contains (or approximates) the four required sections. The orchestrator validates the structure before firing any agents and will tell you exactly which sections are missing, with a suggested `/orchestrate-manifest` command to fix it.

**3. Write one manually** — any markdown file with the four sections is valid.

Then run the orchestrator — both args are optional, Step 0 handles anything missing:

```bash
/orchestrate [recipe-name] [manifest-path-or-input]
```

Example:

```bash
/orchestrate code-writer ~/.orchestrate/runs/my-feature/manifest.md
```

---

## Recipes

A recipe declares the topology and agents for a run. Recipes are user-specific — the repo does not ship runnable recipes; it ships reference examples.

- **`recipes/*.example.json`** — reference examples. Unlike agent templates, they are fully valid JSON and runnable as-is (with `skills` starting empty as `{}`). Copy one to get started:
  ```bash
  cp recipes/code-writer.example.json recipes/local/code-writer.json
  # then edit to match your workflow
  ```
- **`recipes/local/`** — where your runnable recipes live. This directory is gitignored and never committed (only `.gitkeep` is tracked).
- **`/orchestrate-recipe`** — build a recipe interactively. Walks through topology, agents, exit guards, and skills, then writes to `recipes/local/<name>.json`.

The orchestrator resolves each recipe name by checking `recipes/local/<name>.json` first, then falling back to `recipes/<name>.example.json`. If neither exists, the run fast-fails with a pointer to `/orchestrate-recipe`.

| Example | Topology | When to use |
| --- | --- | --- |
| `code-writer` | Loop (≤3 write/review cycles) | Phased implementation where the reviewer may request changes |
| `code-writer-once` | Once (single pass) | Well-scoped work unlikely to need revision |
| `feature-scoper` | Loop (≤3 scope cycles) | Feature scoping loop — requires custom agents — see [Agents](#agents) |

The schema is small — `recipeVersion`, `steps`, `skills`, and optional loop guards (`exit`, `transitions`).

**Skill injection.** The recipe's `skills` map composes skills into agent prompts at dispatch time. A `_shared` key injects its skills into every agent in the run; a key matching an agent name (e.g. `"writer"`) injects only into that agent. Skill injection is recipe-only — there is no global or domain-level default.

---

## Agents

Agents are user-specific — a developer's retro differs from a product designer's, a Go backend writer differs from a React writer. The repo does not ship runnable agents; it ships reference templates.

- **`prompts/agents/*.example.md`** — reference templates. Copy one to get started:
  ```bash
  cp prompts/agents/writer.example.md prompts/agents/local/writer.md
  # then edit the persona and work step to match your domain
  ```
- **`prompts/agents/local/`** — where your runnable agents live. This directory is gitignored and never committed (only `.gitkeep` is tracked).
- **`/orchestrate-agent`** — build an agent interactively. Walks through role, persona, work step, and (for critics) verdict vocabulary, then writes to `prompts/agents/local/<name>.md`.

The orchestrator resolves each agent named in a recipe's `steps` by checking `prompts/agents/local/<name>.md` first, then falling back to `prompts/agents/<name>.example.md`. If neither exists — or the resolved file still has `[TODO]` placeholders — the run fast-fails with a pointer to `/orchestrate-agent`.

---

## Artifacts

Each run creates a directory under `artifact_root`:

```
{artifact_root}/runs/<session_id>/
  manifest.md     — input plan, stamped with recipeVersion; Decision Log appended as the run progresses
  learnings.md    — progressive learnings from every agent, written immediately after each step (each agent's `## Learnings` section is aggregated into `learnings.md`)
  retro.md        — run report (what changed, alignment against original intent) + improvement proposals
```

The `session_id` format is `<YYYYMMDD_HHMMSS>-<slug>` — date-first for natural sort order, where `<slug>` is the recipe name plus the manifest basename (e.g. `code-writer-my-feature`). Every log entry and artifact for a run shares this ID.

---

## Logging

See [eimaj/clog](https://github.com/eimaj/clog) for type definitions, KPI flags, and setup.
