---
name: triforce-demo
description: Drive the live Triforce demo on this repo step by step with scripts/demo-prs/run-demo.sh. Use when Josh says "run the demo", "next step", "check D1", "demo status", or names a demo step (a1, d1-open, d1-fix, d3-request, d3-push, a2, d2-open, d2-push, approve).
---

# Triforce demo driver

Josh narrates; you advance the demo one step at a time with `scripts/demo-prs/run-demo.sh` (run it from
the repo root). Read `scripts/demo-prs/README.md` once if you need the background of a step.

## Commands

- `scripts/demo-prs/run-demo.sh plan`: the steps in order with a narration cue. Run it first and keep
  track of which step is next.
- `scripts/demo-prs/run-demo.sh status`: one screen of all demo PRs (tier, who it waits on, check, defects).
- `scripts/demo-prs/run-demo.sh check <step>`: read-only; one `PASS`/`FAIL`/`WARN`/`SKIP` line per
  "Look for" item, then a `RESULT` line with the PR URL. Exit 1 on any FAIL.
- `scripts/demo-prs/run-demo.sh run <step>`: does the step, waits for Triforce (up to 6 min), then checks.
  Give the Bash call `timeout: 600000`. For d1-open, d2-open, a1 and a2 it only checks when the PR is
  already open.
- Human steps (`d3-request`, `approve`): run them with `--no-wait`. They print who must click what; tell
  Josh, wait for him to say it's done, then `check <step>`.
- D2 needs the prompter: `--prompter <login>` or `DEMO_PROMPTER`. Ask Josh if you don't know it.

## How to report

- After each step, say in one or two sentences what Triforce did and whether the checks passed. Quote a
  FAIL line's reason; say that WARN/SKIP items are model judgement or transient, not failures.
- At a human step, tell Josh exactly who must act (a Security member who is not the author), the PR URL,
  and what to click.
- If a check fails, say whether the PR is just at a different point in the flow (the detail says "now:
  ...") or Triforce did something unexpected. Don't retry a `run` on your own.

## Never

- Never approve, request changes, merge, close or comment on PRs yourself, and never push except
  through `run <step>`.
- Never run `run reset`, `reset-all.sh`, `--force`, or the per-demo scripts unless Josh asks for that
  in so many words: each one resets live demo PRs and spends model tokens.
- Use `--dry-run` when you only want to show what a step would do.
