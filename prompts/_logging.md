# Logging

Logging is optional. If clog is installed, use it. If not, skip logging — never fail or pause the run because logging is unavailable.

Clog owns event types, required flags, and anti-patterns. See `~/.claude/skills/clog/SKILL.md` for the full spec. If that file is absent, clog is not installed — skip logging.

> **Authoring note:** Do not add type definitions, flag descriptions, or `--kpi` value lists here — those belong in the clog skill and will drift if duplicated. This file owns the orchestrate-specific context only: detection logic, the `--session` requirement, and the parent-side dispatch checkpoint below.

---

## Detection (first hit wins)

1. `config.json` → `clog.enabled`: `true` forces on; `false` forces off; `null`/absent → fall through
2. `command -v clog` on PATH
3. `~/.claude/hooks/clog.sh` exists and is executable

---

## Usage

```bash
clog <TYPE> "<summary>" --agent <role> --repo <repo> --session <session_id>
```

Always include `--session <session_id>`. The session_id is injected by the orchestrator at dispatch time — it links every entry from this run together. For type definitions, required flags (including `--kpi` on `LEARNING`), and anti-patterns, see `~/.claude/skills/clog/SKILL.md`.

---

## Parent-side dispatch checkpoint

The orchestrator logs **its own** dispatches. One `ACTION` per agent dispatch, cut *before* the agent is dispatched — not after, and not only at step boundaries.

```bash
clog ACTION "dispatch <agent> (<role>, cycle <n>) for step '<name>'" \
  --agent orchestrator --repo <repo> --session <session_id>
```

This is separate from the `step '<name>' complete` entry in `orchestrate.md` Step 8. A step containing a producer/critic loop over three cycles is **seven** parent entries (six dispatches + one completion), not one.

**A subagent's own log entries never satisfy the parent's checkpoint.** The subagent logs what it did; the orchestrator logs that it handed off. Both are required — they answer different questions when a run is reconstructed later.

Also cut a parent `ACTION` for:

- **Resuming an agent** (e.g. `SendMessage` to an existing agent). A resumption is a new dispatch, not a continuation of the logged one.
- **Repository state changes the orchestrator makes itself** — creating or removing a worktree, creating or switching a branch, merging a base branch in. These change state without editing a file, which is exactly why they get skipped.
- **Outward-facing mutations not covered by `post-action-log.sh`.** That hook auto-logs `git commit`, `git push`, and `gh pr create` — and nothing else. `gh pr edit`, `gh pr comment`, review submissions, and issue-tracker mutations are all on the orchestrator.
- **Verification the orchestrator runs on an agent's behalf** — if the parent runs the build, tests, or lint because a dispatch came back short, that is parent work and needs a parent entry.

### Failure modes this exists to stop

Every one of these is a real miss, not a hypothetical. They share a shape: *something adjacent got logged, so the parent's own action stopped feeling like a state change.*

| Pattern | What it looks like |
| --- | --- |
| Coverage by proxy | A subagent logged its verdict, so the dispatch felt covered |
| Absorption by an auto-log | A worktree removal sat next to an auto-logged `COMMIT` and rode along on it |
| Adjacency inheritance | `gh pr edit` assumed to inherit the auto-logged `gh pr create` entry |
| Resumption as continuation | `SendMessage` read as part of the already-logged dispatch |
| Bookkeeping bias | `git merge` changed no file, so it read as plumbing rather than state |
| Scaffolding bias | Run-artifact and memory writes read as setup rather than durable state |

If a sweep at the end of a run finds parent-side dispatch misses, that is a defect in this checkpoint, not in the operator's discipline — fix the rule, not the habit.
