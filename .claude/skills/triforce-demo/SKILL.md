---
name: triforce-demo
description: Drive the live Triforce demo on this repo with scripts/demo-prs/run-demo.sh. Use when Josh says "stage the demo", "tour", "walk me through", "run the demo", "next step", "check D1", "demo status", or names a demo step (a1, m1, m1-approve, d1-open, d1-fix, a2, approve; optional d3-request, d3-push, d2-open, d2-push).
---

# Triforce demo driver

Josh narrates; you advance the demo one step at a time with `scripts/demo-prs/run-demo.sh` (run it from
the repo root). Read `scripts/demo-prs/README.md` once if you need the background of a step.

The story is LOW -> MEDIUM -> HIGH: `a1` (LOW, merges itself), `m1` and `m1-approve` (MEDIUM,
Frontend, one approval), `d1-open` and `d1-fix` (HIGH, defect fixed live), `a2` (HIGH by classifier;
show it while D1 re-evaluates after the fix), then back to D1 for `approve`. `d3-request`, `d3-push`,
`d2-open` and `d2-push` are optional: run them only when Josh names them.

## Demo day: stage, then tour

Triforce takes ~3-4 min per push or review, so the live demo is a tour of PRs staged beforehand.

- "Stage the demo": run `scripts/demo-prs/run-demo.sh stage` (Bash `timeout: 600000`; it can take
  ~20 min, so run it in the background and report as it goes). It resets, waits for Triforce, re-runs
  failed CI once, pushes the D1 fix, then stops for the human step: tell Josh that Silas
  (silasjmatson) must approve D1 as Security **with a one-line rationale** (give the D1 URL and the
  suggested text it prints). Exit 1 means a FAIL line to fix before the demo; quote it.
  `--skip-reset` keeps the open PRs; `--dry-run` only prints the plan. Staging resets live PRs and
  spends tokens: run it (other than `--dry-run`) only when Josh asks for it.
- "Tour" / "walk me through": run `scripts/demo-prs/run-demo.sh tour` (read-only) and relay it: per
  PR the URL, headline and the line to say, plus any `⚠️` line (a PR not in the state its line needs).
- Never give D1 its second approval or approve M1, or tell anyone to, except when Josh says it is the
  live demo moment: either one makes Triforce merge the PR into main.

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
