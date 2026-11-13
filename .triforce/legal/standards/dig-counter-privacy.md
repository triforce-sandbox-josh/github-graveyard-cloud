# GG-P1 Dig counter privacy (fictional, for the Triforce demo)

The dig counter (`POST /api/dig`, `lib/digs.ts`) counts how often a GitHub login's graveyard is dug up.

- §1 Per login it stores only `{ login, count, lastDugAt }`. Never the visitor's IP address, user agent, referrer, cookies or any identifier of the visitor.
- §2 It only counts logins that GitHub confirms exist; it never stores free text a visitor typed.
- §3 Logs from the dig route never include request headers, tokens or the full error object.
- §4 A login's owner can ask for its record to be deleted; nothing else is derived from it.
