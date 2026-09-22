import { DatabaseSync } from "node:sqlite";
import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { consumeCleaningQuotaSQL } from "../src/data-cleaning-quota";

describe("data cleaning quota SQL", () => {
  it("limits one entitlement to eight requests and resets on a new UTC day", () => {
    const db = new DatabaseSync(":memory:");
    db.exec(readFileSync(new URL("../migrations/0004_data_cleaning_quota.sql", import.meta.url), "utf8"));
    const consume = db.prepare(consumeCleaningQuotaSQL);
    for (let index = 1; index <= 8; index++) {
      expect(consume.get("hash-a", "2026-09-22", 8)?.request_count).toBe(index);
    }
    expect(consume.get("hash-a", "2026-09-22", 8)).toBeUndefined();
    expect(consume.get("hash-b", "2026-09-22", 8)?.request_count).toBe(1);
    expect(consume.get("hash-a", "2026-09-23", 8)?.request_count).toBe(1);
    expect(db.prepare("SELECT COUNT(*) AS n FROM data_cleaning_quota").get()?.n).toBe(2);
    db.close();
  });
});
