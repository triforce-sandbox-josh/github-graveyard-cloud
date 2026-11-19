// Client-safe: POSTs to /api/dig. Must not import lib/digs or any server-only module.

// Counts the dig (fire-and-forget; keepalive survives the navigation).
// Non-OK responses and network errors are deliberately swallowed.
export function dig(login: string): Promise<void> {
  return fetch("/api/dig", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ login }),
    keepalive: true,
  }).then(
    () => {},
    () => {},
  );
}
