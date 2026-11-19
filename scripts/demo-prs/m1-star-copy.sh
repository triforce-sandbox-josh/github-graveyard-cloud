#!/usr/bin/env bash
# Demo M1: a copy tweak in components/StarCard.tsx. components/** is Frontend's shared-ui path
# (required, medium tier), so Frontend is asked for one approval; no Security, no second person.
# Usage: scripts/demo-prs/m1-star-copy.sh
# Re-running resets demo/m1-star-copy to origin/main and updates the same PR. If an earlier M1 was
# merged (approving it lets Triforce merge it), this run changes the headline back instead.
. "$(dirname "$0")/lib.sh"
BRANCH=demo/m1-star-copy
LONG='Don&apos;t let this repo end up in a graveyard.'
SHORT='Don&apos;t let this repo join the graveyard.'

demo_init
demo_reset_branch "$BRANCH"

if grep -qF -- "$LONG" components/StarCard.tsx; then
  demo_replace components/StarCard.tsx "$LONG" "$SHORT"
  TITLE="Shorter star-card headline"
else
  demo_replace components/StarCard.tsx "$SHORT" "$LONG"
  TITLE="Restore the star-card headline"
fi

demo_commit "$TITLE"
demo_push "$BRANCH"
demo_open_pr "$BRANCH" "[demo M1] $TITLE" \
"Demo M1. Changes the headline on the star card in \`components/StarCard.tsx\`.

Opened by scripts/demo-prs/m1-star-copy.sh (demo PR; the README in that folder says what to expect)."
