---
name: orchestrate-brief
description: Produce a structured brief.md from a goal, plan, or spec — use before /orchestrate when you want explicit file scoping for large or parallel work. For simple one-shot runs, /orchestrate handles brief generation inline via three-question intake.
---

# Generate Brief

## Trigger

**Use when:** you have a goal, plan file, or openspec and want a fully structured `brief.md` with explicit file scoping before invoking `/orchestrate` — recommended for large features, parallel sub-tasks, or any run where scope ambiguity could cause drift. **Do not use when:** you have a simple, well-described goal and are happy to answer three quick questions inline — `/orchestrate` handles that directly. **Inputs expected:** a goal description (natural language), an existing plan file path, or an openspec path. **Outputs produced:** `brief.md` written to `{artifact_root}/runs/<session_id>/` with sections: `Goal`, `Constraints`, `Acceptance criteria`, `Operations` (with `files` scope per sub-task for fanout recipes), and `Decision Log`. **Capture learnings:** after a session with this skill, log signals via: `clog LEARNING "<observation>" --family orchestrate --kpi <failure|prompt_gap|token_waste|effective|format_issue>`

> **Last Reviewed**: 2026-06-02 **Refresh Rule**: Event-driven — update when the brief schema or planner agent changes.

## Related Skills

- [`orchestrate`](../orchestrate/SKILL.md) — run a recipe against the brief this skill produces
- [`orchestrate-recipe`](../orchestrate-recipe/SKILL.md) — author the recipe to pair with the brief
- [`plan-workflow`](../plan-workflow/SKILL.md) — lightweight planning; output can be passed to this skill to produce a brief

---

## Invocation

```
/orchestrate-brief <goal>
/orchestrate-brief <path-to-plan-or-spec>
```

Examples:

```
/orchestrate-brief "add rate limiting to the payments API"
/orchestrate-brief ~/Code/_notes/plans/2026-05-29-my-feature.local.md
/orchestrate-brief ~/Code/my-repo/openspec/changes/JIRA-1234.md
```

---

## What it produces

The planner agent reads the input and produces a `brief.md`:

| Section | Purpose |
| --- | --- |
| `Goal` | What we're trying to achieve (1–3 sentences or bullets) |
| `Constraints` | Scope limits, things not to change, rollback steps |
| `Acceptance criteria` | How we'll know the run succeeded (concrete, testable) |
| `Operations` | Sequenced sub-tasks, each with a `files` scope list — required for fanout recipes |
| `Decision Log` | Empty on creation; orchestrator appends entries during the run |

The `files` scope in `Operations` is what enables the parallel independence check in fanout recipes. For loop/sequential recipes it acts as an advisory scope hint.

The brief is written to:

```
{artifact_root}/runs/<session_id>/brief.md
```

Pass that path directly to `/orchestrate`.

---

## Passing a plan or openspec

When given an existing document, the planner extracts intent and maps it onto the brief structure. It does not rewrite your document — it produces a new brief derived from it. If the source already has clear requirements and a defined approach, the planner preserves them. Gaps (missing `files` scopes, vague operations) are filled in or flagged.

---

## Signal Keywords

<!-- Comma-separated terms the skills collector uses to attribute learnings to this skill -->

orchestrate-brief, planner, brief, goal, constraints, acceptance criteria, operations, files scope
