# Demo PRs

Scripts that open the demo pull requests on this repo, so a person can run the Triforce demo by
hand. Nothing here runs by itself: the PR that adds these scripts does not run them.

The live demo tells one story, LOW -> MEDIUM -> HIGH, in about 12 minutes:

1. **LOW**, A1: a joke. Nobody is asked; it merges itself.
2. **MEDIUM**, M1: a copy tweak in a shared component. Frontend is asked for one approval.
3. **HIGH**, D1: an analytics change with a planted bug. The author fixes it live.
4. **HIGH**, A2 (shown while D1 re-evaluates after the fix): by path it is only medium (Frontend),
   but the classifier escalates it to high with Security.
5. Back to D1: the defect is "Fixed in <sha>", Security is asked, and Silas approves as Security.

D2 and D3 still work but are not part of the live demo (see "Not in the live demo").

## Use

- Run from a clean clone of `github-graveyard-cloud` with `git` and an authenticated `gh`.
- Each script refuses to run on a dirty tree, creates its branch from `origin/main`, commits the
  change, force-resets its own `demo/...` branch on origin, and opens the PR (or updates the one
  that is already open, so re-running never opens a second). It never pushes to `main`, and returns
  you to the branch you started on.
- Each PR is titled `[demo A1] ...`, `[demo M1] ...`, `[demo D1] ...` and so on.
- Running the scripts makes the live Triforce service evaluate the PRs, which spends model tokens.
- Close or merge a demo PR before re-running its script if you want a fresh PR rather than an update.

To reset the demo at once (before a demo or a dry run), run `scripts/demo-prs/reset-all.sh`. It
closes every open `[demo A1/M1/D1/A2]` PR (whatever its branch), deletes their `demo/...` branches,
and opens all four fresh from `origin/main`. `--dry-run` shows what it would do; `--only d1,a2`
resets a subset (`--only d2 --prompter <login>` for D2); `--gap N` sets the pause between demo PRs
(default 10s, so the evaluations don't hit OpenRouter's rate limit). It does not run the follow-ups
that are part of the demo itself (`d1-fix.sh`, the approvals).

Accounts: the **author** runs the scripts (joshuayoes). **Silas** (silasjmatson) is in both the
`security` and `frontend` GitHub teams, so he can approve M1 and D1.

> [!WARNING]
> **Approvals can merge demo PRs into `main`.** `merge_when_ready: true` is on: once a demo PR has
> every required approval and CI is green, Triforce merges it. A merged D1 or A2 breaks re-running
> its script (D1 would add `trackShare` twice; A2 would add the attribute twice). `m1-star-copy.sh`
> copes (it changes the headline back), `a1-epitaph.sh` picks another joke.
> In rehearsal: don't approve M1, and don't give D1 a second approval. If one merges anyway,
> revert it on `main` before the next run.

## Run the whole demo

`scripts/demo-prs/run-demo.sh` walks the steps in demo order for a person or an agent:

```
reset  a1  m1  m1-approve  d1-open  d1-fix  a2  approve
```

- `run-demo.sh plan` lists the steps with a narration cue, then the optional steps; `status` shows
  every demo PR on one screen (A1, M1, D1, A2, and D2 while it is open).
- `run-demo.sh check <step>` checks that step's "Look for" items against the live PR (read-only):
  one `PASS`/`FAIL`/`WARN`/`SKIP` line each. Items that are model judgement are `WARN`, never `FAIL`.
- `run-demo.sh run <step>` does the step with the scripts in this folder, waits for the `triforce`
  check to finish, then checks. Human steps (`m1-approve`, `approve`) print who must click what and
  wait for one approval (`--no-wait` to skip). `run` on an already open A1, M1, D1 or A2 only checks it.
- `run-demo.sh stage` and `run-demo.sh tour`: see "Demo day" below.
- `run-demo.sh all` pauses before each main step (`--with-reset` adds `reset`); `--dry-run` changes
  nothing. The optional steps (`d3-request`, `d3-push`, `d2-open`, `d2-push`) are reachable only by
  name with `run`/`check`.

A Claude Code skill, `.claude/skills/triforce-demo`, drives it when you say "next step" or "run the
demo". It never resets, approves or merges on its own.

## Demo day: stage at 9:00, then tour

Triforce takes about 3-4 minutes to react to each push or review (CI plus the AI re-review), so the
live demo is a guided tour of PRs staged beforehand, not a wait on each step.

- **9:00: `run-demo.sh stage`.** Runs `reset` (skip with `--skip-reset`), waits for Triforce on A1,
  M1, D1 and A2 and checks each (A1 must have merged itself), re-runs a demo PR's failed CI jobs once
  (`gh run rerun <id> --failed`), pushes the D1 fix (`d1-fix`), then pauses for **Silas to approve D1
  as Security with a one-line rationale** (for example "Privacy decision OK; labels are fixed.";
  without a comment the Security row shows "no rationale"). Enter skips the wait. It ends with
  `status` and one PASS/FAIL line per PR, and exits 1 on any FAIL: fix those before 10:00.
  `stage --dry-run` prints the plan and changes nothing. Allow about 20 minutes.
- **Until the live moment, don't give D1 a second approval and don't approve M1**: Triforce merges a
  demo PR as soon as its gate is satisfied (`merge_when_ready`).
- **10:00: `run-demo.sh tour`.** Read-only. Prints the walkthrough in order (LOW A1, MEDIUM M1, HIGH
  D1, HIGH A2), each with its URL, current tier and headline, and a line to say. A `⚠️` line marks a
  PR whose state doesn't match its line (A1 not merged, D1 not yet approved by Security, and so on).
  It ends with the optional live beat: a second person approves D1, the gate turns green and Triforce
  merges D1. That is the only live click.

## LOW

### A1: `a1-epitaph.sh` (step `a1`)

Adds one joke to `lib/epitaphs.ts`. No team's path matches. Re-runs pick a joke that is not already
in the file (the first unused one from the script's list), and fail if every candidate is used.

Look for:

- [ ] Low tier, no required reviewers.
- [ ] Read by every AI reviewer.
- [ ] With nothing found and CI green, merges with no person asked (`merge_when_ready: true`).

Who must act: nobody.

## MEDIUM

### M1: `m1-star-copy.sh` (steps `m1`, `m1-approve`)

Shortens the star card's headline in `components/StarCard.tsx` ("Don't let this repo end up in a
graveyard." -> "Don't let this repo join the graveyard."). `components/**` is a path of Frontend's
`shared-ui` domain (required, medium tier). If an earlier M1 was merged, the script changes the
headline back instead, so it can always be re-run.

Look for:

- [ ] Medium tier.
- [ ] Frontend required by path (`shared-ui`), and Frontend requested.
- [ ] No Security.
- [ ] No defects, and no "Second person" row: one approval is enough.

The design rows (`visual-design`, `demo-design`) may show too; they are advisory and don't block.

Who must act: a member of the `frontend` GitHub team other than the author approves once:
Silas (silasjmatson). Then the check turns green and Triforce merges M1 (see the warning above).

## HIGH

### D1: `d1-share-target.sh`, then `d1-fix.sh` (steps `d1-open`, `d1-fix`, `approve`)

Adds a `share_target` parameter in `lib/analytics.ts` with one small bug: copy-link shares are
recorded as `download_image` (ShareBar's `data-track-method` calls them `copy_link`).
`lib/analytics.ts` is a path of `data-privacy-egress` (Security, required, high tier).

Run `d1-share-target.sh`, and look for:

- [ ] Security required by path, high tier.
- [ ] The check is in progress ("Preparing your review") until the AI reviewers finish.
- [ ] Then "Waiting on @author", with the defect as an inline thread and "1 defect outstanding" in the author comment.
- [ ] Nobody else is notified.

Then run `d1-fix.sh` (pushes the fix to the same branch). While Triforce re-evaluates, show A2. Then
look for:

- [ ] The defect thread is resolved with "Fixed in <short sha>".
- [ ] One Security role comment.
- [ ] A decision thread from the privacy lens.
- [ ] Two people requested, and the second-person row.

Whether the AI reviewers raise anything else (for example, the privacy lens's point as a defect
rather than a decision, or that `trackShare` runs alongside ShareBar's existing `share` event) is
model judgement. A second defect thread means the planted code needs another look, not that
Triforce miscounted. The privacy-lens decision check may not appear when nothing is left to decide.

Then (step `approve`) look for:

- [ ] A Security member approved: the Security row shows "Approved by".
- [ ] Optional: a second, different person approves, and the gate turns green. This merges D1.

Who must act: Silas approves as Security. A second approval (any other eligible person, for example
Uliana) is optional; skip it in rehearsal.

### A2: `a2-share-username.sh` (step `a2`)

Adds `data-track-username={login}` to the X share button in `components/ShareBar.tsx`, so each share
sends the viewer's username to analytics. No comment says so. By path, `components/**` makes it
Frontend's `shared-ui` (medium). `components/ShareBar.tsx` is not one of the floor paths of
`data-privacy-egress` (Security's paths for it are `lib/github.ts`, `lib/digs.ts`, `lib/analytics.ts`,
`lib/site.ts`, `components/Analytics.tsx`, `app/api/dig/**`), so only the classifier can add Security
and raise it to high.

Look for:

- [ ] By path alone it is medium (`shared-ui`, Frontend).
- [ ] The classifier adds `data-privacy-egress`, with a `file:line` reason (not a path match).
- [ ] High tier.
- [ ] An IE decision thread from the privacy lens.
- [ ] If a defect is open: "Waiting on @author" and nobody asked yet. Otherwise: two people
      requested, and the second-person row.

Who must act: nobody in the demo (it is shown, not approved).

## Not in the live demo

These still run by name (`run-demo.sh run d2-open` and so on) and are not reset by default.

### D2: `d2-data-track.sh <prompter-login>`, then `d2-push.sh` (steps `d2-open`, `d2-push`)

Pass the GitHub login of the person who should count as the prompter, or set `DEMO_PROMPTER`. The
script commits with `Co-Authored-By: Claude <noreply@anthropic.com>` and `Prompted-by: @<login>` as
if a bot opened it, and adds `data-track-*` attributes to the heading in `app/page.tsx`. The commit is
made with your own git identity, so the PR author is you: to see it fully as a bot PR, run the script
from the bot account's checkout. Reset it with `reset-all.sh --only d2 --prompter <login>`.

Note: "Waiting on @prompter" and the prompter ping need a Bot-authored PR with a defect, which this
script does not produce. The D2 tag-in part (the checks below other than the prompter one) still demos.
The prompter behaviour is proven by tests (`packages/worker/test/review/feedback.test.ts`, S2.9, in
aitriforce-cloud).

Look for:

- [ ] No Security path matches (`app/page.tsx` is not one).
- [ ] Security is added by the classifier or tagged in by its AI reviewer, with a `path:line` reason.
- [ ] "Waiting on" names the prompter, who is pinged.

Then run `d2-push.sh` (removes the `data-track-*` lines) and look for:

- [ ] Security is still on the PR after the line is gone.

Who must act: the prompter account (to see the ping); a Security member to approve.

### D3: `d3-request-changes.md` (manual; steps `d3-request`, `d3-push`)

A Security member requests changes on the D1 PR. See the file for steps. Look for:

- [ ] "Waiting on @author", with the review quoted under "Reviewers asked you to".
- [ ] The author's next push re-requests that reviewer.

Who must act: the Security reviewer, then the author.

## Known limit

CI runs on this repo (GitHub-hosted), so D1's CI wait and A1's auto-merge on green CI can be shown.
