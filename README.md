# multica-squad

A 9-agent squad for [Multica](https://multica.ai), based on
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
| Alex | Strategist | Copilot | GPT-5.4 | high | Structured decomposition; a second model family checks Rex's assumptions. |
| Aria | Architect | Claude | Opus 5.5 | high | The hardest reasoning in the flow; mistakes here are the most expensive. |
| Mason | Builder | Claude | Sonnet 5 | high | Strong coder at reasonable cost; does the most tokens of work. |
| Luna | Reviewer | Copilot | GPT-5.4 | high | Cross-model review: a different family reviews Claude-written code and catches different mistakes. |
| Quinn | QA | Copilot | GPT-5.4 | medium | Independent from the builder; test writing is mostly mechanical. |
| Max | Optimizer | Claude | Sonnet 5 | medium | Rarely used; conservative refactors. |
| Dep | DevOps | Copilot | GPT-5.4 | medium | CI and Docker are well-trodden ground. |

All agents are private (owner-only), with at most 2 concurrent runs each.

## How to use

Assign an issue to **Agent Squad**. The Orchestrator picks one specialist, creates a `[Agent] …` sub-issue for them, and after each phase posts a summary on your issue and waits for your "go". Full reports are comments on the sub-issues.

To skip the ceremony, assign the issue directly to a specialist, for example Luna for "review PR #123".
