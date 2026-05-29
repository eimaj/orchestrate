---
name: orchestrate-manifest
description: Produce a structured manifest.md from a goal, plan, or spec. Use before running /orchestrate when you don't yet have a properly structured manifest.
---

# Generate Manifest

## Trigger

**Use when:** you have a goal, plan file, or openspec and need a properly structured `manifest.md` before invoking `/orchestrate`. Also use when `/orchestrate` rejects your input as malformed — run this first to fix the structure. **Do not use when:** you already have a manifest with all four required sections and it passed orchestrator validation. **Inputs expected:** a goal description (natural language), an existing plan file path, or an openspec path. **Outputs produced:** `manifest.md` written to `{artifact_root}/runs/<session_id>/` with four sections: `Requirements`, `Approach`, `Operations` (with `files` scope per sub-task), and `Safeguards`. **Capture learnings:** after a session with this skill, log signals via: `clog LEARNING "<observation>" --family orchestrate --kpi <failure|prompt_gap|token_waste|effective|format_issue>`

> **Last Reviewed**: 2026-05-29 **Refresh Rule**: Event-driven — update when the manifest schema or planner agent changes.

## Related Skills

- [`orchestrate`](../orchestrate/SKILL.md) — run a recipe against the manifest this skill produces
- [`orchestrate-recipe`](../orchestrate-recipe/SKILL.md) — author the recipe to pair with the manifest
- [`plan-workflow`](../plan-workflow/SKILL.md) — lightweight planning; output can be passed to this skill to produce a manifest

---

## Invocation

```
/orchestrate-manifest <goal>
/orchestrate-manifest <path-to-plan-or-spec>
```

Examples:

```
/orchestrate-manifest "add rate limiting to the payments API"
/orchestrate-manifest ~/Code/_notes/plans/2026-05-29-my-feature.local.md
/orchestrate-manifest ~/Code/my-repo/openspec/changes/JIRA-1234.md
```

---

## What it produces

The planner agent (`prompts/agents/planner.example.md` as template, or your local override) reads the input and produces a `manifest.md` with four required sections:

| Section        | Purpose                                                |
| -------------- | ------------------------------------------------------ |
| `Requirements` | What must be true when the run completes (1–5 bullets) |
| `Approach`     | The strategy and key decisions (2–4 sentences)         |
| `Operations`   | Sequenced sub-tasks, each with a `files` scope list    |
| `Safeguards`   | Constraints, things not to change, rollback steps      |

The `files` scope in `Operations` is required — it's what the orchestrator uses for the parallel independence check in fan-out recipes.

The manifest is written to:

```
{artifact_root}/runs/<session_id>/manifest.md
```

Pass that path directly to `/orchestrate`.

---

## Passing a plan or openspec

When given an existing document, the planner reads it, extracts intent, and maps it onto the four-section structure. It does not rewrite your document — it produces a new manifest derived from it. If the source already has clear requirements and a defined approach, the planner preserves them. Gaps (missing `files` scopes, vague operations) are filled in or flagged.

---

## Signal Keywords

<!-- Comma-separated terms the skills collector uses to attribute learnings to this skill -->

orchestrate-manifest, planner, manifest, requirements, approach, operations, safeguards, files scope
