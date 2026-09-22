// Atomic fixed-window quota. Persist only an entitlement hash, UTC day and count.
export const consumeCleaningQuotaSQL = `
INSERT INTO data_cleaning_quota (subject_hash, utc_day, request_count)
VALUES (?, ?, 1)
ON CONFLICT(subject_hash) DO UPDATE SET
  utc_day = excluded.utc_day,
  request_count = CASE WHEN data_cleaning_quota.utc_day = excluded.utc_day
    THEN data_cleaning_quota.request_count + 1 ELSE 1 END
WHERE data_cleaning_quota.utc_day <> excluded.utc_day OR data_cleaning_quota.request_count < ?
RETURNING request_count`;

export async function consumeCleaningQuota(db: D1Database, subjectHash: string, now = Date.now()): Promise<boolean> {
  const day = new Date(now).toISOString().slice(0, 10);
  const result = await db.prepare(consumeCleaningQuotaSQL).bind(subjectHash, day, 8).first<{ request_count: number }>();
  return result !== null;
}
