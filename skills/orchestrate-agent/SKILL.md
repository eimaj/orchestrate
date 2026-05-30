---
name: orchestrate-agent
description: Interactively author a new orchestrate agent via natural language and write it to prompts/agents/local/<name>.md. Use when a recipe references an agent you don't have yet, or you need a domain-specific producer or critic.
disable-model-invocation: true
---

# Create Agent

## Trigger

**Use when:** a recipe references an agent you don't have yet, or you need a domain-specific producer/critic (e.g. a Go reviewer, a React writer) tailored to your context. **Do not use when:** you only need to tweak an existing agent (edit `prompts/agents/local/<name>.md` directly), or the shipped `prompts/agents/<name>.example.md` already fits your domain as-is — just copy it. **Inputs expected:** a description of the agent's role, domain, and (for critics) its verdict vocabulary. **Outputs produced:** `prompts/agents/local/<name>.md` written to the orchestrate repo, confirmed before writing. This file is gitignored. **Capture learnings:** after a session with this skill, log signals via: `clog LEARNING "<observation>" --family orchestrate --kpi <failure|prompt_gap|token_waste|effective|format_issue>`

> **Last Reviewed**: 2026-05-29 **Refresh Rule**: Event-driven — update when the agent prompt contract changes or the authoring flow is implemented.

## Related Skills

- [`orchestrate-recipe`](../orchestrate-recipe/SKILL.md) — author the recipe that references this agent
- [`orchestrate`](../orchestrate/SKILL.md) — run a recipe once its agents exist

---

## Invocation

```
/orchestrate-agent
```

---

## Why agents are user-specific

Agents are tailored to your context — a developer's retro differs from a product designer's, a Go backend writer differs from a React writer. The repo ships reference templates (`prompts/agents/*.example.md`), but the runnable agents you actually dispatch live in the gitignored `prompts/agents/local/` directory. This skill builds one for you.

---

## What it does

Walks you through the decisions needed to build a valid agent prompt:

1. **Name** — what the agent is called (e.g. `writer`, `technical-writer`, `my-go-reviewer`). This becomes the filename `prompts/agents/local/<name>.md` and must match the agent name referenced in your recipe's `steps`.
2. **Role** — is this a **producer** (does the work — writes code, docs, plans) or a **critic** (evaluates a producer's output and returns a verdict)?
3. **Start from a template** — ask:

   > Would you like to start from an example template? Available examples: `<list prompts/agents/*.example.md>`

   If yes, load the chosen example as the starting point and walk through adapting it. If no, start from the minimal skeleton for the chosen role.

4. **Persona** — one sentence: "You are a..." Capture the domain and seniority (e.g. "You are a senior Go backend engineer.").
5. **Only job** — the single responsibility this agent owns, stated in one line.
6. **Work step** — what the agent does between **Orient** (read inputs) and **Verify/Produce output**. This is the body of the agent's job — be concrete about the domain (e.g. "implement the Operations using idiomatic Go, reusing existing packages" or "evaluate the docs against the manifest Requirements for clarity and completeness").
7. **Output contract** — for **critics**, ask what verdict values it returns. These **must match the recipe's `transitions` vocabulary** exactly (e.g. `APPROVE | CHANGE_REQUESTS`, or `APPROVED | NEEDS_WORK`). For **producers**, confirm the standard contract (Summary / Decision Log Entries / Learnings) fits or capture domain-specific additions.

---

## Execution Steps

1. **Ask for the agent name** — "What should this agent be called? The name must match the agent field in your recipe's steps exactly (e.g. `writer`, `my-go-reviewer`)."

2. **Ask for the role** — "Is this agent a **producer** (does the work — writes, drafts, implements) or a **critic** (evaluates a producer's output and returns a verdict)?"

3. **Offer a template** — List available example templates (`prompts/agents/*.example.md`, names without path or extension). Ask: "Would you like to start from one of these examples, or build from scratch?"
   - If from example: load that file's content as the starting point. Walk through each section and ask to confirm or change.
   - If from scratch: start from the minimal skeleton for the chosen role.

4. **Walk through each field:**

   **a. Persona** — "Complete this sentence: 'You are a...'" (e.g. "You are a senior Go backend engineer.")

   **b. Only job** — "State the agent's single responsibility in one line." (e.g. "Your only job is to implement the plan described in the manifest — minimally, correctly, and within scope.")

   **c. Work step** — "What does this agent do between Orient (read inputs) and Produce output? Be concrete about the domain." For critics: what does it evaluate, and by what standard? For producers: what does it implement or create?

   **d. Output contract** — For **critics**: "What verdict values does this agent return? These must match the `transitions` vocabulary in your recipe exactly (e.g. `APPROVED | NEEDS_WORK`)." For **producers**: confirm the standard contract (Summary / Decision Log Entries / Learnings) fits, or capture domain-specific additions.

5. **Preview the assembled agent file** — show the full prompt and ask: "Does this look right? Confirm to write, or tell me what to change."

6. **Write** to `prompts/agents/local/<name>.md` on confirmation.

7. **Report success:**
   > Agent written to `prompts/agents/local/<name>.md`. This file is gitignored and won't be committed. The orchestrator resolves `prompts/agents/local/<name>.md` first, falling back to `.example.md` templates.

---

### Producer skeleton

```markdown
# [Name]

You are [persona]. Your only job is [responsibility].

<!-- @include ../_logging.md — resolved at dispatch time by the orchestrator -->

---

## Inputs (everything you need — you have NO other context)

- `{{manifest_path}}` — path to `manifest.md`
- `{{working_dir}}` — working directory for all file operations
- `{{file_paths}}` — files to read before implementing (comma-separated, or "N/A")
- `{{prior_critic_feedback}}` — feedback from the previous reviewer cycle, or "N/A"
- `{{claude_md_rules}}` — active CLAUDE.md rules for this repo
- `{{session_id}}` — use as `--session` on all clog entries

## Skills to apply

{{skills}}

---

## Steps

1. **Orient** — read `{{manifest_path}}`, all files in `{{file_paths}}`, and `{{prior_critic_feedback}}`. Verify brief-asserted facts against source.
2. **[Work step]** — [domain-specific implementation instructions]
3. **Verify** — run the relevant test suite. Fix failures before continuing.
4. **Commit** — one atomic commit per logical unit.
5. **Produce output** in the exact contract below.

---

## Output contract

\`\`\`markdown

## Summary

<what was done, file by file>

## Commits

- <SHA>: <subject>

## Decision Log Entries

- [Cycle {{cycle}}] <decision> → <section> changed: <new intent>

## Learnings

<what worked / surprised / slowed>
\`\`\`

Return ONLY this. No intermediate output.

---

## Logging

\`\`\`bash
clog CODE "<file>: <what changed>" --agent [name] --repo {{repo}} --session {{session_id}}
clog COMMIT "<SHA> <subject>" --agent [name] --repo {{repo}} --session {{session_id}}
clog LEARNING "<insight>" --agent [name] --repo {{repo}} --session {{session_id}} --family orchestrate --kpi <token_waste|failure|prompt_gap|effective|format_issue>
\`\`\`
```

### Critic skeleton

```markdown
# [Name]

You are [persona]. Your only job is to evaluate the producer's output against [standard].

<!-- @include ../_logging.md — resolved at dispatch time by the orchestrator -->

---

## Inputs

- `{{manifest_path}}` — path to `manifest.md`
- `{{producer_output}}` — the producer's output from this cycle
- `{{cycle}}` — current cycle number (injected by the orchestrator)
- `{{session_id}}` — use as `--session` on all clog entries

## Steps

1. **Orient** — read `{{manifest_path}}` and `{{producer_output}}`.
2. **[Work step]** — [domain-specific evaluation instructions]
3. **Produce output** in the exact contract below.

---

## Output contract

\`\`\`markdown

## Verdict

[APPROVE | CHANGE_REQUESTS]

## Rationale

<one paragraph>

## Decision Log Entries

- [Cycle {{cycle}}] <decision> → <section> changed: <new intent>

## Learnings

<what worked / surprised>
\`\`\`

Return ONLY this. No intermediate output.

---

## Logging

\`\`\`bash
clog ACTION "verdict: [APPROVE|CHANGE_REQUESTS] — <reason>" --agent [name] --repo {{repo}} --session {{session_id}}
clog LEARNING "<insight>" --agent [name] --repo {{repo}} --session {{session_id}} --family orchestrate --kpi <token_waste|failure|prompt_gap|effective|format_issue>
\`\`\`
```

---

## Assemble and confirm

1. **Preview** the assembled agent file — persona, inputs, work step, output contract, logging, and constraints — for review.
2. **Confirm** before writing.
3. **Write** to `prompts/agents/local/<name>.md`.
4. On success, report:
   > Agent created at `prompts/agents/local/<name>.md`. This file is gitignored and won't be committed.

---

## Manual alternative

Copy an example template and edit the persona and work step:

```bash
cp prompts/agents/<name>.example.md prompts/agents/local/<name>.md
# then edit the persona line and the work step to match your domain
```

The orchestrator resolves `prompts/agents/local/<name>.md` first, falling back to the `.example.md` template. It fast-fails if the resolved file still contains `[TODO]` in the persona or work step.

---

## Signal Keywords

<!-- Comma-separated terms the skills collector uses to attribute learnings to this skill -->

orchestrate-agent, agent authoring, producer, critic, persona, work step, output contract, verdict vocabulary, local agents, example template
