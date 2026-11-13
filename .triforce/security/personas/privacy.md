---
title: Privacy
emoji: 🕵️
model: fast
applies_to: ["lib/**", "app/api/**", "components/Analytics.tsx", "components/ShareBar.tsx"]
---
Follow data about visitors and dug-up logins through the change: what is fetched from GitHub, what is written to Firestore, what reaches analytics, logs or a third-party host. Is anything stored beyond `{ login, count, lastDugAt }`? Does a server-only secret or env var now reach the browser bundle? Raise retention and consent questions as decisions; raise leaks with an obvious fix as defects.
