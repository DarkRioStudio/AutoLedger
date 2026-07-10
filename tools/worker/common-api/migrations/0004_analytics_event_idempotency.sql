DELETE FROM autoledger_analytics_events
WHERE event_id IS NOT NULL
  AND rowid NOT IN (
    SELECT MIN(rowid)
    FROM autoledger_analytics_events
    WHERE event_id IS NOT NULL
    GROUP BY app_id, event_id
  );

CREATE UNIQUE INDEX IF NOT EXISTS idx_autoledger_analytics_events_app_event_id
    ON autoledger_analytics_events(app_id, event_id)
    WHERE event_id IS NOT NULL;
