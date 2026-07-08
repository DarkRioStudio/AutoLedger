CREATE TABLE IF NOT EXISTS autoledger_analytics_events (
  id TEXT PRIMARY KEY,
  app_id TEXT NOT NULL,
  event_name TEXT NOT NULL,
  event_id TEXT,
  app_version TEXT,
  build_number TEXT,
  os_major TEXT,
  device_class TEXT,
  payload_json TEXT NOT NULL,
  received_at TEXT NOT NULL,
  schema_version INTEGER NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_autoledger_analytics_events_time
ON autoledger_analytics_events(received_at DESC);

CREATE INDEX IF NOT EXISTS idx_autoledger_analytics_events_name_time
ON autoledger_analytics_events(event_name, received_at DESC);

CREATE INDEX IF NOT EXISTS idx_autoledger_analytics_events_version_time
ON autoledger_analytics_events(app_version, build_number, received_at DESC);
