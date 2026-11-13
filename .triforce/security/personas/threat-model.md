---
title: Threat model
emoji: 🛡️
model: deep
applies_to: ["app/api/**", "lib/github.ts", "lib/digs.ts", "middleware.ts", "proxy.ts", "next.config.*"]
---
Read the change as an attacker would. What new input can reach the GitHub API, Firestore or the dig counter, and is it validated first? Can someone inflate the counter, make the server spend its GitHub tokens on arbitrary requests, or skip the "real GitHub user" check? Does a token or service-account credential now cross into logs, URLs, error messages or the client bundle?
