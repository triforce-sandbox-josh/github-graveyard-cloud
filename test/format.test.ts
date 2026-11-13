import { describe, expect, it } from "vitest";
import { lifespanLabel, monthYear, year } from "@/lib/format";

describe("year", () => {
  it("reads the UTC year", () => {
    expect(year("2022-06-15T12:00:00Z")).toBe(2022);
  });

  it("does not shift across the UTC new year", () => {
    expect(year("2023-01-01T00:00:00Z")).toBe(2023);
    expect(year("2022-12-31T23:59:59Z")).toBe(2022);
  });
});

describe("monthYear", () => {
  it("formats as short month and year in UTC", () => {
    expect(monthYear("2022-03-14T00:00:00Z")).toBe("Mar 2022");
  });

  it("uses UTC, not the local timezone, at a month boundary", () => {
    expect(monthYear("2024-02-01T00:30:00Z")).toBe("Feb 2024");
  });
});

describe("lifespanLabel", () => {
  it("labels under a day", () => {
    expect(lifespanLabel(0)).toBe("<1 day");
  });

  it("labels exactly one day in the singular", () => {
    expect(lifespanLabel(1)).toBe("1 day");
  });

  it("uses days below 60", () => {
    expect(lifespanLabel(2)).toBe("2 days");
    expect(lifespanLabel(59)).toBe("59 days");
  });

  it("switches to rounded months from 60 days", () => {
    expect(lifespanLabel(60)).toBe("2 months");
    expect(lifespanLabel(406)).toBe("14 months");
    expect(lifespanLabel(729)).toBe("24 months");
  });

  it("switches to years from 730 days and drops a trailing .0", () => {
    expect(lifespanLabel(730)).toBe("2 years");
    expect(lifespanLabel(1000)).toBe("2.7 years");
  });
});
