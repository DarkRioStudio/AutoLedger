-- Non-destructive: no raw entitlement, merchant, receipt or financial data.
CREATE TABLE IF NOT EXISTS data_cleaning_quota (
  subject_hash TEXT PRIMARY KEY NOT NULL,
  utc_day TEXT NOT NULL,
  request_count INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS data_cleaning_quota_day ON data_cleaning_quota(utc_day);
