#!/usr/bin/env bash
# Reset every demo PR to a fresh run: close the open [demo ...] PRs, delete their demo branches,
# then open A1, M1, D1 and A2 again from origin/main with the per-demo scripts in this folder.
#
# Usage: scripts/demo-prs/reset-all.sh [--dry-run] [--only a1,m1,d1,a2,d2] [--prompter <login>]
#   --dry-run       list what would be closed and opened; change nothing
#   --only LIST     reset only these demos (default: a1,m1,d1,a2; d2 is not in the live demo)
#   --prompter X    the D2 prompter login (or set DEMO_PROMPTER); required when d2 is included
#   --gap SECONDS   pause between opening demo PRs (or set DEMO_GAP; default 10, 0 to skip)
#
# Not run here: the follow-up steps that are part of the live demo itself (d1-fix.sh, the
# approvals, and the optional d2-push.sh and D3 review). Each open PR is evaluated by the live
# Triforce service, which spends model tokens (about $0.07 per PR on the OpenRouter Sonnet/Haiku pin).

# The per-demo scripts check out other branches, which can remove or change this folder while bash
# is still reading this file. Run from a temporary copy instead, from the same working directory.
if [ -z "${DEMO_RESET_COPY:-}" ]; then
  tmp=$(mktemp -d "${TMPDIR:-/tmp}/demo-prs.XXXXXX")
  cp "$(dirname "$0")"/*.sh "$tmp/"
  DEMO_RESET_COPY=$tmp exec bash "$tmp/$(basename "$0")" "$@"
fi
. "$(dirname "$0")/lib.sh"
HERE=$(cd "$(dirname "$0")" && pwd)

DRY=0
ONLY="a1,m1,d1,a2"
PROMPTER=${DEMO_PROMPTER:-}
# A pause between demos spreads out the Triforce evaluations so a burst of four PRs doesn't
# hit OpenRouter's rate limit (429).
GAP=${DEMO_GAP:-10}
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1 ;;
    --only) ONLY=${2:?--only needs a list}; shift ;;
    --prompter) PROMPTER=${2:?--prompter needs a login}; shift ;;
    --gap) GAP=${2:?--gap needs a number of seconds}; shift ;;
    -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
    *) demo_die "unknown argument: $1 (see --help)" ;;
  esac
  shift
done

# Demo key -> title tag, script, extra args.
demo_tag() { case "$1" in a1) echo A1 ;; m1) echo M1 ;; d1) echo D1 ;; a2) echo A2 ;; d2) echo D2 ;; *) demo_die "unknown demo '$1' (use a1,m1,d1,a2,d2)" ;; esac; }
demo_script() { case "$1" in a1) echo a1-epitaph.sh ;; m1) echo m1-star-copy.sh ;; d1) echo d1-share-target.sh ;; a2) echo a2-share-username.sh ;; d2) echo d2-data-track.sh ;; esac; }

IFS=, read -r -a KEYS <<< "$ONLY"
for k in "${KEYS[@]}"; do demo_tag "$k" >/dev/null; done
case "$GAP" in ''|*[!0-9]*) demo_die "--gap must be a whole number of seconds" ;; esac
case ",$ONLY," in *,d2,*) [ -n "$PROMPTER" ] || demo_die "d2 needs a prompter: --prompter <login> or DEMO_PROMPTER" ;; esac

demo_init
echo "Repo: $DEMO_REPO   base: origin/$DEMO_BASE @ $(git rev-parse --short "origin/$DEMO_BASE")"

# 1. Close the open PRs for the chosen demos (matched by the "[demo XX]" title tag, whatever the
#    branch, so older runs on task/... branches are caught too). Only demo/... branches are deleted.
for k in "${KEYS[@]}"; do
  tag=$(demo_tag "$k")
  while IFS=$'\t' read -r num head; do
    [ -n "$num" ] || continue
    case "$head" in demo/*) del=--delete-branch ;; *) del= ;; esac
    if [ "$DRY" = 1 ]; then
      echo "would close #$num ($head)${del:+ and delete its branch}"
    else
      gh pr close "$num" -R "$DEMO_REPO" $del --comment "Closed by scripts/demo-prs/reset-all.sh to start a fresh demo run." >/dev/null
      echo "closed #$num ($head)${del:+, branch deleted}"
    fi
  done < <(gh pr list -R "$DEMO_REPO" --state open --search "in:title \"[demo $tag]\"" --json number,headRefName,title \
             --jq ".[] | select(.title | startswith(\"[demo $tag]\")) | [.number, .headRefName] | @tsv")
done

# Branches deleted above leave stale origin/demo/... tracking refs, which make the per-demo
# scripts' --force-with-lease push fail with "stale info". Prune them first.
[ "$DRY" = 1 ] || git fetch -q --prune origin

# 2. Open each demo again (each script resets its own demo/... branch from origin/main), pausing
#    GAP seconds between demos.
first=1
for k in "${KEYS[@]}"; do
  s=$(demo_script "$k")
  if [ "$first" = 0 ] && [ "$GAP" -gt 0 ]; then
    if [ "$DRY" = 1 ]; then echo "would wait ${GAP}s"; else sleep "$GAP"; fi
  fi
  first=0
  if [ "$DRY" = 1 ]; then
    echo "would run $s${PROMPTER:+$( [ "$k" = d2 ] && echo " $PROMPTER")}"
    continue
  fi
  echo "== $(demo_tag "$k"): $s"
  if [ "$k" = d2 ]; then bash "$HERE/$s" "$PROMPTER"; else bash "$HERE/$s"; fi
done

[ "$DRY" = 1 ] && exit 0
echo
echo "Open demo PRs now:"
gh pr list -R "$DEMO_REPO" --state open --search 'in:title "[demo"' --json number,title,url \
  --jq '.[] | select(.title | startswith("[demo ")) | "#\(.number)  \(.title)  \(.url)"'
