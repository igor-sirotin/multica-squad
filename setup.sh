#!/usr/bin/env bash
# Creates (or updates) the 12-agent squad in the current Multica workspace.
# Safe to re-run: existing agents get their runtime/instructions/model/thinking synced.
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

# name | runtime provider | model | thinking (empty = runtime default) | squad role | description
AGENTS=(
  "Orchestrator|claude|$SONNET|medium|Leader|Squad leader. Routes work to specialists one phase at a time and relays summaries."
  "Rex|claude|$OPUS|high|Analyst|Turns vague intent into a precise spec: MoSCoW features, user stories, edge cases."
  "Alex|claude|$SONNET|high|Strategist|Turns requirements into a dependency-aware checklist with binary Definitions of Done."
  "Aria|claude|$OPUS|high|Architect|Designs data model, API contracts, file structure and security architecture."
  "Iris|claude|$OPUS|high|Designer|Designs UI flows, screens, states, tokens and accessibility; reviews the built UI."
  "Mason|claude|$SONNET|high|Builder|Implements code strictly from the blueprint and checklist."
  "Luna|claude|$OPUS|high|Reviewer|Reviews code for correctness, security and reliability. Quality gate."
  "Quinn|claude|$SONNET|medium|QA Tester|Writes and runs tests mapped to acceptance criteria and DoDs."
  "Max|claude|$SONNET|medium|Optimizer|Behavior-preserving refactoring and optimization, on explicit request only."
  "Dep|claude|$SONNET|medium|DevOps|CI/CD, containers, environment config and deployment verification."
  "Portia|claude|$OPUS|high|Legal Counsel|Privacy and legal requirements for personal data; compliance review of PRs."
  "Hex|claude|$OPUS|high|Security Engineer|Threat models sensitive features and reviews PRs for exploitable security issues."
)

ANTHROPIC_SKILLS="https://github.com/anthropics/skills/tree/main/skills"
ANTHROPIC_LEGAL="https://github.com/anthropics/knowledge-work-plugins/tree/main/legal/skills"
TOB="https://github.com/trailofbits/skills/tree/main/plugins"

WORKERS="Rex Alex Aria Iris Mason Luna Quinn Max Dep Portia Hex"

# skill name | import URL or local file | agents
SKILLS=(
  "squad-worker-contract|skills/squad-worker-contract.md|$WORKERS"
  "frontend-design|$ANTHROPIC_SKILLS/frontend-design|Iris Mason"
  "webapp-testing|$ANTHROPIC_SKILLS/webapp-testing|Iris Quinn"
  "compliance-check|$ANTHROPIC_LEGAL/compliance-check|Portia"
  "legal-risk-assessment|$ANTHROPIC_LEGAL/legal-risk-assessment|Portia"
  "gdpr-data-handling|https://github.com/wshobson/agents/tree/main/plugins/hr-legal-compliance/skills/gdpr-data-handling|Portia Aria"
  "differential-review|$TOB/differential-review/skills/differential-review|Hex"
  "sharp-edges|$TOB/sharp-edges/skills/sharp-edges|Hex"
  "supply-chain-risk-auditor|$TOB/supply-chain-risk-auditor/skills/supply-chain-risk-auditor|Hex"
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
    echo "~ $name: exists, syncing runtime/instructions/model/thinking"
    multica agent update "$id" --instructions "$instructions" --description "$desc" \
      --runtime-id "$rid" --model "$model" --thinking-level "$thinking" --output json >/dev/null
  else
    echo "+ $name: creating on $provider ($model, thinking=${thinking:-default})"
    out="$(multica agent create --name "$name" --description "$desc" --instructions "$instructions" \
      --runtime-id "$rid" --model "$model" --thinking-level "$thinking" \
      --max-concurrent-tasks "$MAX_CONCURRENT" --output json)"
    id="$(jq -r '.id' <<<"$out")"
  fi
  IDS+="$name=$id"$'\n'
done

SQUAD_DESC="Autonomous team: assign a feature or problem to the squad, get a PR back for final review."
LEAD="$(multica user profile get --output json)"
SQUAD_INSTRUCTIONS="$(<instructions/squad.md)"
SQUAD_INSTRUCTIONS="${SQUAD_INSTRUCTIONS//"{{LEAD_NAME}}"/"$(jq -r .name <<<"$LEAD")"}"
SQUAD_INSTRUCTIONS="${SQUAD_INSTRUCTIONS//"{{LEAD_ID}}"/"$(jq -r .id <<<"$LEAD")"}"

squad_id="$(multica squad list --output json | jq -r --arg n "$SQUAD_NAME" '[.[] | select(.name == $n)][0].id // empty')"
if [[ -z "$squad_id" ]]; then
  echo "+ Squad '$SQUAD_NAME': creating with Orchestrator as leader"
  squad_id="$(multica squad create --name "$SQUAD_NAME" --leader "$(id_of Orchestrator)" \
    --description "$SQUAD_DESC" \
    --output json | jq -r '.id')"
else
  echo "~ Squad '$SQUAD_NAME': exists, syncing instructions"
fi
multica squad update "$squad_id" --instructions "$SQUAD_INSTRUCTIONS" --description "$SQUAD_DESC" >/dev/null

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

skill_id() {
  multica skill list --output json | jq -r --arg n "$1" '[.[] | select(.name == $n)][0].id // empty'
}

for row in "${SKILLS[@]}"; do
  IFS='|' read -r skill src agents <<<"$row"
  sid="$(skill_id "$skill")"
  if [[ "$src" != https://* ]]; then
    desc="$(head -1 "$src" | sed 's/^# *//')"
    if [[ -z "$sid" ]]; then
      echo "+ Skill $skill: creating from $src"
      multica skill create --name "$skill" --description "$desc" --content-file "$src" --output json >/dev/null
    else
      echo "~ Skill $skill: syncing from $src"
      multica skill update "$sid" --content-file "$src" --output json >/dev/null
    fi
  elif [[ -z "$sid" ]]; then
    echo "+ Skill $skill: importing"
    multica skill import --url "$src" --on-conflict skip --output json >/dev/null
  fi
  sid="${sid:-$(skill_id "$skill")}"
  [[ -n "$sid" ]] || { echo "Skill '$skill' not found after create/import from $src" >&2; exit 1; }
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
