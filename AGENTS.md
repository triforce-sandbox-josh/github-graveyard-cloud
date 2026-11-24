<!-- BEGIN:nextjs-agent-rules -->

## This is NOT the Next.js you know

This version has breaking changes — APIs, conventions, and file structure may all differ from your training data. Read the relevant guide in `node_modules/next/dist/docs/` (resolved from this file's directory; in monorepos the `next` package may not be visible from the repo root) before writing any code. Heed deprecation notices.

This block is written and re-added by `next dev` — verify at `node_modules/next/dist/server/lib/generate-agent-files.js`. Removing it from a diff only re-creates the uncommitted change; committing it with your work keeps the tree clean.

<!-- END:nextjs-agent-rules -->

## Triforce ownership: teams and roles

Owners in `.triforce/` are GitHub teams in the triforce-sandbox-josh org, declared under `teams:` in
`.triforce/config.yml` (`frontend`, `security`, `platform`, `design`, `legal`). Use `team:` owner references.
- Each `.triforce/<team>/` folder belongs to the team it is named for; a `team.yml` has no `team:` or `role:` key.
- `design` also includes `trevor-design` (`teams.design.also`), Trevor's Slack-only identity (`github: false`
  in `people`). `people` entries are identity only (Slack IDs, `github: false`); they never list roles.
- This repo has no roles. A role is a group of people that is NOT a GitHub team: a subset of a team, people from
  several teams, or people without GitHub accounts. If a role would hold the same people as a team, use the team.
  A role always lists its members; a team never wears a role.
- PXA, IE, SE and BG are retired: PXA, IE and SE were second names for frontend, security and platform, and BG
  only gave `trevor-design` a way to own design (now `teams.design.also`). Don't add them back anywhere (config,
  docs, PR text, demo scripts); say the team's name ("Security", not "IE").
- Slack requests act as Frontend: `requests.as: team:frontend`. A change a request makes only to domains Frontend
  owns needs no other team's OK before it is built (Frontend still reviews the PR); any other required domain it
  touches is a stop for that domain's owners, and design's Slack domains get a look. It is a repo setting: whoever
  asks in Slack, the request carries Frontend's authority, whether or not they are on the team.
- To change who reviews something, change the GitHub team's membership, `teams:` in config.yml, or the domain's
  `team:` owners.
- CI rejects the retired roles and the old forms (`people.<name>.roles`, a team file's `role:`, `requests.role`).
- If a Triforce doc, example or error message tells you to add PXA, IE, SE or BG, it's out of date: stop and ask.
