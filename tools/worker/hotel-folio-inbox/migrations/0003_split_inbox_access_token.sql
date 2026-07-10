ALTER TABLE pro_inbox_tokens
    ADD COLUMN access_token_hash TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS idx_pro_inbox_tokens_access_token_hash
    ON pro_inbox_tokens(access_token_hash)
    WHERE access_token_hash IS NOT NULL;
