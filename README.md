# multica-squad

A 12-agent squad (the 9 from agent-squad plus a UI/UX designer, a legal & privacy counsel and a security engineer) for [Multica](https://multica.ai), based on
[agent-squad](https://github.com/sickn33/agentic-awesome-skills/tree/main/skills/agent-squad).

```sh
./setup.sh                                   # uses runtimes on this machine
SQUAD_HOST=my-laptop.local ./setup.sh        # or pick another machine
```

Re-running is safe: existing agents get their runtime, instructions, model and thinking level synced from this repo. Edit `instructions/*.md` or the table at the top of `setup.sh`, then run it again.

## The squad

| Agent | Role | Runtime | Model | Thinking | Why |
|-------|------|---------|-------|----------|-----|
| Orchestrator | Leader | Claude | Sonnet 5 | medium | Wakes up often; routing and summaries don't need Opus. Claude is strongest at driving the Multica CLI. |
| Rex | Analyst | Claude | Opus 5.5 | high | Spec quality determines everything downstream. |
| Alex | Strategist | Claude | Sonnet 5 | high | Structured decomposition of Rex's spec into a checklist; doesn't need Opus. |
| Aria | Architect | Claude | Opus 5.5 | high | The hardest reasoning in the flow; mistakes here are the most expensive. |
| Iris | Designer | Claude | Opus 5.5 | high | Design judgement is where the model tier shows most; runs only for UI work. |
| Mason | Builder | Claude | Sonnet 5 | high | Strong coder at reasonable cost; does the most tokens of work. |
| Luna | Reviewer | Claude | Opus 5.5 | high | The quality gate: a stronger model reviews Sonnet-written code and catches what the builder missed. |
| Quinn | QA | Claude | Opus 5.5 | high | Independent from the builder; finding the edge cases the builder missed needs Opus. |
| Max | Optimizer | Claude | Sonnet 5 | medium | Rarely used; conservative refactors. |
| Dep | DevOps | Claude | Sonnet 5 | medium | CI and Docker are well-trodden ground. |
| Portia | Legal Counsel | Claude | Opus 5.5 | high | We handle sensitive user data; privacy mistakes are costly and hard to undo. Runs only when personal data is involved. |
| Hex | Security Engineer | Claude | Opus 5.5 | high | Deeper than Luna's review, focused on exploitable issues. Runs only for sensitive changes. |

All agents are private (owner-only), with at most 2 concurrent runs each.

## Skills

Created or imported and assigned by `setup.sh`:

| Skill | Agents |
|-------|--------|
| `squad-worker-contract` ([local](skills/squad-worker-contract.md)) | all workers |
| `frontend-design` ([anthropics/skills](https://github.com/anthropics/skills)) | Iris, Mason |
| `webapp-testing` | Iris, Quinn |
| `compliance-check`, `legal-risk-assessment` ([anthropics/knowledge-work-plugins](https://github.com/anthropics/knowledge-work-plugins/tree/main/legal)) | Portia |
| `gdpr-data-handling` ([wshobson/agents](https://github.com/wshobson/agents/tree/main/plugins/hr-legal-compliance/skills/gdpr-data-handling)) | Portia, Aria |
| `differential-review`, `sharp-edges`, `supply-chain-risk-auditor` ([trailofbits/skills](https://github.com/trailofbits/skills)) | Hex |

Add more to the `SKILLS` table in `setup.sh`. Next candidates if Iris's output feels generic: [ui-ux-pro-max](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill), and `design-review` / `plan-design-review` from [gstack](https://github.com/garrytan/gstack).

## How to use

You're the product lead:

1. Create an issue with a feature or a problem and assign it to **Agent Squad**, not to the Orchestrator directly.
2. The team runs on its own. The Orchestrator picks the smallest pipeline that fits (e.g. Mason → Luna → Quinn for a small change, with Rex, Aria and Iris added for bigger features, and Hex and Portia for anything touching sensitive data), dispatches each step as a sub-issue, and loops fixes until review and QA pass.
3. You're @mentioned only for a real product question, and for delivery: the parent moves to `in_review` with the PR link, what was verified, and non-blocking notes.
4. Review the PR. Comment on the issue to request changes (the team does another round) or to say it's merged (the issue closes).

Production issues fit the same flow later: anything that creates an issue assigned to Agent Squad (an autopilot, an alert integration) starts it.

### How hand-offs work

Multica only wakes the leader when all of a parent's sub-issues reach `done` or `cancelled`, on a comment or @mention, or when a registered wakeup fires. So there are two rules:

- **Workers** ([`squad-worker-contract`](skills/squad-worker-contract.md)): one report starting with `RESULT: OK | BLOCKING | QUESTION`, then status `done`. Always.
- **Leader** ([`instructions/squad.md`](instructions/squad.md)): on every wake-up, read the sub-issues, close leftovers, dispatch the next step, and register a 45-minute check-back while waiting.

You can also assign a ticket straight to one specialist (e.g. Luna for "review PR #123"). It reports the same way and @mentions you if it needs you.

## License

MIT, see [LICENSE](LICENSE). The agent instructions are adapted from [agent-squad](https://github.com/sickn33/agentic-awesome-skills/tree/main/skills/agent-squad) (MIT).
