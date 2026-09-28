# multica-squad

A 10-agent squad (the 9 from agent-squad plus a UI/UX designer) for [Multica](https://multica.ai), based on
[agent-squad](https://github.com/sickn33/agentic-awesome-skills/tree/main/skills/agent-squad).

```sh
./setup.sh                                   # uses runtimes on this machine
SQUAD_HOST=Igors-MacBook-Pro.local ./setup.sh  # or pick another machine
```

Re-running is safe: existing agents get their instructions, model and thinking level synced from this repo. Edit `instructions/*.md` or the table at the top of `setup.sh`, then run it again.

## The squad

| Agent | Role | Runtime | Model | Thinking | Why |
|-------|------|---------|-------|----------|-----|
| Orchestrator | Leader | Claude | Sonnet 5 | medium | Wakes up often; routing and summaries don't need Opus. Claude is strongest at driving the Multica CLI. |
| Rex | Analyst | Claude | Opus 5.5 | high | Spec quality determines everything downstream. |
| Alex | Strategist | Copilot | GPT-5.4 | default | Structured decomposition; a second model family checks Rex's assumptions. |
| Aria | Architect | Claude | Opus 5.5 | high | The hardest reasoning in the flow; mistakes here are the most expensive. |
| Iris | Designer | Claude | Opus 5.5 | high | Design judgement is where the model tier shows most; runs only for UI work. |
| Mason | Builder | Claude | Sonnet 5 | high | Strong coder at reasonable cost; does the most tokens of work. |
| Luna | Reviewer | Copilot | GPT-5.4 | default | Cross-model review: a different family reviews Claude-written code and catches different mistakes. |
| Quinn | QA | Copilot | GPT-5.4 | default | Independent from the builder; test writing is mostly mechanical. |
| Max | Optimizer | Claude | Sonnet 5 | medium | Rarely used; conservative refactors. |
| Dep | DevOps | Copilot | GPT-5.4 | default | CI and Docker are well-trodden ground. |

All agents are private (owner-only), with at most 2 concurrent runs each. Multica has no per-agent reasoning setting for Copilot, so those agents use the runtime default.

## Skills

Created or imported and assigned by `setup.sh`:

| Skill | Agents |
|-------|--------|
| `squad-worker-contract` ([local](skills/squad-worker-contract.md)) | all workers |
| `frontend-design` ([anthropics/skills](https://github.com/anthropics/skills)) | Iris, Mason |
| `webapp-testing` | Iris, Quinn |

Add more to the `SKILLS` table in `setup.sh`. Next candidates if Iris's output feels generic: [ui-ux-pro-max](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill), and `design-review` / `plan-design-review` from [gstack](https://github.com/garrytan/gstack).

## How to use

Assign an issue to **Agent Squad**, not to the Orchestrator directly. Only squad-assigned issues give the leader the squad protocol ([`instructions/squad.md`](instructions/squad.md)), control over the parent's status, and your comments. The Orchestrator picks one specialist, creates a `[Agent] …` sub-issue for them, and after each phase posts a summary on your issue and waits for your "go". Full reports are comments on the sub-issues.

### Handoffs

Multica only wakes the leader when all of a parent's sub-issues reach `done` or `cancelled`, on a comment or @mention, or when a registered wakeup fires. So:

- **Every worker ends the same way** ([`squad-worker-contract`](skills/squad-worker-contract.md)): one report comment starting with `VERDICT: DONE | CHANGES_NEEDED | NEEDS_DECISION`, then status `done`. The verdict lives in the comment, never in the status.
- **The leader registers a 45-minute check-back** whenever it waits on a worker, so a worker that finishes wrongly gets noticed instead of stalling the squad.

To skip the ceremony, assign the issue directly to a specialist, for example Luna for "review PR #123".
