# Handler: Loop

This fragment is included by `orchestrate.md` for steps with `type: loop`. It implements the loop state machine described in §7a of the design.

---

## Pre-flight

Before entering the loop for this step:

1. Confirm `step.exit` is present. If absent: **fast-fail immediately**.
   ```
   Error: step "<name>" has type: loop but no "exit" field.
   At least one of exit.maxCycles or exit.churnThreshold must be set.
   ```
2. Confirm at least one of `step.exit.maxCycles` or `step.exit.churnThreshold` is set. If neither: same fast-fail.
3. Load `step.transitions` (or use defaults):
   - Default: `{ "APPROVE": "exit-success", "CHANGE_REQUESTS": "continue" }`
   - Recipe-declared map overrides defaults entirely — use as written.

---

## State machine

```
[INIT]
  cycle = 0
  churn_count = 0
  prior_churn_value = null
  prior_critic_feedback = "N/A"

[GUARD]  ← check before every producer dispatch
  if maxCycles is set AND cycle >= maxCycles:
    → [exit-failure: maxCycles exceeded]
  if churnThreshold is set AND churn_count >= churnThreshold:
    → [exit-failure: churnThreshold exceeded]
  → [PRODUCING]

[PRODUCING]
  cycle += 1
  dispatch producer agent (writer / technical-writer / …)
  with prior_critic_feedback and {{run_mandate}} injected

[REVIEWING]
  dispatch critic agent (reviewer / product-lead / …)
  with producer output + brief + {{run_mandate}}

[TRANSITION LOOKUP]
  verdict = critic.structured_result.verdict
  next_state = step.transitions[verdict]

  if next_state is undefined:
    → [ERROR: unknown transition value "<verdict>" — fast-fail]

  switch next_state:
    "exit-success"            → [EXIT: success — step complete, return to orchestrator]
    "exit-failure"            → [EXIT: failure — step complete, return to orchestrator]
    "continue"                → update brief, update churn, → [GUARD]
    "continue-skip-brief"     → skip brief update, update churn, → [GUARD]
    default                   → [ERROR: invalid state value]
```

On either exit: **return the step result to the orchestrator. Step 8 advances to the next step.** On `exit-failure`, pass the failure reason so the next step (retro) can report it.

---

## Brief update (on `continue`)

1. Apply `decision_log_entries` from critic result to `brief.md` (appended to `## Decision Log`).
2. Append Decision Log entry: `[Cycle N] <critic finding> → <section> changed: <new intent>`
3. Re-read `brief.md` fresh at the top of the next cycle — no in-memory carry.

On `continue-skip-brief`: skip steps 1–3. Advance to [GUARD] without brief changes.

---

## Churn tracking

If `step.exit.churnThreshold` is set:

- After each cycle, read the field named by `step.exit.churnField` from the critic's structured result. If `churnField` is not set on the step, churn detection is disabled.
- If the value did not decrease compared to `prior_churn_value`, increment `churn_count`. Otherwise reset `churn_count = 0`.
- Update `prior_churn_value` to the current value.

---

## Failure exits

On any failure exit (maxCycles, churnThreshold, or `exit-failure` transition):

```bash
clog FOLLOWUP "loop step '<name>' exited via <condition> at cycle <N>" \
  --agent orchestrator --repo <repo> --session <session_id>
```

Log which condition triggered. Mark the run outcome as `failure` in the final close log. Retro still runs — pass the failure reason in its inputs.

---

## Prior critic feedback injection

After each critic result, store the feedback summary as `prior_critic_feedback`. Inject it into the next producer dispatch prompt under the `<prior critic feedback>` placeholder. On the first cycle, inject `"N/A"`.

**Under `interactive: none` you are the only adjudicator a scope question will get.** When a producer surfaces a conflict between a decision's stated intent and its declared `files` list, resolve it yourself before the next dispatch instead of letting the loop re-litigate it: take the union of the `files` lists across every Operation in the brief, and if the files the decision actually needs already appear under another Operation, authorize them explicitly, log a `DECISION` recording why the widening is faithful to intent rather than scope creep, and inject that authorization into the next producer prompt. Hand the producer the narrowing facts you hold at the same time — which call site is permanently broken versus transiently self-healing — so the fix is proportionate rather than a speculative abstraction. A producer's disclosed scope conflict is the cheapest bug report in the loop; never let it round-trip as an unanswered question.

**Once you have proven an environment dead end, inject the proof into every later dispatch — not the symptom.** When an agent reports a blocked verification and you re-derive the real root cause yourself, record it as a Decision Log entry stating the exact blockers in order, the commands run, and the verdict ("`<cmd>` cannot run in this environment; AC N is UNVERIFIED; CI must run it before merge"), then carry that entry verbatim into every subsequent producer and critic prompt for the run. Passing the symptom forward ("the build failed") invites each cycle to re-probe the same dead end and burn a cycle; passing the proof forward stops it. Never let a proven-unrunnable command be reported as passing, and never let it silently disappear from the record either.
