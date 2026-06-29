CREATE TABLE IF NOT EXISTS pro_inbox_tokens (
    token_hash TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    inbox_email TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'active',
    pro_expires_at TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_pro_inbox_tokens_status
    ON pro_inbox_tokens(status, pro_expires_at);

CREATE TABLE IF NOT EXISTS cloud_hotel_folio_candidates (
    id TEXT PRIMARY KEY,
    token_hash TEXT NOT NULL,
    user_id TEXT NOT NULL,
    source_email_subject TEXT,
    source_email_from TEXT,
    message_id_hash TEXT,
    attachment_file_name TEXT NOT NULL,
    attachment_hash TEXT NOT NULL,
    object_storage_key TEXT NOT NULL UNIQUE,
    object_byte_size INTEGER NOT NULL,
    mime_type TEXT NOT NULL,
    status TEXT NOT NULL,
    received_at TEXT NOT NULL,
    expires_at TEXT NOT NULL,
    downloaded_at TEXT,
    converted_at TEXT,
    deleted_at TEXT,
    failure_reason TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    UNIQUE(token_hash, attachment_hash)
);

CREATE INDEX IF NOT EXISTS idx_cloud_hotel_folio_candidates_token_status
    ON cloud_hotel_folio_candidates(token_hash, status, received_at DESC);

CREATE INDEX IF NOT EXISTS idx_cloud_hotel_folio_candidates_expires
    ON cloud_hotel_folio_candidates(status, expires_at);

CREATE TABLE IF NOT EXISTS apns_devices (
    id TEXT PRIMARY KEY,
    token_hash TEXT NOT NULL,
    user_id TEXT NOT NULL,
    device_token TEXT NOT NULL,
    device_token_hash TEXT NOT NULL,
    platform TEXT NOT NULL,
    environment TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'active',
    last_seen_at TEXT NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    UNIQUE(token_hash, device_token_hash)
);

CREATE INDEX IF NOT EXISTS idx_apns_devices_user_status
    ON apns_devices(user_id, status, environment);

CREATE TABLE IF NOT EXISTS notification_outbox (
    id TEXT PRIMARY KEY,
    token_hash TEXT NOT NULL,
    user_id TEXT NOT NULL,
    candidate_id TEXT NOT NULL,
    kind TEXT NOT NULL,
    status TEXT NOT NULL,
    payload_json TEXT NOT NULL,
    delivered_at TEXT,
    failure_reason TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_notification_outbox_status
    ON notification_outbox(status, created_at);
