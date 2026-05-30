# Logging

Logging is optional. If clog is installed, use it. If not, skip logging — never fail or pause the run because logging is unavailable.

Clog owns event types, required flags, and anti-patterns. See `~/.claude/skills/clog/SKILL.md` for the full spec. If that file is absent, clog is not installed — skip logging.

> **Authoring note:** This file is a thin wrapper. Do not add type definitions, flag descriptions, or `--kpi` value lists here — those belong in the clog skill and will drift if duplicated. This file owns only: detection logic and the `--session` requirement (orchestrate-specific context).

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
