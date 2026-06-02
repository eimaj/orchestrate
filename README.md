# orchestrate

**orchestrate is a Claude Code slash-command that runs a goal through a team of AI agents — one writes, one reviews, one reflects — and saves every artifact so the run is auditable and repeatable.** It's for developers who want multi-agent write/review/retro cycles against a coding task without hand-rolling the orchestration logic each time.

You describe a goal (or hand it a plan file). orchestrate writes down the intent, dispatches a writer agent to do the work, a reviewer agent to critique it, and a retro agent to reflect on how it went — then leaves you a folder of artifacts you can read, replay, and learn from.

---

## Key terms

These four words appear throughout this README. Read them once and the rest will make sense.

| Term | Plain-English meaning |
| --- | --- |
| **Brief** | The intent file (`brief.md`). Captures your goal, constraints, acceptance criteria, and a running Decision Log. Written *before* any agent runs, and re-read fresh at every cycle so intent never drifts. |
| **Agent** | A stateless AI worker (writer, reviewer, retro, or your own). Each gets one self-contained prompt, returns one structured result, and remembers nothing between runs. |
| **Recipe** | A JSON file declaring *which* agents run and *in what shape* (the "topology"): once, in a loop, or fanned out in parallel. |
| **Topology** | The shape of a recipe's run: **once** (single pass), **loop** (repeat write/review up to N times), or **fanout** (run agents in parallel). |
| `{artifact_root}` | The folder where every run's files land. Defaults to `~/.orchestrate/`. Set it in `config.json` (see [Configure](#configure)). |

The one rule every recipe obeys: **Act → Learn → Retro**. Work happens, learnings are captured as they occur, and a reflection pass closes *every* run — even one that failed. See [`docs/PATTERN.md`](docs/PATTERN.md) for the full contract.

---

## Prerequisites

- **[Claude Code](https://docs.claude.com/en/docs/claude-code)** — orchestrate is a set of Claude Code skills (slash commands). You invoke them from inside a Claude Code session.
- **git** and **bash** — to clone and install.
- **(Optional) [clog](https://github.com/eimaj/clog)** — a structured logging tool. If present, orchestrate logs each step in real time. If absent, it falls back to writing a plain JSONL file — nothing breaks either way. You do **not** need clog to use orchestrate.

---

## Quick Start

**1. Install the skills** (one time):

```bash
git clone https://github.com/eimaj/orchestrate ~/Code/orchestrate
cd ~/Code/orchestrate
bash install.sh
```

This symlinks the skills into `~/.claude` and creates a local `config.json`. See [Install](#install) for exactly what it does.

**2. Copy one recipe and one set of agents** (one time). The repo ships *examples*, not runnable files — you copy them into gitignored `local/` folders so your edits stay yours:

```bash
# A recipe (defines the writer → reviewer → retro flow):
cp recipes/code-writer-once.example.json recipes/local/code-writer-once.json

# The three agents that recipe names:
cp prompts/agents/writer.example.md   prompts/agents/local/writer.md
cp prompts/agents/reviewer.example.md prompts/agents/local/reviewer.md
cp prompts/agents/retro.example.md    prompts/agents/local/retro.md
```

> The example agent templates contain `[TODO]` placeholders for persona and domain. Edit them before your first run — a run fast-fails if a resolved agent still has `[TODO]` markers. See [Agents](#agents).

**3. Run it** from inside a Claude Code session:

```
/orchestrate "add rate limiting to the payments API"
```

orchestrate asks you three quick questions (scope and acceptance criteria), writes a `brief.md`, shows you a summary, and — once you confirm — dispatches the agents. When it finishes, your artifacts are in `{artifact_root}/runs/<run-id>/` (see [Artifacts](#artifacts)).

---

## Why it works this way

(Skip this on your first read — it's the rationale, not the how-to.)

**Stateless agents** eliminate a class of bugs where an agent's earlier context bleeds into later decisions. Every dispatch is fully self-contained, so behavior is consistent and auditable, and you can swap an agent's implementation with no side effects.

**The brief is the source of truth.** The orchestrator never holds intent in memory between cycles — it re-reads `brief.md` fresh at each cycle. Agents propose changes to intent via Decision Log entries; the orchestrator applies them. The brief plus its Decision Log is the complete record of how intent evolved.

**Recipes are data, not code.** Topology, loop guards, model assignments, and skill composition all live in a JSON file you can read, diff, and share without touching any prompt. Adding a new workflow means adding a recipe file — the orchestration logic never changes.

**Retro always runs** — including on failure — because the most useful signal about what went wrong comes from synthesizing the whole run's learnings against the original intent, not from the failure message alone.

---

## Install

```bash
git clone https://github.com/eimaj/orchestrate ~/Code/orchestrate
cd ~/Code/orchestrate
bash install.sh
```

To preview every action without changing anything:

```bash
bash install.sh --dry-run
```

`install.sh` does exactly two things:

1. **Symlinks four skills into `~/.claude/skills/`** so Claude Code exposes them as slash commands:
   - `orchestrate` → the `/orchestrate` command (run a goal through the agents)
   - `orchestrate-brief` → `/orchestrate-brief` (generate a structured brief up front)
   - `orchestrate-recipe` → `/orchestrate-recipe` (build a new recipe interactively)
   - `orchestrate-agent` → `/orchestrate-agent` (build a new agent interactively)
2. **Creates `config.json`** in the repo root by copying `config.example.json`. This file is gitignored and stays local — edit it to set your `artifact_root` (see [Configure](#configure)).

**If something goes wrong:**

- *"`<link> already exists — skipping"`* — a skill is already installed (or a leftover file is in the way). The installer never overwrites. To relink, remove the existing path under `~/.claude/skills/` manually and re-run.
- *"`config.json already exists — skipping"`* — your config is preserved on re-install. Delete it first if you want a fresh copy from the example.
- *The `/orchestrate` command doesn't appear in Claude Code* — confirm the symlinks exist under `~/.claude/skills/`, then restart your Claude Code session so it re-scans skills.

### Logging (optional)

Orchestrate integrates with [clog](https://github.com/eimaj/clog) for structured run logging. When clog is present, every dispatch, join, learning, and commit is logged in real time with a `--session` ID that links all entries for a run. When clog is absent the orchestrator falls back to direct JSONL append — **runs never fail due to missing logging.** Install clog only if you want it:

```bash
bash install-clog.sh --path ~/Code/clog
```

---

## Configure

`install.sh` creates `config.json` from the example template. Open it and set `artifact_root` to taste; the defaults work as-is otherwise.

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

**`artifact_root`** — the folder where every run's files (brief, learnings, retro) are written. `~` is expanded to your home directory. Point it wherever you keep notes, e.g. `~/Code/_notes/orchestra`.

**The `clog` block is entirely optional** — it only governs the optional logging tool described in [Install](#install). If you don't use clog, leave it at its defaults and ignore it.

- **`clog.enabled`** — `null` (default) auto-detects clog: checks your PATH, then `~/.claude/hooks/clog.sh`. Set `true` to require clog (the run errors if it's missing), or `false` to always use the plain-JSONL fallback.
- **`clog.bin`** — path to the clog executable. Only change it if you installed clog somewhere non-standard.
- **`clog.repo`** — where `install-clog.sh` clones clog from. No effect at runtime.
- **`clog.fallback.jsonl`** — where the plain-JSONL log is written when clog isn't used. `{artifact_root}` is substituted with your configured root, and `YYYYMMDD` with today's date, giving one log file per day.

---

## Run

Invoke `/orchestrate` from inside a Claude Code session. There are three ways to start, depending on what you already have. **Both arguments are optional** — anything you leave out, orchestrate asks for interactively:

```
/orchestrate [recipe-name] [goal-string-or-file-path]
```

**Way 1 — Free-form goal (simplest).** Just describe what you want. orchestrate asks three questions (scope, acceptance criteria), writes `brief.md`, and dispatches:

```
/orchestrate "add rate limiting to the payments API"
/orchestrate code-writer-once "refactor the auth middleware to use the new token service"
```

**Way 2 — Pass a plan or spec file.** Point orchestrate at an existing plan or [openspec](https://github.com/Fission-AI/OpenSpec) change file. It runs the same three-question intake using the file as the goal source. For large or parallel work, run `/orchestrate-brief` on the file first to produce a structured `brief.md` with explicit file scoping:

```
/orchestrate ~/Code/_notes/plans/2026-05-29-my-feature.local.md

# For large/parallel work, build the brief first, then run it:
/orchestrate-brief ~/Code/my-repo/openspec/changes/JIRA-1234.md
/orchestrate code-writer-once ~/.orchestrate/runs/<run-id>/brief.md
```

**Way 3 — Pass an existing `brief.md`.** If you already have a brief (from a prior run or from `/orchestrate-brief`), pass it directly. The intake questions are skipped — the run dispatches right after you confirm the recipe:

```
/orchestrate code-writer ~/.orchestrate/runs/my-feature/brief.md
```

### Choosing a recipe

If you don't name a recipe, orchestrate lists the available ones and asks you to pick. Two good starting points (both shipped as examples):

| Recipe | Use when | Topology |
| --- | --- | --- |
| `code-writer-once` | The change is well-scoped with clear acceptance criteria — one pass is enough | Once (single write/review pass) |
| `code-writer` | You expect reviewer pushback or need a few iterations | Loop (≤3 write/review cycles) |

### The companion commands

| Command | What it's for |
| --- | --- |
| `/orchestrate-brief` | Generate a structured `brief.md` with explicit file scoping. Use before `/orchestrate` for large or parallel work; for simple runs, `/orchestrate` builds the brief inline. |
| `/orchestrate-recipe` | Build a new recipe interactively — walks you through topology, agents, and exit guards, then writes to `recipes/local/<name>.json`. |
| `/orchestrate-agent` | Build a new agent interactively — walks you through role, persona, and work step, then writes to `prompts/agents/local/<name>.md`. |

---

## Recipes

A **recipe** is a JSON file that declares which agents run and in what topology. Recipes are user-specific, so the repo ships **reference examples** (`*.example.json`), not files you run directly. You copy an example into the gitignored `recipes/local/` folder and edit it.

**Copy one to get started:**

```bash
cp recipes/code-writer-once.example.json recipes/local/code-writer-once.json
# then edit to match your workflow
```

**How the orchestrator finds a recipe:** given a recipe name, it checks `recipes/local/<name>.json` first, then falls back to `recipes/<name>.example.json`. If neither exists, the run fast-fails and points you at `/orchestrate-recipe`.

A recipe looks like this (the `code-writer-once` example):

```json
{
  "recipeVersion": 1,
  "name": "code-writer-once",
  "description": "Implement a plan in a single write/review pass, then retro.",
  "execution": "sequential",
  "interactive": "none",
  "steps": [
    { "name": "write",  "type": "single", "agent": "writer",   "model": "sonnet" },
    { "name": "review", "type": "single", "agent": "reviewer", "model": "sonnet" },
    { "name": "retro",  "type": "single", "agent": "retro",    "model": "opus"   }
  ],
  "skills": {
    "_shared": [],
    "writer": [],
    "reviewer": []
  }
}
```

- **`steps`** — the agents to run, in order. Each names an `agent` (resolved from `prompts/agents/`, see [Agents](#agents)) and the Claude `model` to dispatch it with.
- **`skills`** — optionally injects Claude Code skills into agent prompts at dispatch time. The `_shared` key injects into *every* agent; a key matching an agent name injects only into that agent. Leave these empty (`[]`) to start.

Example recipes shipped in the repo:

| Example | When to use | Topology |
| --- | --- | --- |
| `code-writer` | Multi-step feature where you expect reviewer pushback | Loop (≤3 write/review cycles) |
| `code-writer-once` | Well-scoped change, one pass is enough | Once (single pass) |
| `feature-scoper` | Turning a rough idea into a technical spec with product-level review (needs custom agents) | Loop (≤3 scope cycles) |

---

## Agents

An **agent** is a stateless AI worker that does one job in a run — writing code, reviewing it, or running the retro. Like recipes, agents are user-specific, so the repo ships **reference templates** (`*.example.md`), not runnable files.

**Copy the ones your recipe names.** For `code-writer-once`, that's all three:

```bash
cp prompts/agents/writer.example.md   prompts/agents/local/writer.md
cp prompts/agents/reviewer.example.md prompts/agents/local/reviewer.md
cp prompts/agents/retro.example.md    prompts/agents/local/retro.md
# then edit the persona and work step in each to match your domain
```

> **The example templates contain `[TODO]` placeholders** for persona and domain-specific instructions. You must fill them in — a run fast-fails if a resolved agent still has `[TODO]` in its persona line or work step. Run `/orchestrate-agent` for a guided walkthrough, or edit the files directly.

A template opens like this:

```markdown
# Writer

You are [TODO: persona — e.g. "a senior Go backend engineer"].
Your only job is to implement the goal described in the brief — minimally, correctly, and within scope.

## Inputs (everything you need — you have NO other context)

- `{{brief_path}}`            — path to brief.md (Goal / Constraints / Acceptance criteria + Decision Log)
- `{{working_dir}}`           — working directory for all file operations
- `{{file_paths}}`            — files to read before implementing
- `{{prior_critic_feedback}}` — feedback from the previous reviewer cycle, or "N/A"
...
```

The `{{...}}` tokens are filled in by the orchestrator at dispatch time. You write the persona and instructions around them — you don't set the token values yourself.

**How the orchestrator finds an agent:** given an agent name from a recipe's `steps`, it checks `prompts/agents/local/<name>.md` first, then falls back to `prompts/agents/<name>.example.md`. If neither exists — or the resolved file still has `[TODO]` placeholders — the run fast-fails and points you at `/orchestrate-agent`.

---

## Artifacts

Each run creates a directory under `{artifact_root}` (default `~/.orchestrate/`, configurable in [Configure](#configure)):

```
{artifact_root}/runs/<run-id>/
  brief.md      — written before any agent fires; captures goal, constraints,
                  and acceptance criteria; the Decision Log is appended here during the run
  learnings.md  — learnings from every agent, written right after each step
                  (structured as: ## Cycle N → ### Writer → ### Reviewer)
  retro.md      — run report (what changed, alignment against intent) plus
                  improvement proposals
```

The `<run-id>` format is `<YYYYMMDD_HHMMSS>-<slug>` — date-first so runs sort naturally, where `<slug>` is the recipe name plus the brief source (e.g. `20260529_143000-code-writer-add-oauth`). Every artifact and log entry for a run shares this ID.

---

## Learn more

- [`docs/PATTERN.md`](docs/PATTERN.md) — the full Act → Learn → Retro contract every recipe obeys.
- [eimaj/clog](https://github.com/eimaj/clog) — the optional logging tool, with type definitions, KPI flags, and setup.
