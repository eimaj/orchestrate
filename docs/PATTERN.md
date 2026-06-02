# Act → Learn → Retro

The invariant pattern across every recipe. Never changes, regardless of topology, agents, or configuration. All agents reference this document.

---

## ACT

The orchestrator dispatches stateless agents to do work.

- The orchestrator is the **only stateful actor**. It holds the complete mental model, loads the recipe, decomposes work into steps, resolves skills, dispatches agents, integrates structured results, and captures learnings.
- Agents are **stateless workers**. Each receives a fully self-contained dispatch prompt — persona, inputs, file paths, skills, output contract, and `session_id` (format: `<YYYYMMDD_HHMMSS>-<slug>` where slug = recipe name + brief goal slug, e.g. `code-writer-my-feature`). The agent has no access to prior conversation; everything it needs is in the prompt.
- Agents **never write to `brief.md`** directly. They return proposed `decision_log_entries` in their structured result. The orchestrator applies these sequentially after each step.
- Every dispatch prompt follows the **standard dispatch envelope**: `persona` + task context (brief path, working dir, file paths, prior feedback) + `{{skills}}` placeholder + output contract ("Return only this. No intermediate output.").
- The orchestrator holds no intent purely in-memory between cycles. The brief is re-read fresh at each cycle start — it is the complete audit trail.
- The orchestrator resolves each recipe and agent by checking `local/` first (`recipes/local/<name>.json`, `prompts/agents/local/<name>.md`), then falling back to the `.example.*` reference. A missing file — or a resolved agent still containing `[TODO]` placeholders — fast-fails the run before any agent fires.

---

## LEARN

Progressive learnings are captured after each step. Never batched, never deferred.

- Every agent appends a `## Learnings` section to its structured result — what worked, what surprised, what slowed it down. The orchestrator writes these to `{artifact_root}/runs/<session_id>/learnings.md` immediately after each join.
- LEARNINGs are logged via `clog` the instant they occur (within a single dispatch), before the structured result is returned. `--family` and `--kpi` flags are required on every LEARNING entry.
- The orchestrator logs its own dispatch, join, verdict, and integration events independently. A subagent's log entry is never inherited as the orchestrator's entry (the **subagent-claim-as-parent anti-pattern**).
- All logging uses `_logging.md` (shared fragment, included in every agent prompt). This fragment is included automatically at dispatch time — it is not configured through the recipe `skills._shared` key. Direct JSONL append is the fallback when `clog` is absent — the run never fails due to missing logging.

---

## RETRO

A reflection pass closes every run. No run ends without it.

- The `retro` step is always the final step in a recipe. It runs whether the preceding steps exited via success or failure.
- Retro inputs: evolved brief (including Decision Log) + `learnings.md` + clog JSONL events filtered to the current session (when clog is configured). If clog is absent, Retro falls back to learnings only.
- Retro produces `retro.md` with two sections:
  - **Run Report** (always present): summary of changes made, alignment check against original goal and acceptance criteria in the brief. If the result strayed from intent, the divergence and its cause are flagged explicitly.
  - **Recommended Improvements** (present only when learnings exist): concrete, actionable changes to the agents, skills, hooks, or bash patterns used during this run. KPI-tagged. Proposals only — structural changes require human review.
- Retro may apply non-structural improvements directly within its scope guardrail (`{artifact_root}/runs/<session_id>/` and `orchestrate/prompts/` + `orchestrate/recipes/`). Structural changes (new sections, new agents, new recipe topologies) require human review.
- Cross-run context: Retro reads prior `retro.md` files from `{artifact_root}/runs/` for the same repo slug to build awareness of recurring patterns.
