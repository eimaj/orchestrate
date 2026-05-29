# Handler: Fan-out

This fragment is included by `orchestrate.md` for steps with `type: fanout`. It implements the parallel fan-out / fan-in topology described in §7d of the design.

---

## Step 1 — Independence check (required before any fan-out)

Each sub-task in the manifest's `Operations` section must declare a `files` scope list.

Before dispatching any agent:

1. Read all sub-task `files` lists from the manifest.
2. Run a static overlap check:
   - **Exact match**: the same path appears in two or more sub-task `files` lists.
   - **Common directory prefix**: one path is an ancestor directory of another.
   - **Missing scope**: any sub-task has no `files` list, or the list is empty.
3. If any overlap or missing scope is found:
   - Log the collapsed sub-tasks.
   - Fall back to **sequential execution** using the same `agents` pair (one sub-task at a time, via the sequential handler). No parallel dispatch fires.
   - The integration critic step still runs over the merged result.

```bash
clog DECISION "fanout independence check: <n> sub-tasks, <k> collapsed to sequential" \
  --agent orchestrator --repo <repo> --session <session_id>
```

---

## Step 2 — Parallel dispatch (independent sub-tasks only)

For each independent sub-task, dispatch a **producer + critic pair** in parallel:

1. Load producer agent (orchestrator-resolved path for `<producer>` from Step 6.5 — `prompts/agents/local/<producer>.md` if present, else `prompts/agents/<producer>.example.md`).
2. Load critic agent (orchestrator-resolved path for `<critic>` from Step 6.5 — `prompts/agents/local/<critic>.md` if present, else `prompts/agents/<critic>.example.md`).
3. Compose fully self-contained prompt for each: inject only that sub-task's manifest slice (requirements + files scope), working dir, session_id, and resolved skills.
4. Dispatch producer and critic for each sub-task. Producer runs first; critic receives producer output.
5. Collect all pair results.

Each pair is independent — they share no state. The orchestrator holds all results.

```bash
clog ACTION "fanout: dispatched <n> producer+critic pairs in parallel" \
  --agent orchestrator --repo <repo> --session <session_id>
```

---

## Step 3 — Fan-in: apply sub-task results

After all parallel pairs complete:

1. Collect `decision_log_entries` from all critic results.
2. Apply them to `{artifact_root}/runs/<session_id>/manifest.md` sequentially (one at a time, in sub-task order — no concurrent writes).
3. Append learnings from all pairs to `{artifact_root}/runs/<session_id>/learnings.md`.

---

## Step 4 — Integration critic

After fan-in, dispatch ONE integration critic over the **merged result tree**:

- Agent: the `critic` role defined in the step's `agents` array (same as per-pair critic).
- Input: full manifest (all sub-tasks) + all sub-task diffs/outputs merged + session_id.
- Purpose: catch collisions (type errors, fixture conflicts, lint failures) that the file-path independence check did not predict.

Apply the integration critic's `decision_log_entries` to the manifest. Append its learnings.

```bash
clog ACTION "fanout integration critic complete" \
  --agent orchestrator --repo <repo> --session <session_id>
```

**Fanout step complete — return the step result to the orchestrator. Step 8 advances to the next step.**

---

## Sequential fallback

When the independence check collapses sub-tasks to sequential:

- Reuse the **same `agents` pair** from the fanout step.
- Run via `_handler_sequential.md` logic: one sub-task at a time, in manifest order.
- After all sub-tasks complete, still run the integration critic over the merged result.
- Log the fallback reason.
