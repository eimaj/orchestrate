---
name: orchestrate-recipe
description: Interactively author a new orchestrate recipe via natural language and write it to recipes/local/<name>.json. Use when you need a new recipe and don't want to hand-edit JSON.
disable-model-invocation: true
---

# Create Recipe

## Trigger

**Use when:** you want a new orchestration recipe and want guided authoring — topology, agents, exit guards, skills, and interactive mode — before invoking `/orchestrate`. **Do not use when:** you're modifying an existing recipe (edit the JSON directly), or you already know the schema well enough to write it by hand. **Inputs expected:** a description of what you want the recipe to do (natural language). **Outputs produced:** `recipes/local/<name>.json` written to the orchestrate repo (gitignored), confirmed before writing. **Capture learnings:** after a session with this skill, log signals via: `clog LEARNING "<observation>" --family orchestrate --kpi <failure|prompt_gap|token_waste|effective|format_issue>`

> **Last Reviewed**: 2026-05-29 **Refresh Rule**: Event-driven — update when the recipe schema changes or the authoring flow is implemented.

## Related Skills

- [`orchestrate`](../orchestrate/SKILL.md) — run the recipe once it's created
- [`dev-orchestrate`](../dev-orchestrate/SKILL.md) — predecessor; `code-writer` recipe covers the same use case

---

## Invocation

```
/orchestrate-recipe
```

---

## Starting from a template

At the start of the authoring flow, ask:

> Would you like to start from an example recipe as a template? Available templates: `<list recipes/*.example.json, without path or extension>`

- **If yes** — load that example's JSON as the starting point and walk through modifying each field (name, topology, agents, exit guards, skills, interactive mode).
- **If no** — start from the minimal skeleton and build up field by field.

---

## What it does

Walks you through the decisions needed to build a valid recipe:

1. **Name and description** — what this recipe is called and what it does.
2. **Topology** — `loop` (producer/critic cycles with a guard), `single` (once through), or `fanout` (parallel sub-tasks).
3. **Agents** — which agents to use for producer and critic roles.
4. **Exit guards** — `maxCycles`, `churnThreshold`, custom `transitions` vocabulary.
5. **Skills** — role-level skills; domain skills are resolved at runtime from `config.json`.
6. **Interactive mode** — `none` (headless-safe, default), `cycle` (gate after each verdict), or `full` (gate before every dispatch).

Shows the resulting JSON and asks for confirmation before writing to `recipes/local/<name>.json`.

On success, confirm: the recipe was written to `recipes/local/<name>.json`, which is gitignored and will not be committed.

---

## Execution Steps

1. **Ask for a description** — "What should this recipe do? Describe the workflow in a sentence or two."

2. **Offer a template** — List available example recipes (`recipes/*.example.json`, names without path or extension). Ask: "Would you like to start from one of these examples, or build from scratch?"
   - If from example: load that JSON as the starting point. Present each field and ask to confirm or change.
   - If from scratch: build from the minimal skeleton below and fill in each field interactively.

3. **Walk through each field in order:**

   **a. Name** — "What should this recipe be called? (This becomes the filename `recipes/local/<name>.json`.)"

   **b. Description** — "Describe what this recipe does in one sentence."

   **c. Topology** — "What execution pattern do you need?"
   - `loop` — producer/critic cycles with a guard (e.g. write/review, scope/approve)
   - `single` (sequential) — agents run once in order, no cycles
   - `fanout` — parallel sub-tasks, each handled by a separate agent

   **d. Steps** — for each step:
   - Step name
   - Step type (loop / single / fanout)
   - For `loop`: producer agent name, critic agent name, `maxCycles` (default 3), custom transition vocabulary (or use defaults: `APPROVED → exit-success`, `NEEDS_WORK → continue`)
   - For `single`: agent name
   - For `fanout`: source step, list of agent names

   **e. Skills** — "Do any agents need specific skills injected? List per-agent skills, or add shared skills under `_shared`." Present the current agent list and ask for each. Empty arrays are fine — agents work without skills.

   **f. Interactive mode** — "Should the orchestrator pause for your input during the run?"
   - `none` (default) — fully headless, no pauses
   - `cycle` — pause after each critic verdict
   - `full` — pause before every agent dispatch

4. **Preview the JSON** — show the assembled recipe and ask: "Does this look right? Confirm to write, or tell me what to change."

5. **Write** to `recipes/local/<name>.json` on confirmation.

6. **Report success:**
   > Recipe written to `recipes/local/<name>.json`. This file is gitignored and won't be committed. Next: make sure you have agents for each agent name in your steps. Run `/orchestrate-agent` for any that are missing.

---

### Minimal skeleton (for scratch builds)

```json
{
  "recipeVersion": 1,
  "name": "",
  "description": "",
  "execution": "sequential",
  "interactive": "none",
  "steps": [],
  "skills": {
    "_shared": []
  }
}
```

---

## Manual alternative

Copy an example recipe to `recipes/local/` and edit the fields. The schema is documented in: `~/Code/_notes/plans/2026-05-27-orchestrate-pattern.local.md` §6.

Example recipes to copy from:

| Example | Good base for |
| --- | --- |
| `code-writer.example.json` | Any loop-based producer/critic workflow |
| `code-writer-once.example.json` | Single-pass workflows |
| `feature-scoper.example.json` | Non-code producer/critic loops with custom verdicts |

```bash
cp recipes/code-writer.example.json recipes/local/my-recipe.json
# then edit to match your workflow
```

---

## After your recipe is created

Once your recipe is created, make sure you have agents for each agent name referenced in `steps`. Run `/orchestrate-agent` for any that are missing.

---

## Signal Keywords

<!-- Comma-separated terms the skills collector uses to attribute learnings to this skill -->

orchestrate-recipe, recipe authoring, topology, loop, fanout, sequential, exit guards, transitions, interactive mode
