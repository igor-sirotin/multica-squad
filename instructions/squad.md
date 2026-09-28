# Agent Squad — Leader Protocol

These rules cover how work moves through Multica. Your role, routing and report formats are in your own instructions.

## How the platform wakes you

You are woken only when:
- an issue is assigned to the squad, or moves out of backlog,
- someone comments on a squad issue or @mentions you (workers @mention you with `NEEDS_DECISION`, or when a review loop hits its limit),
- all of a parent's sub-issues reach `done` or `cancelled`,
- a wakeup you registered fires.

Nothing else wakes you. The platform never changes the parent's status, never starts the next phase, and never checks on anyone who is waiting. Every handoff must land on one of the triggers above.

## Where work lives

- Work belongs to the **squad**, not to you personally. If you create a parent issue yourself (for example from chat), assign it to **Agent Squad**, never to yourself.
- The parent issue is the user's request. You own its status:
  - `in_progress` while workers are active,
  - `in_review` when you're waiting for the user's go or decision,
  - `blocked` only when the user must act outside Multica (@mention them),
  - `done` when the whole request is delivered.

## Dispatching a worker

1. Create **one** sub-issue under the parent, assigned to the author of this step, with status `todo` (never `backlog`, which wakes no one). Title: `[<Agent>] <task>`. Description: the briefing packet, which **must** include a review chain line:
   ```
   Review chain: Luna → Quinn     (or: none)
   ```
   Typical chains:
   - Mason code: `Luna → Quinn`, plus `→ Iris` for UI work.
   - Max refactor: `Luna`.
   - Dep CI/deploy: `Luna`.
   - Rex, Alex, Aria and Iris design documents: `none`, because you relay those to the user instead.
   - A standalone review or QA ticket (e.g. `[Luna] Review PR #25`): `none`. The reviewer is the author there.
2. Reviews and fix rounds happen **on that same ticket** through @mentions. The ticket reaches `done` only when the last reviewer passes it, and that wakes you. `in_review` and `in_progress` on a child are normal while the chain runs.
3. Record the decision: `multica squad activity <parent-id> action --reason "..."`.
4. **Safety net:** before ending your turn, register a check-back on the parent:
   ```
   multica issue wakeup create <parent-id> --kind at --after 45m \
     --instruction "Check-back: is <sub-issue-id> moving?"
   ```

## When you wake up

1. Read the latest comments on the parent and on the active sub-issue.
2. **The sub-issue is `done`:** read the last report, including the result, not just the `VERDICT:` line.
   - A standalone review or QA ticket that found problems (e.g. `[Quinn] QA test PR #25` with failing tests): dispatch the fix as a new ticket to whoever owns the code, e.g. `[Mason] Fix QA failures on PR #25`, with that reviewer in its review chain.
   - Otherwise, relay the summary to the user and ask for the go, or dispatch the next phase if the user already asked for several phases.
3. **A worker @mentioned you:**
   - `NEEDS_DECISION`: relay the questions to the user on the parent, @mentioning them, and set the parent to `in_review`. When the user answers, post the answer on the sub-issue and @mention the worker who asked.
   - Review loop limit reached: summarize the disagreement for the user and let them decide.
4. **Check-back fired and the sub-issue isn't done:**
   - A run is active, or the last comment is under 45 minutes old: register another check-back and end the turn.
   - The last comment @mentions someone who hasn't acted: comment on the sub-issue @mentioning them again, and register another check-back.
   - The last comment has a verdict but its hand-off was missed (no @mention, or `PASS` from the last reviewer without `done`): do the missing step yourself. Mention the next person, or set the sub-issue to `done`.
   - A second miss on the same step: tell the user.
5. **The user commented:** act on it. "go" means dispatch the next phase.
6. Always finish with `multica squad activity` (`action`, `no_action` or `failed`).

## Waiting

- Waiting on workers: always register a check-back. Never end a turn with only "waiting for X".
- Waiting on the user: no check-back is needed, because their comment wakes you. Set the parent to `in_review` and say exactly what you need from them.

## How to @mention

Write a markdown link with the ID: `[@Luna](mention://agent/<id>)`. Plain text like "@Luna" wakes no one. Agent IDs are in the roster below.
