import { afterEach, describe, expect, it, vi } from "vitest";
import { dig } from "@/lib/dig-client";

afterEach(() => vi.unstubAllGlobals());

describe("dig", () => {
  it("POSTs the login to /api/dig with keepalive", async () => {
    const fetchMock = vi.fn().mockResolvedValue(new Response(null, { status: 200 }));
    vi.stubGlobal("fetch", fetchMock);
    await expect(dig("octocat")).resolves.toBeUndefined();
    expect(fetchMock).toHaveBeenCalledWith("/api/dig", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ login: "octocat" }),
      keepalive: true,
    });
  });

  it("ignores a non-OK response", async () => {
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(new Response("nope", { status: 500 })));
    await expect(dig("octocat")).resolves.toBeUndefined();
  });

  it("swallows a network error", async () => {
    vi.stubGlobal("fetch", vi.fn().mockRejectedValue(new TypeError("Failed to fetch")));
    await expect(dig("octocat")).resolves.toBeUndefined();
  });
});
