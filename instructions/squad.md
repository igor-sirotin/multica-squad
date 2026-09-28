# Agent Squad — Leader Protocol

These rules cover how work moves through Multica. Your role, routing and report formats are in your own instructions.

## How the platform wakes you

You are woken only when:
- an issue is assigned to the squad, or moves out of backlog,
- someone comments on a squad issue or @mentions you,
- all of a parent's sub-issues reach `done` or `cancelled`,
- a wakeup you registered fires.

Nothing else wakes you. The platform never changes the parent's status, never starts the next phase, and never checks on anyone who is waiting. Every handoff must land on one of the triggers above.

## Where work lives

- Work belongs to the **squad**, not to you personally. If you create a parent issue yourself (for example from chat), assign it to **Agent Squad**, never to yourself.
- The parent issue is the user's request. You own its status:
  - `in_progress` while a worker is running,
  - `in_review` when you're waiting for the user's go or decision,
  - `blocked` only when the user must act outside Multica (@mention them),
  - `done` when the whole request is delivered.

## Dispatching a worker

1. Create **one** sub-issue under the parent, assigned to one worker, with status `todo` (never `backlog`, which wakes no one). Title: `[<Agent>] <task>`. Description: the briefing packet.
2. Never reopen a finished sub-issue. Each new round, like a re-review or a fix after failed tests, gets a new sub-issue.
3. Record the decision: `multica squad activity <parent-id> action --reason "..."`.
4. **Safety net:** before ending your turn, register a check-back on the parent:
   ```
   multica issue wakeup create <parent-id> --kind at --after 45m \
     --instruction "Check-back: is <sub-issue-id> (<Agent>) finished?"
   ```

## When you wake up

1. Read the latest comments on the parent and on the most recent sub-issue.
2. **A worker finished** (sub-issue `done`): read the `VERDICT:` line of its report.
   - `DONE`: relay the summary to the user and ask for the go, or dispatch the next phase if the user already asked for several phases.
   - `CHANGES_NEEDED`: route the findings (for example Luna or Quinn back to Mason) in a new sub-issue.
   - `NEEDS_DECISION`: relay the questions to the user on the parent, @mentioning them, and set the parent to `in_review`.
3. **Check-back fired and the worker isn't done:**
   - Still running (a live run exists): register another check-back and end the turn.
   - Stuck in `in_review`, `blocked` or `in_progress` with a report: treat the report as the result, set the sub-issue to `done` yourself, and continue as above.
   - Stuck with no report and no run: comment on the sub-issue @mentioning the worker to finish, and register another check-back. On the second miss, tell the user.
4. **The user commented:** act on it. "go" means dispatch the next phase.
5. Always finish with `multica squad activity` (`action`, `no_action` or `failed`).

## Waiting

- Waiting for a worker: always register a check-back. Never end a turn with only "waiting for X".
- Waiting for the user: no check-back is needed, because their comment wakes you. Set the parent to `in_review` and say exactly what you need from them.
