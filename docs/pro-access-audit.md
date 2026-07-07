# Pro Access Audit

Date: 2026-07-07

This audit records the current Pro entitlement boundary after the source-available and Worker token-claim hardening pass. The goal is to keep local Free / Pro UX intact while making clear that server-cost features require server-side verification.

## App Side

### `AutoLedger/AutoLedger/Domain/Services/ProEntitlementManager.swift`

- Owns StoreKit product IDs `top.darkrio326.AutoLedger.pro.monthly` and `top.darkrio326.AutoLedger.pro.yearly`.
- `isProActive` is still derived from verified StoreKit current entitlements or the DEBUG-only `autoLedgerProDevelopmentOverride`.
- `canUse(_:)` remains a synchronous UI compatibility gate. It is not a security boundary and now refuses non-local boundaries such as `cloudFolioInbox`.
- `resolveAccess(_:)` is the richer async entry point. It distinguishes free features, local Pro purchase requirements, planned features, server verification requirements, and server verification failures.
- `cloudFolioInbox` now routes through server verification. The App sends the current StoreKit signed transaction JWS to the Worker verifier; local StoreKit state alone is not enough to claim a production cloud inbox token.

Risk: public source can be forked and local client checks can be modified. This only gates UI and local user experience; it must not authorize server-cost functions.

### `AutoLedger/AutoLedgerCore/Sources/AutoLedgerCore/Models/ProAccessPolicy.swift`

- Defines `AutoLedgerCapability`, `ProAccessTier`, and `AutoLedgerProAccessPolicy`.
- Free/core capabilities remain free: `manualTransactionEntry`, `singleReceiptScan`, `manualHotelFolioImport`, `hotelStayArchiveAccess`, basic subscription/report/widget/export/backup, history edit/delete, and support donation.
- Current P0 Pro capabilities are `localEmailFolioScan`, `batchCandidateImport`, `advancedDeduplication`, `merchantNormalizationSuggestions`, and `cloudFolioInbox`.
- v1.7.0 merchant normalization keeps single-record merchant edits, basic merchant aliases, category learning, and already accepted rules in the free/core layer. Pro gates full-ledger analysis, merchant normalization suggestions, batch preview/application, low-confidence review queues, and optional future Worker-assisted suggestion generation.
- New `ProSecurityBoundary` classifies capabilities as `localUIGate`, `serverVerified`, or `planned`.
- `cloudFolioInbox` is `serverVerified`; local email scan, batch import, advanced deduplication, and merchant normalization suggestions are still `localUIGate`.

Risk: policy is useful for consistency and regression tests, but it is still client code in a public repo.

### `AutoLedger/AutoLedger/Features/Settings/SupportAutoLedgerView.swift`

- Shows current Pro subscription status, products, restore purchases, and manage subscription entry points.
- Reads `isProActive` for subscription presentation and button disabling.
- This is correct as purchase UI state, not as server authorization.

### `isProActive` Callers

- `ProEntitlementManager.restorePurchases()` uses it to select success/empty restore messaging.
- `SupportAutoLedgerView` uses it for status display and purchase button disabling.
- `LocalEmailFolioImportAllowanceState` receives local Pro status for local monthly import allowance logic.

Risk: fine for UI, purchase messaging, and local allowance. Not sufficient for Worker token claim, APNs, future unified model parsing, hosted quotas, or any server-cost path.

### `canUse(_:)` Callers

- `HotelFolioInboxImportView` no longer relies on `canUse(.cloudFolioInbox)` for cloud token claim. It uses `resolveAccess(_:)`, shows manual PDF / local email fallback when verification is unavailable, and sends the signed transaction JWS when claiming a token.
- `HotelFolioEmailImportView` uses `canUse(.localEmailFolioScan)` for the local email scan/allowance experience.
- `IPadBatchImportWorkspaceView` uses `canUse(.batchCandidateImport)` to gate new multi-file batch import, drag-and-drop import, Mac import-file commands, retry, and recognition execution; existing candidates and queue review remain reachable.
- `IPadCleaningPreviewWorkspaceView` uses `canUse(.advancedDeduplication)` for local data cleaning and deduplication UI.

Risk: local UI gates can be bypassed in forks. The impact for local features is limited to local experience; server-cost features must not depend on this.

### `requiresPro(_:)` Callers

- No current App call sites were found outside `ProEntitlementManager`.

### Direct `AutoLedgerCapability` Usage

- Policy definitions and regression references use all capabilities.
- Version docs and iteration logs reference `cloudFolioInbox`, P0 Pro gates, and planned v1.7.0 merchant normalization / data-cleaning gates.
- UI call sites currently use `localEmailFolioScan`, `batchCandidateImport`, `advancedDeduplication`, `merchantNormalizationSuggestions`, and `cloudFolioInbox`.

## Worker Side

### `tools/worker/hotel-folio-inbox/README.md`

- Documents that App-side Pro state is UI only.
- Documents `ALLOW_UNVERIFIED_TOKEN_CLAIM` as dev/staging-only.
- Documents that production token claim needs server-side entitlement / receipt verification.
- Documents `pro_inbox_tokens.pro_expires_at` as the service-side expiry gate.
- Documents APNs secrets as `wrangler secret` values that must not be committed.

### `tools/worker/hotel-folio-inbox/src/index.ts`

- `POST /v1/pro-entitlements/verify` validates a StoreKit signed transaction JWS through App Store Server API and returns allowed / denied plus expiry.
- `POST /v1/cloud-hotel-folio-token` is no longer open by default.
- If `ALLOW_UNVERIFIED_TOKEN_CLAIM` is missing or false, token claim requires a StoreKit signed transaction JWS, validates it through App Store Server API, and returns `403` with `error: "server_entitlement_required"` when validation fails.
- Dev/staging bootstrap claims insert `pro_expires_at` with a short TTL capped at 30 days.
- Production claims set `pro_expires_at` from the verified subscription expiry and bind `user_id` to a SHA-256 hash of the App Store original transaction ID.
- `loadActiveToken` continues to require `status = active` and rejects expired `pro_expires_at`, which is the right direction for server-side gating.
- The current production authorization path is App Store Server API transaction verification. A separate short-lived signed entitlement token can be added later, but is not accepted by the current token claim route.

Risk: App Store Server API secrets must be configured in Cloudflare before production token claim works. Production must keep unauthenticated bootstrap disabled.

### `tools/worker/hotel-folio-inbox/migrations/0001_hotel_folio_inbox.sql`

- `pro_inbox_tokens` includes `status` and `pro_expires_at`.
- Indexing supports status/expiry checks.
- The schema can support server-side subscription expiry enforcement without migration.

Risk: the column is nullable for compatibility, so production provisioning must set meaningful values.

### `tools/worker/hotel-folio-inbox/wrangler.jsonc`

- Dev and staging explicitly enable `ALLOW_UNVERIFIED_TOKEN_CLAIM=true` with `UNVERIFIED_TOKEN_TTL_DAYS=7`.
- Production omits `ALLOW_UNVERIFIED_TOKEN_CLAIM`, so default behavior is disabled.
- Production declares non-secret `APP_STORE_BUNDLE_ID` and `APP_STORE_SERVER_ENVIRONMENT=production`; App Store Connect issuer, key ID, and private key must be configured as Worker secrets.
- APNs runtime secrets are referenced by name only and should be configured with `wrangler secret`.

## Security Boundary Summary

- Client StoreKit state is appropriate for local UI gates and purchase presentation.
- Public source means client gates can be forked and changed.
- Bypassing local gates affects local user experience only.
- Cloud inbox, Worker APIs, APNs, future hosted model parsing, quotas, and other server-cost features must rely on server-side entitlement verification and service-side token state.
