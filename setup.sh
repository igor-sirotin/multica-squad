#!/usr/bin/env bash
# Creates (or updates) the 10-agent squad in the current Multica workspace.
# Safe to re-run: existing agents get their instructions/model/thinking synced.
#
# Env overrides:
#   SQUAD_HOST   machine whose runtimes to use (default: this host)
#   SQUAD_NAME   squad name (default: "Agent Squad")
set -euo pipefail
cd "$(dirname "$0")"

HOST="${SQUAD_HOST:-$(hostname)}"
SQUAD_NAME="${SQUAD_NAME:-Agent Squad}"
MAX_CONCURRENT=2

OPUS="claude-opus-5-5"
SONNET="claude-sonnet-5"
GPT="gpt-5.4"

# name | runtime provider | model | thinking | squad role | description
AGENTS=(
  "Orchestrator|claude|$SONNET|medium|Leader|Squad leader. Routes work to specialists one phase at a time and relays summaries."
  "Rex|claude|$OPUS|high|Analyst|Turns vague intent into a precise spec: MoSCoW features, user stories, edge cases."
  "Alex|copilot|$GPT|high|Strategist|Turns requirements into a dependency-aware checklist with binary Definitions of Done."
  "Aria|claude|$OPUS|high|Architect|Designs data model, API contracts, file structure and security architecture."
  "Iris|claude|$OPUS|high|Designer|Designs UI flows, screens, states, tokens and accessibility; reviews the built UI."
  "Mason|claude|$SONNET|high|Builder|Implements code strictly from the blueprint and checklist."
  "Luna|copilot|$GPT|high|Reviewer|Reviews code for correctness, security and reliability. Quality gate."
  "Quinn|copilot|$GPT|medium|QA Tester|Writes and runs tests mapped to acceptance criteria and DoDs."
  "Max|claude|$SONNET|medium|Optimizer|Behavior-preserving refactoring and optimization, on explicit request only."
  "Dep|copilot|$GPT|medium|DevOps|CI/CD, containers, environment config and deployment verification."
)

ANTHROPIC_SKILLS="https://github.com/anthropics/skills/tree/main/skills"

# skill name | import URL | agents
SKILLS=(
  "frontend-design|$ANTHROPIC_SKILLS/frontend-design|Iris Mason"
  "webapp-testing|$ANTHROPIC_SKILLS/webapp-testing|Iris Quinn"
)

command -v multica >/dev/null || { echo "multica CLI not found" >&2; exit 1; }
command -v jq >/dev/null || { echo "jq not found" >&2; exit 1; }

RUNTIMES="$(multica runtime list --output json)"

runtime_id() {
  jq -r --arg p "$1" --arg h "$HOST" \
    '[.[] | select(.provider == $p and (.name | contains($h)))] | (map(select(.status == "online")) + .)[0].id // empty' \
    <<<"$RUNTIMES"
}

agent_id() {
  multica agent list --output json | jq -r --arg n "$1" '[.[] | select(.name == $n)][0].id // empty'
}

IDS=""
id_of() { awk -F= -v n="$1" '$1 == n { print $2 }' <<<"$IDS"; }

for row in "${AGENTS[@]}"; do
  IFS='|' read -r name provider model thinking role desc <<<"$row"
  file="instructions/$(tr '[:upper:]' '[:lower:]' <<<"$name").md"
  instructions="$(cat "$file")"

  rid="$(runtime_id "$provider")"
  [[ -n "$rid" ]] || { echo "No '$provider' runtime found on host '$HOST' (set SQUAD_HOST)" >&2; exit 1; }

  id="$(agent_id "$name")"
  if [[ -n "$id" ]]; then
    echo "~ $name: exists, syncing instructions/model/thinking"
    multica agent update "$id" --instructions "$instructions" --description "$desc" \
      --model "$model" --thinking-level "$thinking" --output json >/dev/null
  else
    echo "+ $name: creating on $provider ($model, thinking=$thinking)"
    args=(--name "$name" --description "$desc" --instructions "$instructions"
          --runtime-id "$rid" --model "$model" --max-concurrent-tasks "$MAX_CONCURRENT" --output json)
    if ! out="$(multica agent create "${args[@]}" --thinking-level "$thinking" 2>&1)"; then
      echo "  ! create with thinking=$thinking failed, retrying with runtime default:" >&2
      echo "    $out" >&2
      out="$(multica agent create "${args[@]}")"
    fi
    id="$(jq -r '.id' <<<"$out")"
  fi
  IDS+="$name=$id"$'\n'
done

squad_id="$(multica squad list --output json | jq -r --arg n "$SQUAD_NAME" '[.[] | select(.name == $n)][0].id // empty')"
if [[ -z "$squad_id" ]]; then
  echo "+ Squad '$SQUAD_NAME': creating with Orchestrator as leader"
  squad_id="$(multica squad create --name "$SQUAD_NAME" --leader "$(id_of Orchestrator)" \
    --description "Rex → Alex → Aria → Iris (UI only) → Mason → Luna → Quinn → Dep (+ Max on request). Assign an issue to the squad to start." \
    --output json | jq -r '.id')"
else
  echo "~ Squad '$SQUAD_NAME': exists"
fi

members="$(multica squad member list "$squad_id" --output json | jq -r '.[] | (.member_id // .agent_id // .id)')"

for row in "${AGENTS[@]}"; do
  IFS='|' read -r name _ _ _ role _ <<<"$row"
  [[ "$name" == "Orchestrator" ]] && continue
  if grep -qx "$(id_of "$name")" <<<"$members"; then
    echo "~ $name: already in squad"
  else
    echo "+ $name: adding to squad as '$role'"
    multica squad member add "$squad_id" --member-id "$(id_of "$name")" --role "$role" >/dev/null
  fi
done

for row in "${SKILLS[@]}"; do
  IFS='|' read -r skill url agents <<<"$row"
  sid="$(multica skill list --output json | jq -r --arg n "$skill" '[.[] | select(.name == $n)][0].id // empty')"
  if [[ -z "$sid" ]]; then
    echo "+ Skill $skill: importing"
    multica skill import --url "$url" --on-conflict skip --output json >/dev/null
    sid="$(multica skill list --output json | jq -r --arg n "$skill" '[.[] | select(.name == $n)][0].id // empty')"
    [[ -n "$sid" ]] || { echo "Skill '$skill' not found after import from $url" >&2; exit 1; }
  fi
  for name in $agents; do
    aid="$(id_of "$name")"
    if multica agent skills list "$aid" --output json | jq -e --arg s "$sid" 'any(.[]; (.id // .skill_id) == $s)' >/dev/null; then
      echo "~ $name: has $skill"
    else
      echo "+ $name: assigning $skill"
      multica agent skills add "$aid" --skill-ids "$sid" >/dev/null
    fi
  done
done

echo
echo "Done. Squad '$SQUAD_NAME' ($squad_id):"
multica squad member list "$squad_id"
