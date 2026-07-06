CREATE TABLE IF NOT EXISTS release_notes (
  app_id TEXT NOT NULL,
  app_version TEXT NOT NULL,
  locale TEXT NOT NULL,
  schema_version INTEGER NOT NULL DEFAULT 1,
  resource_version TEXT NOT NULL,
  current_title TEXT NOT NULL,
  current_body TEXT NOT NULL,
  upcoming_title TEXT NOT NULL,
  upcoming_body TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'published' CHECK (status IN ('draft', 'published', 'archived')),
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (app_id, app_version, locale)
);

CREATE INDEX IF NOT EXISTS idx_release_notes_lookup
  ON release_notes (app_id, app_version, status);

CREATE INDEX IF NOT EXISTS idx_release_notes_status
  ON release_notes (status, updated_at);
