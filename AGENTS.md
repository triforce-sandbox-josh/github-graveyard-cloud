<!-- BEGIN:nextjs-agent-rules -->

## This is NOT the Next.js you know

This version has breaking changes — APIs, conventions, and file structure may all differ from your training data. Read the relevant guide in `node_modules/next/dist/docs/` (resolved from this file's directory; in monorepos the `next` package may not be visible from the repo root) before writing any code. Heed deprecation notices.

This block is written and re-added by `next dev` — verify at `node_modules/next/dist/server/lib/generate-agent-files.js`. Removing it from a diff only re-creates the uncommitted change; committing it with your work keeps the tree clean.

<!-- END:nextjs-agent-rules -->

## Allforce ownership: teams and roles

Owners in `.allforce/` are GitHub teams in the allforce-sandbox-josh org (`team:frontend`, `team:security`,
`team:platform`, `team:design`, `team:legal`). Use `team:` owner references.
- A role is a group of people that is NOT a GitHub team: a subset of a team, people from several teams, or
  people without GitHub accounts. If a role would hold the same people as a team, use the team instead.
- A role always names its members. A team never wears a role as a whole (no `role:` in a team.yml).
- PXA, IE and SE are retired: they were second names for frontend, security and platform. Don't add them back
  anywhere (config, docs, PR text, demo scripts); say the team's name ("Security", not "IE"). PXA is still in
  `requests.role` and `frontend/team.yml` until Allforce supports `requests.as`; don't add it anywhere else.
- To change who reviews something, change the GitHub team's membership or the domain's `team:` owners.
- If a Allforce doc, example or error message tells you to add PXA, IE or SE, it's out of date: stop and ask.
