---
name: triforce-demo
description: Drive the live Triforce demo on this repo step by step with scripts/demo-prs/run-demo.sh. Use when Josh says "run the demo", "next step", "check D1", "demo status", or names a demo step (a1, m1, m1-approve, d1-open, d1-fix, a2, approve; optional d3-request, d3-push, d2-open, d2-push).
---

# Triforce demo driver

Josh narrates; you advance the demo one step at a time with `scripts/demo-prs/run-demo.sh` (run it from
the repo root). Read `scripts/demo-prs/README.md` once if you need the background of a step.

The story is LOW -> MEDIUM -> HIGH: `a1` (LOW, merges itself), `m1` and `m1-approve` (MEDIUM,
Frontend, one approval), `d1-open` and `d1-fix` (HIGH, defect fixed live), `a2` (HIGH by classifier;
show it while D1 re-evaluates after the fix), then back to D1 for `approve`. `d3-request`, `d3-push`,
`d2-open` and `d2-push` are optional: run them only when Josh names them.

## Commands

- `scripts/demo-prs/run-demo.sh plan`: the steps in order with a narration cue, then the optional
  steps. Run it first and keep track of which step is next.
- `scripts/demo-prs/run-demo.sh status`: one screen of the demo PRs (A1, M1, D1, A2, and D2 while
  open): tier, who it waits on, check, defects.
- `scripts/demo-prs/run-demo.sh check <step>`: read-only; one `PASS`/`FAIL`/`WARN`/`SKIP` line per
  "Look for" item, then a `RESULT` line with the PR URL. Exit 1 on any FAIL.
- `scripts/demo-prs/run-demo.sh run <step>`: does the step, waits for Triforce (up to 6 min), then checks.
  Give the Bash call `timeout: 600000`. For a1, m1, d1-open, a2 and d2-open it only checks when the PR
  is already open.
- Human steps: run them with `--no-wait`. They print who must click what; tell Josh, wait for him to
  say it's done, then `check <step>`.
  - `m1-approve`: a `frontend` GitHub team member other than the author approves M1 once (Silas,
    silasjmatson). Triforce then merges M1 into main.
  - `approve`: Silas approves D1 as Security. A second, different approver (for example Uliana) is
    optional; it turns the gate green and Triforce merges D1, so the check only WARNs without it.
  - `d3-request` (optional): a Security member other than the author requests changes on D1.
- Only the optional `d2-open` needs the prompter: `--prompter <login>` or `DEMO_PROMPTER`. Ask Josh
  if you don't know it.

## How to report

- After each step, say in one or two sentences what Triforce did and whether the checks passed. Quote a
  FAIL line's reason; say that WARN/SKIP items are model judgement or transient, not failures.
- At a human step, tell Josh exactly who must act (for M1 a Frontend member, for D1 a Security member;
  never the author), the PR URL, and what to click. Remind him that a full set of approvals makes
  Triforce merge the demo PR into main, which matters in rehearsal.
- If a check fails, say whether the PR is just at a different point in the flow (the detail says "now:
  ...") or Triforce did something unexpected. Don't retry a `run` on your own.

## Never

- Never approve, request changes, merge, close or comment on PRs yourself, and never push except
  through `run <step>`.
- Never run `run reset`, `reset-all.sh`, `--force`, or the per-demo scripts unless Josh asks for that
  in so many words: each one resets live demo PRs and spends model tokens.
- Use `--dry-run` when you only want to show what a step would do.
