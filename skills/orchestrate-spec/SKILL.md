---
name: orchestrate-spec
description: Turn a goal into an openspec change and then into the structured brief.md that /orchestrate consumes — confirms where the spec lives and whether the ask is one deliverable or several before anything is written. Use before /orchestrate for any work big enough to deserve a spec.
---

# Spec to Brief

## Trigger

**Use when:** you have a goal, or an existing `openspec/changes/<change-id>/` directory, and want a `brief.md` with explicit `Operations` and `files` scoping before invoking `/orchestrate`. **Do not use when:** the task is small enough to describe in a sentence — `/orchestrate` runs three-question intake inline and writes the brief itself. **Inputs expected:** a goal description (natural language) or the path to an openspec change directory containing `proposal.md`, `design.md`, and `tasks.md`. **Outputs produced:** one `brief.md` per change, written to `{artifact_root}/runs/<session_id>/`, with sections `Goal`, `Constraints`, `Acceptance criteria`, `Operations` (with a `files` scope per sub-task), and `Decision Log`. **Capture learnings:** after a session with this skill, log signals via: `clog LEARNING "<observation>" --family orchestrate --kpi <failure|prompt_gap|token_waste|effective|format_issue>`

> **Last Reviewed**: 2026-10-08 **Refresh Rule**: Event-driven — update when the brief schema, the openspec artifact set, or the `openspec` CLI's root resolution changes.

## Related Skills

- [`orchestrate`](../orchestrate/SKILL.md) — run a recipe against the brief this skill produces
- [`orchestrate-recipe`](../orchestrate-recipe/SKILL.md) — author the recipe to pair with the brief
- `openspec` — the spec workflow this skill drives; `/opsx:propose` writes the change directory this skill reads

---

## Invocation

```
/orchestrate-spec <goal>
/orchestrate-spec <path-to-openspec-change-dir>
```

Examples:

```
/orchestrate-spec "add rate limiting to the payments API"
/orchestrate-spec ~/Code/my-repo/openspec/changes/TICKET-42-rate-limiting/
```

A goal runs all four gates below. An existing change directory skips the spec-root gate and the proposal step; the split gate still runs, as a warning.

---

## Gate 1 — Spec root

Nothing is written until the invoker confirms where the spec lives. Repos differ: some keep an `openspec/` folder at the repo root, some keep specs in a separate project folder or a registered store.

1. Run `openspec context` from the working directory. It prints the resolved OpenSpec root.
2. Run `openspec store list` to show registered standalone stores.
3. Ask, with the resolved root and the store list shown verbatim:

   > The spec would be written under `<resolved root>`. Use this root, one of the registered stores, or a different path?

No default. If nothing resolves, offer `openspec init <path>` and stop until the invoker answers.

If the confirmed root is a store, carry its id forward and pass it to `openspec context --store <id>` to confirm the path before proposing. How `/opsx:propose` itself selects a store is unverified against the CLI — check the resolved path first rather than assuming.

---

## Gate 2 — Split

One openspec change is one clear deliverable. Before proposing, restate the goal as a list of deliverables — things that could ship, be reviewed, or be reverted on their own.

- **One deliverable** → proceed with one change.
- **More than one** → present the list and propose one change per deliverable. Wait for the invoker to accept, merge, or drop items. Do not propose until the list is agreed.

Signals that an ask is more than one deliverable: more than one repo or deployable unit; task groups whose `files` scopes cannot be kept disjoint; acceptance criteria that can pass independently of each other. The last one matters most — when two sub-tasks' `files` scopes overlap (the same path in both lists, or one path an ancestor directory of another), the fanout handler in `/orchestrate` logs the collapse and falls back to sequential execution. Nothing errors; the run just loses its parallelism. Catching the split here is what keeps a fanout recipe actually parallel.

For an existing change directory, run the same check against `tasks.md` and `proposal.md`. If it finds more than one deliverable, say so and continue — warn, never block.

---

## Gate 3 — Propose

For each agreed change, invoke `/opsx:propose <change-id>` at the confirmed root. It writes `proposal.md`, `specs/`, `design.md`, and `tasks.md` in one step. Show the invoker the resulting path before moving on.

Skip this gate when the input was an existing change directory.

---

## Gate 4 — Brief

Map each change directory onto a `brief.md`:

| openspec artifact | brief section |
| --- | --- |
| `proposal.md` — why and scope | `Goal`, `Constraints` |
| `specs/` — delta requirements | `Acceptance criteria` |
| `design.md` — approach, things not to touch | `Constraints` |
| `tasks.md` — checklist | `Operations`, one sub-task per task, `files` from the paths the task names |
| — | `Decision Log` — empty on creation; the orchestrator appends during the run |

Rules:

- Extract, do not paraphrase. Field names, paths, commands, and metric names are copied verbatim from the spec.
- A task that names no files gets an empty `files` list and a `[?] no files named in tasks.md` note on the sub-task heading, never inside the list. Do not guess a scope. Say in the report that an empty list makes the fanout handler collapse the run to sequential until it is filled in.
- Wiring files (entry points, registration, build manifests) are easy to omit from `tasks.md`. If `design.md` names them and `tasks.md` does not, add them to the relevant sub-task's `files` and flag the addition.
- One brief per change. A split never produces one merged brief.

`Operations` shape:

```markdown
## Operations

### 1. Add the rate limiter middleware
files:
- services/payments/middleware/ratelimit.go
- services/payments/middleware/ratelimit_test.go

### 2. Wire the middleware into the router  [?] no files named in tasks.md
files:
```

This skill generates `<session_id>` in the orchestrator's format, `<YYYYMMDD_HHMMSS>-<slug>` with the change id as the slug, creates the directory, and writes the brief to:

```
{artifact_root}/runs/<session_id>/brief.md
```

`/orchestrate` then reads it as an existing brief (Step 4 Case A) and copies it into its own run directory. Report each path and the source change directory. Pass the path to `/orchestrate`.

---

## Signal Keywords

<!-- Comma-separated terms the skills collector uses to attribute learnings to this skill -->

orchestrate-spec, openspec, opsx, proposal, design, tasks, spec root, store, split, deliverable, brief, operations, files scope
