#!/usr/bin/env bash
# Step-by-step runner for the Triforce demo (D1, D2, D3, A1, A2 in README.md), for a person or an agent.
#
# Usage: scripts/demo-prs/run-demo.sh [options] <command> [step]
#   plan            list the steps in demo order, with a narration cue each
#   status          one screen: each demo PR's tier, who it waits on, check state, open defects (read-only)
#   check <step>    evaluate the step's "Look for" items against the live PR (read-only)
#   run <step>      do the step (calls the per-demo scripts; human steps print who must click what),
#                   wait for Triforce to finish, then run the checks
#   all             go through every step in order, pausing for Enter before each (needs a terminal)
# Options:
#   --dry-run          print the actions; change nothing (no pushes, no PRs, no waiting)
#   --prompter LOGIN   D2 prompter login (or DEMO_PROMPTER); needed by reset and d2-open
#   --no-wait          at human steps, print the instructions and return without polling
#   --force            let run d1-open/d2-open/a1/a2 reset a demo PR that is already open
#   --with-reset       include the reset step in `all`
# Env: DEMO_TIMEOUT (Triforce wait, default 360s), DEMO_REVIEW_TIMEOUT (human click, default 480s),
#      DEMO_POLL (default 10s), DEMO_PR_D1/D2/A1/A2 (use this PR number instead of looking it up).
# Check lines start with PASS, FAIL, WARN (model judgement) or SKIP. Exit status 1 when any FAIL.
# shellcheck disable=SC2016,SC2034  # checks are eval'd strings; fields are read inside them

# The per-demo scripts check out branches that do not have this file. Run from a temporary copy.
if [ -z "${DEMO_RUN_COPY:-}" ]; then
  tmp=$(mktemp -d "${TMPDIR:-/tmp}/demo-run.XXXXXX")
  cp "$(dirname "$0")"/*.sh "$tmp/"
  DEMO_RUN_COPY=$tmp exec bash "$tmp/$(basename "$0")" "$@"
fi
. "$(dirname "$0")/lib.sh"
set +o pipefail   # the checks pipe into grep -q / head, which close their input early
HERE=$(cd "$(dirname "$0")" && pwd)

DRY=0 NOWAIT=0 FORCE=0 WITH_RESET=0 PROMPTER=${DEMO_PROMPTER:-}
TIMEOUT=${DEMO_TIMEOUT:-360} REVIEW_TIMEOUT=${DEMO_REVIEW_TIMEOUT:-480} POLL=${DEMO_POLL:-10}
ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1 ;;
    --no-wait) NOWAIT=1 ;;
    --force) FORCE=1 ;;
    --with-reset) WITH_RESET=1 ;;
    --prompter) PROMPTER=${2:?--prompter needs a login}; shift ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    -*) demo_die "unknown option: $1 (see --help)" ;;
    *) ARGS+=("$1") ;;
  esac
  shift
done
PROMPTER=${PROMPTER#@}
CMD=${ARGS[0]:-plan} STEP=${ARGS[1]:-}

url=$(git remote get-url origin 2>/dev/null || true)
case "$url" in
  *github-graveyard-cloud*) DEMO_REPO=${DEMO_REPO:-$(printf '%s' "$url" | sed -E 's#(\.git)?$##; s#^.*[:/]([^/:]+/[^/]+)$#\1#')} ;;
  *) DEMO_REPO=${DEMO_REPO:-triforce-sandbox-josh/github-graveyard-cloud} ;;
esac

STEPS="reset a1 d1-open d1-fix d3-request d3-push a2 d2-open d2-push approve"
# step_info <step>: sets TAG (demo PR), KIND (action|human), WHO (who must act), CUE (narration).
step_info() {
  WHO="the author (this script)"
  case "$1" in
    reset) TAG=- KIND=action CUE="Fresh slate: close old demo PRs, open D1, D2, A1, A2 from main (spends tokens; only when Josh asks)." ;;
    a1) TAG=A1 KIND=action CUE="A joke in lib/epitaphs.ts: low tier, nobody is asked, it merges itself once CI is green." ;;
    d1-open) TAG=D1 KIND=action CUE="share_target in lib/analytics.ts: Security by path, high tier, 1 defect inline, waiting on the author, nobody else pinged." ;;
    d1-fix) TAG=D1 KIND=action CUE="Author pushes the fix: defect thread resolved 'Fixed in <sha>', now Security is asked, two people needed." ;;
    d3-request) TAG=D1 KIND=human WHO="a Security member other than the author (silasjmatson, trevor-coleman or trevbot-9000)"
      CUE="Security requests changes: it goes back to 'Waiting on @author' with the review quoted." ;;
    d3-push) TAG=D1 KIND=action CUE="Author pushes again: the Security reviewer is requested again automatically." ;;
    a2) TAG=A2 KIND=action CUE="username in ShareBar: not a Security path, but the classifier adds data-privacy-egress by file:line; high tier." ;;
    d2-open) TAG=D2 KIND=action CUE="Bot-style PR, data-track-* in app/page.tsx: no Security path, the classifier/AI reviewer tags Security in." ;;
    d2-push) TAG=D2 KIND=action CUE="The tracking lines are removed: Security stays on the PR (no silent un-routing)." ;;
    approve) TAG=D1 KIND=human WHO="two different Security members other than the author (high tier needs 2 approvals)"
      CUE="Security approves (twice, high tier): the triforce check turns green and the gate opens." ;;
    *) demo_die "unknown step '$1' (steps: $STEPS)" ;;
  esac
}
branch_of() { case "$1" in D1) echo demo/d1-share-target ;; D2) echo demo/d2-data-track ;; A1) echo demo/a1-epitaph ;; A2) echo demo/a2-share-username ;; esac; }

# find_pr <TAG>: the open demo PR for the tag (else the newest one, e.g. a merged A1), by head branch.
find_pr() {
  local ov
  eval "ov=\${DEMO_PR_$1:-}"
  if [ -n "$ov" ]; then echo "$ov"; return; fi
  gh pr list -R "$DEMO_REPO" --head "$(branch_of "$1")" --state all --limit 20 --json number,state \
    --jq '([.[]|select(.state=="OPEN")]|max_by(.number)) // max_by(.number) | .number // empty'
}

# load_pr <TAG>: fetch the PR, its review threads and the triforce check run, and derive the fields below.
load_pr() {
  PR_NUM=$(find_pr "$1")
  [ -n "$PR_NUM" ] || return 1
  PR_JSON=$(gh pr view "$PR_NUM" -R "$DEMO_REPO" --json number,title,state,url,author,headRefOid,body,comments,reviews,reviewRequests,commits)
  q() { printf '%s' "$PR_JSON" | jq -r "$@"; }
  PR_URL=$(q .url) PR_STATE=$(q .state) PR_AUTHOR=$(q .author.login) PR_HEAD=$(q .headRefOid) PR_COMMITS=$(q '.commits|length')
  BLOCK=$(q .body | sed -n '/<!-- triforce:start -->/,/<!-- triforce:end -->/p' | perl -CSD -pe 's/\x{200B}//g')
  TIER=$(printf '%s\n' "$BLOCK" | sed -nE 's/.*alt="Tier: ([a-z]+)".*/\1/p' | head -1)
  HEADLINE=$(printf '%s\n' "$BLOCK" | awk '/^### /{f=1;next} f&&NF{print;exit}' | sed -E 's/\*\*//g')
  BLOCK_HEAD=$(printf '%s\n' "$BLOCK" | sed -nE 's/.*head `([0-9a-f]+)`.*/\1/p' | tail -1)
  SEC_ROW=$(printf '%s\n' "$BLOCK" | grep -F '| 🔐 Security' || true)
  AUTHOR_C=$(q '[.comments[]|select(.body|startswith("<!-- triforce:author -->"))]|last|.body // ""')
  if printf '%s' "$AUTHOR_C" | grep -q 'Nothing left for you'; then DEFECTS_OUT=0
  else DEFECTS_OUT=$(printf '%s' "$AUTHOR_C" | sed -nE 's/^\*\*([0-9]+) defects? outstanding.*/\1/p' | head -1); fi
  DEFECTS_OUT=${DEFECTS_OUT:-0}
  SEC_ROLE_N=$(q '[.comments[]|select(.body|startswith("<!-- triforce:role=security -->"))]|length')
  REQ=$(q '[.reviewRequests[]|(.login // .name // .slug)]|join(", ")')
  REQ_N=$(q '.reviewRequests|length')
  REQ_SEC=$(q '[.reviewRequests[]|select((.name // .slug // "")|test("security"))]|length')
  CR=$(gh api "repos/$DEMO_REPO/commits/$PR_HEAD/check-runs?check_name=triforce" --jq '.check_runs|sort_by(.started_at)|last // {}')
  CR_STATUS=$(printf '%s' "$CR" | jq -r '.status // "none"') CR_CONCL=$(printf '%s' "$CR" | jq -r '.conclusion // "-"')
  CR_TITLE=$(printf '%s' "$CR" | jq -r '.output.title // ""') CR_DONE_AT=$(printf '%s' "$CR" | jq -r '.completed_at // ""')
  DPE_LINE=$(printf '%s' "$CR" | jq -r '.output.summary // ""' | grep -E '^- `data-privacy-egress`' || true)
  DPE_WHY=${DPE_LINE#*· found by } DPE_WHY="found by ${DPE_WHY:0:90}" SEC_WHY=${SEC_ROW#*\(high\) · } SEC_WHY=${SEC_WHY:0:90}
  local o=${DEMO_REPO%%/*} r=${DEMO_REPO#*/}
  # One TSV row per review thread: resolved, kind (defect|decision|other), privacy-lens, fixed-in.
  THREADS=$(gh api graphql -f o="$o" -f r="$r" -F n="$PR_NUM" -f query='query($o:String!,$r:String!,$n:Int!){repository(owner:$o,name:$r){pullRequest(number:$n){reviewThreads(first:100){nodes{isResolved comments(first:20){nodes{body}}}}}}}' \
    --jq '.data.repository.pullRequest.reviewThreads.nodes[] | (.comments.nodes[0].body // "") as $b
      | [.isResolved, (if ($b|test("🐞 Defect")) then "defect" elif ($b|test("decision [0-9]+ of";"i")) then "decision" else "other" end),
         ($b|test("Privacy lens")), ([.comments.nodes[].body|select(test("Fixed in `"))]|length>0)] | @tsv')
  cnt() { printf '%s\n' "$THREADS" | awk -F'\t' "$1" | grep -c . || true; }
  DEF_TOTAL=$(cnt '$2=="defect"') DEF_OPEN=$(cnt '$2=="defect" && $1=="false"')
  DEF_FIXED=$(cnt '$2=="defect" && $1=="true" && $4=="true"') DEC_PRIV=$(cnt '$2=="decision" && $3=="true"')
}

# --- check output -------------------------------------------------------------------------------
NP=0 NF=0 NW=0 NS=0
res() { printf '%-5s %s%s\n' "$1" "$2" "${3:+  ($3)}"; }
pass() { NP=$((NP+1)); res PASS "$@"; }
fail() { NF=$((NF+1)); res FAIL "$@"; }
warn() { NW=$((NW+1)); res WARN "$@"; }
skip() { NS=$((NS+1)); res SKIP "$@"; }
ok() { if eval "$1"; then pass "$2" "${3:-}"; else fail "$2" "${4:-${3:-}}"; fi; }
waiting_on_author() { case "$HEADLINE" in *"Waiting on @$PR_AUTHOR"*) return 0 ;; esac; return 1; }
humans() { q --arg st "$1" --arg a "$PR_AUTHOR" '[.reviews[]|select(.state==$st and .author.login!=$a and (.author.login|test("triforce|\\[bot\\]")|not))|.author.login]|unique|join(",")'; }
state_note() { echo "now: $HEADLINE; $DEFECTS_OUT defect(s) outstanding; $PR_COMMITS commit(s)"; }

check_step() {
  step_info "$1"
  NP=0 NF=0 NW=0 NS=0
  if [ "$TAG" = - ]; then show_status; return 0; fi
  load_pr "$TAG" || { echo "FAIL  no [demo $TAG] PR found (branch $(branch_of "$TAG"))"; return 1; }
  echo "== check $1: [demo $TAG] #$PR_NUM $PR_STATE  tier=${TIER:-?}  $HEADLINE"
  [ -z "$BLOCK_HEAD" ] || [ "${PR_HEAD#"$BLOCK_HEAD"}" != "$PR_HEAD" ] || warn "Routing block is for $BLOCK_HEAD, head is ${PR_HEAD:0:7}" "Triforce may still be working"
  case "$1" in
    a1)
      ok '[ "$TIER" = low ]' "Low tier, no required reviewers" "check: $CR_TITLE"
      skip "Read by every AI reviewer" "model behaviour; not shown on a low-tier PR"
      ok '[ "$CR_CONCL" = success ]' "triforce check passes" "$CR_STATUS/$CR_CONCL $CR_TITLE"
      ok '[ "$PR_STATE" = MERGED ] && [ "$REQ_N" = 0 ] && [ -z "$(humans APPROVED)" ]' "Merged with no person asked" "state $PR_STATE, requested: ${REQ:-nobody}" ;;
    d1-open)
      ok 'printf "%s" "$DPE_LINE" | grep -q "required, high.*found by path" && [ "$TIER" = high ]' "Security required by path, high tier" "tier=$TIER; $DPE_WHY"
      if [ "${SAW_PROGRESS:-0}" = 1 ]; then pass "Check was in progress (Preparing your review) first"; else skip "Check in progress until AI reviewers finish" "transient; seen only during run"; fi
      ok waiting_on_author "Waiting on @$PR_AUTHOR" "$HEADLINE"
      ok '[ "$DEF_OPEN" -ge 1 ]' "Defect posted as an inline thread" "$DEF_OPEN open of $DEF_TOTAL"
      case "$DEFECTS_OUT" in 1) pass "\"1 defect outstanding\" in the author comment" ;; 0) fail "\"1 defect outstanding\" in the author comment" "0 outstanding" ;;
        *) warn "\"1 defect outstanding\" in the author comment" "$DEFECTS_OUT outstanding: extra defects are model judgement" ;; esac
      ok '[ "$REQ_N" = 0 ]' "Nobody else is notified" "requested: ${REQ:-nobody}" ;;
    d1-fix)
      ok '[ "$DEF_TOTAL" -ge 1 ] && [ "$DEF_OPEN" = 0 ] && [ "$DEF_FIXED" -ge 1 ]' "Defect thread resolved with \"Fixed in <sha>\"" "$DEF_FIXED fixed, $DEF_OPEN open; $PR_COMMITS commit(s)"
      ok '[ "$REQ_SEC" -ge 1 ]' "Security team requested" "requested: ${REQ:-nobody}; $(state_note)"
      case "$SEC_ROLE_N" in 1) pass "One Security role comment" ;; 0) fail "One Security role comment" "none yet; $(state_note)" ;; *) warn "One Security role comment" "$SEC_ROLE_N found" ;; esac
      if [ "$DEC_PRIV" -ge 1 ]; then pass "Decision thread from the privacy lens"; else warn "Decision thread from the privacy lens" "none: model judgement (may not appear when nothing is left to decide)"; fi
      ok '[ "$REQ_N" -ge 2 ] && printf "%s" "$BLOCK" | grep -qF "| 👥 Second person"' "Two people requested, and the second-person row" "requested: ${REQ:-nobody}" ;;
    d3-request)
      local cr; cr=$(humans CHANGES_REQUESTED)
      ok '[ -n "$cr" ]' "A Security member requested changes" "${cr:-no Request changes review yet}"
      ok waiting_on_author "Waiting on @$PR_AUTHOR" "$HEADLINE"
      ok 'printf "%s" "$AUTHOR_C" | grep -q "Reviewers asked you to"' "Review quoted under \"Reviewers asked you to\"" "author comment" ;;
    d3-push)
      local cr u miss=; cr=$(humans CHANGES_REQUESTED)
      if [ -z "$cr" ]; then fail "Reviewer who requested changes is requested again" "no Request changes review on the PR"
      else
        for u in ${cr//,/ }; do case ", $REQ," in *", $u,"*) ;; *) miss="$miss $u" ;; esac; done
        ok '[ -z "$miss" ]' "Reviewer who requested changes is requested again" "requested: ${REQ:-nobody}" "not re-requested:$miss; requested: ${REQ:-nobody}"
      fi
      ok '! waiting_on_author' "Back to the ready view (not waiting on the author)" "$HEADLINE" ;;
    a2)
      ok 'printf "%s" "$DPE_LINE" | grep -q "found by classifier" && ! printf "%s" "$DPE_LINE" | grep -q "found by path" && printf "%s" "$DPE_LINE" | grep -qE "(line|lines|L) ?~?[0-9]+|:[0-9]+"' \
        "Classifier adds data-privacy-egress with a file:line reason" "$DPE_WHY"
      ok '[ "$TIER" = high ]' "High tier" "tier=${TIER:-?}"
      if [ "$DEC_PRIV" -ge 1 ]; then pass "IE decision thread from the privacy lens"; else warn "IE decision thread from the privacy lens" "none; $DEF_OPEN defect(s) open: model judgement"; fi
      ok '[ "$REQ_N" -ge 2 ] && printf "%s" "$BLOCK" | grep -qF "| 👥 Second person"' "Two people requested, and the second-person row" "requested: ${REQ:-nobody}; $(state_note)" ;;
    d2-open)
      ok '[ -n "$DPE_LINE" ] && ! printf "%s" "$DPE_LINE" | grep -q "found by path"' "No Security path match (app/page.tsx)" "$DPE_WHY"
      ok 'printf "%s" "$SEC_ROW" | grep -qE "(Classifier|AI reviewer):.*((line|lines|L) ?~?[0-9]+|:[0-9]+)"' "Security added by classifier/AI reviewer with a path:line reason" "$SEC_WHY"
      if [ -n "$PROMPTER" ] && printf "%s" "$HEADLINE" | grep -q "Waiting on @$PROMPTER"; then pass "\"Waiting on\" names the prompter @$PROMPTER"
      else skip "\"Waiting on\" names the prompter" "known limit: needs a Bot-authored PR (README); $HEADLINE; $(printf '%s\n' "$BLOCK" | grep -o 'Prompted by.*' | head -1)"; fi ;;
    d2-push)
      ok '[ "$PR_COMMITS" -ge 2 ]' "d2-push.sh commit is on the PR" "$PR_COMMITS commit(s)"
      ok '[ -n "$SEC_ROW" ] && [ -n "$DPE_LINE" ]' "Security is still on the PR after the line is gone" "$SEC_WHY" ;;
    approve)
      local ap; ap=$(humans APPROVED)
      ok '[ "$(printf "%s" "$ap" | tr , "\n" | grep -c .)" -ge 2 ]' "Two different people approved (high tier)" "approved by: ${ap:-nobody}"
      ok '[ "$CR_CONCL" = success ]' "Gate passes (triforce check green)" "$CR_STATUS/$CR_CONCL: $CR_TITLE" ;;
  esac
  echo "RESULT $1: $NP pass, $NF fail, $NW warn, $NS skip   $PR_URL"
  [ "$NF" = 0 ]
}

show_status() {
  local t
  echo "Demo PRs on $DEMO_REPO"
  for t in A1 D1 D2 A2; do
    if ! load_pr "$t"; then printf '%-3s  (no PR)\n' "$t"; continue; fi
    printf '%-3s #%-4s %-6s tier=%-6s %s\n' "$t" "$PR_NUM" "$PR_STATE" "${TIER:-?}" "${HEADLINE:-no routing block yet}"
    printf '     check: %s/%s "%s" | defects open: %s | approvals: %s | requested: %s\n' \
      "$CR_STATUS" "$CR_CONCL" "$CR_TITLE" "$DEF_OPEN" "$(humans APPROVED | sed 's/^$/-/')" "${REQ:--}"
    printf '     %s\n' "$PR_URL"
  done
}

# --- waiting ------------------------------------------------------------------------------------
# pause: sleep POLL seconds; in a terminal, Enter skips the wait (returns 1).
pause() { if [ -t 0 ]; then if read -r -t "$POLL" _; then return 1; fi; else sleep "$POLL"; fi; return 0; }

# wait_triforce <TAG> <old number:head> [after ISO time]: until the PR moved past <old> (if given)
# and the triforce check on it has completed (after the time, if given) and is not "Preparing".
wait_triforce() {
  local start last='' now line
  start=$(date +%s) SAW_PROGRESS=0
  echo "Waiting for Triforce on [demo $1] (up to ${TIMEOUT}s; Enter skips)"
  while :; do
    if ! load_pr "$1"; then line="waiting for the PR to appear"
    elif [ -n "$2" ] && [ "$PR_NUM:$PR_HEAD" = "$2" ]; then line="waiting for the push/new PR to show up"
    elif [ "$CR_STATUS" = none ]; then line="#$PR_NUM: triforce check not started"
    elif [ "$CR_STATUS" != completed ] || printf '%s' "$CR_TITLE" | grep -q Preparing; then SAW_PROGRESS=1 line="#$PR_NUM: in progress: $CR_TITLE"
    elif [ -n "${3:-}" ] && [[ "$CR_DONE_AT" < "$3" ]]; then line="#$PR_NUM: waiting for Triforce to see the review"
    else echo "  done after $(( $(date +%s) - start ))s: $CR_CONCL \"$CR_TITLE\""; return 0; fi
    now=$(( $(date +%s) - start ))
    [ "$line" = "$last" ] || echo "  [${now}s] $line"; last=$line
    [ "$now" -lt "$TIMEOUT" ] || { echo "  timed out after ${TIMEOUT}s; checking anyway"; return 0; }
    pause || { echo "  skipped"; return 0; }
  done
}

# wait_review <state> <count> <since ISO>: until <count> human reviews of <state> exist, submitted after <since>.
wait_review() {
  local start n
  start=$(date +%s)
  echo "Waiting for $2 review(s) of state $1 (up to ${REVIEW_TIMEOUT}s; Enter skips)"
  while :; do
    load_pr "$TAG" || demo_die "no [demo $TAG] PR"
    n=$(q --arg st "$1" --arg a "$PR_AUTHOR" --arg t "$3" '[.reviews[]|select(.state==$st and .submittedAt>$t and .author.login!=$a and (.author.login|test("triforce|\\[bot\\]")|not))|.author.login]|unique|length')
    if [ "$n" -ge "$2" ]; then echo "  seen: $(humans "$1")"; return 0; fi
    [ $(( $(date +%s) - start )) -lt "$REVIEW_TIMEOUT" ] || { echo "  timed out"; return 0; }
    pause || { echo "  skipped"; return 0; }
  done
}

# --- actions ------------------------------------------------------------------------------------
act() { if [ "$DRY" = 1 ]; then echo "would run: $*"; else echo "+ $*"; "$@"; fi; }
need_prompter() { [ -n "$PROMPTER" ] || demo_die "$1 needs the D2 prompter: --prompter <login> or DEMO_PROMPTER"; }
# already_open <TAG>: true when the demo PR is open and --force was not given (re-running would reset it).
already_open() {
  local n; n=$(find_pr "$1")
  [ -n "$n" ] && [ "$FORCE" = 0 ] && [ "$(gh pr view "$n" -R "$DEMO_REPO" --json state --jq .state)" = OPEN ] || return 1
  echo "[demo $1] #$n is already open, so checking it instead (--force re-runs the script: resets the PR, spends tokens)."
}
d3_push() {
  ( demo_init; demo_checkout_existing demo/d1-share-target
    git commit -q --allow-empty -m "Address review"
    demo_push_follow_up demo/d1-share-target; echo "Pushed an empty 'Address review' commit to demo/d1-share-target." )
}

run_step() {
  local s=$1 old='' since script=''
  step_info "$s"
  echo "== run $s: $CUE"
  if [ "$KIND" = human ]; then
    load_pr "$TAG" || demo_die "no [demo $TAG] PR"
    since=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    echo "HUMAN STEP. Who must act: $WHO"
    echo "  Open $PR_URL/files -> Review changes ->"
    if [ "$s" = d3-request ]; then echo "  pick 'Request changes', comment e.g. \"Please don't send raw share targets to analytics\", Submit review."
    else echo "  pick 'Approve', Submit review. (Each of two people; the author's own approval does not count.)"; fi
    [ "$DRY" = 0 ] && [ "$NOWAIT" = 0 ] || { echo "Then run: run-demo.sh check $s"; return 0; }
    if [ "$s" = d3-request ]; then wait_review CHANGES_REQUESTED 1 "$since"; else wait_review APPROVED 2 "$since"; fi
    wait_triforce "$TAG" "" "$since"
    check_step "$s"; return
  fi
  case "$s" in
    reset) need_prompter reset
      if [ "$DRY" = 1 ]; then bash "$HERE/reset-all.sh" --dry-run --prompter "$PROMPTER"; else act bash "$HERE/reset-all.sh" --prompter "$PROMPTER"; fi
      echo "Triforce evaluates the four PRs in ~3 min; then run: run-demo.sh status"; return 0 ;;
    a1) script=a1-epitaph.sh; if already_open A1; then check_step a1; return; fi ;;
    a2) script=a2-share-username.sh; if already_open A2; then check_step a2; return; fi ;;
    d1-open) script=d1-share-target.sh; if already_open D1; then check_step d1-open; return; fi ;;
    d2-open) script=d2-data-track.sh; if already_open D2; then check_step d2-open; return; fi; need_prompter d2-open ;;
    d1-fix) script=d1-fix.sh ;;
    d2-push) script=d2-push.sh ;;
  esac
  local n; n=$(find_pr "$TAG")   # remember "number:head" so the wait ignores the PR as it was before
  [ -z "$n" ] || old=$(gh pr view "$n" -R "$DEMO_REPO" --json number,headRefOid --jq '"\(.number):\(.headRefOid)"')
  if [ "$s" = d3-push ]; then
    if [ "$DRY" = 1 ]; then echo "would push an empty 'Address review' commit to demo/d1-share-target"; else d3_push; fi
  elif [ "$s" = d2-open ]; then act bash "$HERE/$script" "$PROMPTER"
  else act bash "$HERE/$script"; fi
  [ "$DRY" = 0 ] || { echo "would wait for Triforce on [demo $TAG] (up to ${TIMEOUT}s), then: check $s"; return 0; }
  wait_triforce "$TAG" "$old"
  if [ "$s" = a1 ]; then   # A1 merges itself once CI is green
    local start; start=$(date +%s)
    while [ "$(gh pr view "$PR_NUM" -R "$DEMO_REPO" --json state --jq .state)" = OPEN ] && [ $(( $(date +%s) - start )) -lt "$TIMEOUT" ]; do
      echo "  waiting for the auto-merge (CI)"; pause || break
    done
  fi
  check_step "$s"
}

show_plan() {
  local i=0 s
  echo "Triforce demo steps (run-demo.sh run <step> | check <step>). After a reset D1, D2 and A2 are already open, so 'run' on d1-open, d2-open or a2 only checks them."
  for s in $STEPS; do
    i=$((i+1)); step_info "$s"
    printf '%2d. %-11s %-6s %-3s %s\n' "$i" "$s" "$KIND" "$TAG" "$CUE"
  done
}

case "$CMD" in
  plan) show_plan ;;
  status) show_status ;;
  check) [ -n "$STEP" ] || demo_die "usage: check <step>"; check_step "$STEP" ;;
  run) [ -n "$STEP" ] || demo_die "usage: run <step>"; run_step "$STEP" ;;
  all)
    [ -t 0 ] || [ "$DRY" = 1 ] || demo_die "all needs a terminal (or --dry-run); agents should use run <step>"
    for s in $STEPS; do
      [ "$s" != reset ] || [ "$WITH_RESET" = 1 ] || continue
      step_info "$s"
      echo; echo ">>> $s ($KIND): $CUE"
      if [ "$DRY" = 0 ]; then
        printf 'Enter = run, s = skip, c = check only, q = quit: '; read -r a
        case "$a" in q) exit 0 ;; s) continue ;; c) check_step "$s" || true; continue ;; esac
      fi
      run_step "$s" || true
    done ;;
  *) demo_die "unknown command '$CMD' (plan, status, check, run, all; see --help)" ;;
esac
