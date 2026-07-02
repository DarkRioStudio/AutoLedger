CREATE TABLE IF NOT EXISTS app_store_notification_events (
    notification_uuid TEXT PRIMARY KEY,
    environment TEXT NOT NULL,
    bundle_id TEXT,
    app_apple_id TEXT,
    notification_type TEXT NOT NULL,
    subtype TEXT,
    version TEXT,
    signed_date TEXT,
    original_transaction_id_hash TEXT,
    user_id TEXT,
    product_id TEXT,
    transaction_id TEXT,
    transaction_expires_at TEXT,
    entitlement_status TEXT,
    raw_payload_hash TEXT NOT NULL,
    status TEXT NOT NULL,
    failure_reason TEXT,
    received_at TEXT NOT NULL,
    processed_at TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_app_store_notification_events_user
    ON app_store_notification_events(user_id, received_at DESC);

CREATE INDEX IF NOT EXISTS idx_app_store_notification_events_status
    ON app_store_notification_events(status, received_at DESC);

CREATE TABLE IF NOT EXISTS app_store_entitlements (
    user_id TEXT PRIMARY KEY,
    original_transaction_id_hash TEXT NOT NULL UNIQUE,
    environment TEXT NOT NULL,
    bundle_id TEXT,
    product_id TEXT,
    status TEXT NOT NULL,
    expires_at TEXT,
    last_notification_uuid TEXT,
    last_notification_type TEXT,
    last_subtype TEXT,
    last_reason TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_app_store_entitlements_status
    ON app_store_entitlements(status, expires_at);
