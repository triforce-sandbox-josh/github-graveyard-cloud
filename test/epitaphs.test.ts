import { describe, expect, it } from "vitest";
import { diagnose, graveyardTitle } from "@/lib/epitaphs";

type Corpse = Parameters<typeof diagnose>[0];

const corpse = (over: Partial<Corpse> = {}): Corpse => ({
  name: "some-project",
  description: null,
  language: null,
  stars: 0,
  size: 100,
  openIssues: 0,
  archived: false,
  topics: [],
  lifespanDays: 100,
  bornMonth: 5,
  ...over,
});

describe("diagnose", () => {
  it("is deterministic for a fixed input", () => {
    const c = corpse({ name: "todo-app-v3", language: "TypeScript" });
    expect(diagnose(c)).toEqual(diagnose(c));
    expect(diagnose(c, new Set())).toEqual(diagnose(c, new Set()));
  });

  it("returns a well-formed diagnosis", () => {
    const d = diagnose(corpse());
    expect(d.cause).toBeTruthy();
    expect(d.epitaph).toBeTruthy();
    expect(["round", "cross", "gothic", "slab"]).toContain(d.shape);
    expect(d.tilt).toBeGreaterThanOrEqual(-3);
    expect(d.tilt).toBeLessThanOrEqual(3);
  });

  it("picks a name-based joke before trait jokes", () => {
    const d = diagnose(corpse({ name: "my-todo-list", archived: true, language: "Rust" }));
    expect(["Too many todos. Zero dones.", "Item #1 on its own list: finish this app", "Ironically never checked off"]).toContain(d.cause);
  });

  it("matches the repo description too", () => {
    const d = diagnose(corpse({ name: "thing", description: "A bitcoin blockchain toy" }));
    expect(["Rug-pulled by the bear market", "Gas fees exceeded will to live", "Went to zero"]).toContain(d.cause);
  });

  it("calls an empty repo stillborn", () => {
    const d = diagnose(corpse({ name: "empty", size: 0 }));
    expect(["Stillborn. Not a single commit drew breath.", "Never made it past git init"]).toContain(d.cause);
  });

  it("falls back to a non-empty cause when no rule matches", () => {
    expect(diagnose(corpse({ name: "quiet-box", archived: true })).cause.length).toBeGreaterThan(0);
  });

  it("does not reuse a cause within one graveyard while alternatives remain", () => {
    const used = new Set<string>();
    const names = Array.from({ length: 5 }, (_, i) => `todo-app-${i}`);
    const causes = names.map((name) => diagnose(corpse({ name, description: "todo" }), used).cause);
    // The todo rule has three causes, so the first three must all differ.
    expect(new Set(causes.slice(0, 3)).size).toBe(3);
    for (const c of causes) expect(used.has(c)).toBe(true);
  });

  it("still returns a cause when every option is used", () => {
    const used = new Set<string>();
    for (let i = 0; i < 60; i++) expect(diagnose(corpse({ name: "zzz" }), used).cause).toBeTruthy();
  });
});

describe("graveyardTitle", () => {
  it("empty lot when the user has no repos", () => {
    expect(graveyardTitle(0, 0, 0).rank).toBe("The Empty Lot");
  });

  it("suspiciously clean when nothing is dead", () => {
    expect(graveyardTitle(0, 12, 0).rank).toBe("Suspiciously Clean");
  });

  it("mass grave operator from 50 dead", () => {
    expect(graveyardTitle(50, 200, 400).rank).toBe("Mass Grave Operator");
    expect(graveyardTitle(49, 200, 400).rank).not.toBe("Mass Grave Operator");
  });

  it("grim reaper when at least 85% are dead", () => {
    expect(graveyardTitle(17, 20, 400).rank).toBe("Grim Reaper of Repos");
    expect(graveyardTitle(16, 20, 400).rank).not.toBe("Grim Reaper of Repos");
  });

  it("weekend warrior when the average lifespan is a week or less", () => {
    expect(graveyardTitle(6, 20, 7).rank).toBe("Weekend Warrior");
    expect(graveyardTitle(6, 20, 8).rank).not.toBe("Weekend Warrior");
  });

  it("serial abandoner, graveyard shift manager and casual necromancer", () => {
    expect(graveyardTitle(20, 100, 300).rank).toBe("Serial Abandoner");
    expect(graveyardTitle(6, 10, 300).rank).toBe("Graveyard Shift Manager");
    expect(graveyardTitle(5, 20, 300).rank).toBe("Casual Necromancer");
  });

  it("defaults to mostly alive for a few graves", () => {
    expect(graveyardTitle(2, 20, 300)).toEqual({ rank: "Mostly Alive", blurb: "A tidy little plot. Respect." });
  });

  it("always gives a blurb", () => {
    for (const [d, t, a] of [[0, 0, 0], [0, 1, 0], [60, 70, 5], [3, 4, 100], [1, 30, 900]] as const) {
      expect(graveyardTitle(d, t, a).blurb.length).toBeGreaterThan(0);
    }
  });
});
