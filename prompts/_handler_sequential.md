# Handler: Sequential

This fragment handles a single `type: single` step. The orchestrator's Step 8 loop calls this handler once per `type: single` step and waits for it to return before advancing.

---

## Execution (one step)

1. **Load agent**: read the orchestrator-resolved agent path for `<step.agent>` (from Step 6.5 — `prompts/agents/local/<step.agent>.md` if present, else `prompts/agents/<step.agent>.example.md`).
2. **Compose dispatch prompt**: inject manifest path, working dir, file paths, session_id, resolved skills, and prior output from the previous step (or `"N/A"` if this is the first step in the recipe).
3. **Dispatch agent**.
4. **On result received**: return the structured result to the orchestrator.
   - The orchestrator applies `decision_log_entries` to the manifest.
   - The orchestrator appends learnings to `learnings.md`.
   - The orchestrator stores the result as `prior_output` for the next step.

**Step complete — return control to the orchestrator. Step 8 advances to the next step.**

---

## Prior output chaining

The orchestrator passes the previous step's structured result into this handler as `prior_output`. Inject it into the dispatch prompt under `<prior output>`. On the first step of the recipe, `prior_output` is `"N/A"`.

Agents do not write to each other's outputs. All manifest updates flow through the orchestrator's `decision_log_entries` integration.

---

## No loop state

There is no cycle counter, no churn tracking, and no transition map. This step runs exactly once. To run a step multiple times, use `type: loop` in the recipe instead.
