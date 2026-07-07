# AutoLedger Hotel Folio Inbox Worker

This Worker implements the hotel folio inbox path for AutoLedger Pro automation.

This inbox is intentionally not an IMAP scanner. Users forward hotel folio emails, set a forwarding rule, or use a dedicated AutoLedger address such as:

```text
folio+<token>@getautoledger.app
```

The Worker only handles messages delivered to that dedicated address. It does not log in to user mailboxes, does not store QQ/IMAP authorization codes, and does not create ledger records.

## Flow

```text
Cloudflare Email Routing
-> email() handler
-> parse MIME with postal-mime
-> extract PDF attachments
-> SHA-256 attachment hash
-> store PDF in R2
-> store redacted candidate metadata in D1
-> enqueue APNs/outbox notification event
-> Queue consumer sends a privacy-safe APNs deep link
-> App downloads PDF
-> App PDFKit text extraction + HotelFolioParsePipeline
-> User review
-> HotelStayRecord + Transaction
```

## Inbox Token Claim / Pro Gate

The service-side gate is the `pro_inbox_tokens` D1 table:

- `token_hash`: SHA-256 of the normalized inbox token.
- `status`: must be `active`.
- `pro_expires_at`: required for bootstrap/dev claims and recommended for all production tokens. Expired values reject new inbound email and API requests.

The App-side gate should use `AutoLedgerCapability.cloudFolioInbox` for UI state only. Local Pro state is not Worker authorization. Production token claim must be backed by server-side entitlement / receipt verification.

The App can claim or rotate a dedicated inbox address through the Worker:

```http
POST /v1/cloud-hotel-folio-token
Content-Type: application/json

{
  "clientID": "<locally-stored-client-id>",
  "platform": "ios",
  "environment": "production"
}
```

The Worker returns the raw token once, stores only its SHA-256 hash in D1, and marks any previous active token for the same resolved service user as `rotated`. Development bootstrap users resolve to `client:<clientID>`; production App Store users resolve to `appstore:<sha256-original-transaction-id>`:

```json
{
  "token": "<raw-token>",
  "inboxEmail": "folio+<raw-token>@getautoledger.app",
  "tokenHash": "<sha256-normalized-token>",
  "userID": "appstore:<sha256-original-transaction-id>",
  "status": "active",
  "proExpiresAt": "<verified-subscription-expiry>"
}
```

Unauthenticated bootstrap claim is limited to dev/staging and must be explicitly enabled with `ALLOW_UNVERIFIED_TOKEN_CLAIM=true`. Production does not enable this variable by default. When disabled, `POST /v1/cloud-hotel-folio-token` requires App Store subscription verification; failed verification returns `403` with `error: "server_entitlement_required"` and does not create a token.

Bootstrap tokens receive a short `pro_expires_at` value controlled by `UNVERIFIED_TOKEN_TTL_DAYS` and capped at 30 days. Production token claim uses App Store Server API verification before inserting `pro_inbox_tokens`.

Current production P0 uses StoreKit's signed transaction JWS from the App. The Worker decodes the transaction ID, calls App Store Server API `GET /inApps/v1/transactions/{transactionId}`, then validates bundle ID, Pro product ID, revocation, and expiration before creating an inbox token.

Future entitlement backends can add a separate short-lived signed credential flow if needed. The current Worker does not accept a signed entitlement header for token claim; production authorization is the App Store Server API transaction check.

## APNs Device Registration

The App registers the current APNs device token after the user saves a valid inbox token. Device registration uses the same inbox token auth as candidate APIs:

```http
POST /v1/cloud-hotel-folio-devices
Authorization: Bearer <token>
Content-Type: application/json

{
  "deviceToken": "<apns-device-token-hex>",
  "platform": "ios",
  "environment": "production"
}
```

The Worker stores the token against the service-side `user_id` resolved from `pro_inbox_tokens`. Notification payloads are intentionally generic and include only:

- APNs `aps.alert` with a private message.
- `autoledgerDeepLink` such as `autoledger://hotel-cloud-candidate/<candidate-id>`.
- Candidate ID.

They do not include hotel name, amount, order number, attachment filename, or inbox token hash.

## App Store Server Notifications

`POST /v1/app-store/notifications` is reserved for App Store Server Notifications V2. The endpoint accepts Apple's `signedPayload`, decodes the notification contract, writes an idempotent event row keyed by `notificationUUID`, updates `app_store_entitlements`, and adjusts active cloud-inbox tokens for the matching `appstore:<sha256-original-transaction-id>` service user.

The daily scheduled task also runs a Notification History compensation pass. When App Store Server API secrets are configured, it calls `POST /inApps/v1/notifications/history` with `onlyFailures=true`, a default 72-hour lookback window, and paginated results. Each recovered `signedPayload` is processed through the same verification, idempotency, entitlement, and token lifecycle path as the direct webhook endpoint.

Stored notification data is intentionally minimal:

- notification UUID, type, subtype, version, environment, bundle id, product id, transaction id
- SHA-256 hash of the original transaction id
- derived service user id
- entitlement status, expiry, processing status, failure reason
- SHA-256 hash of the raw signed payload

The Worker does not store the raw `signedPayload`, raw original transaction id, user email, hotel folio contents, PDF files, hotel names, or ledger data in the App Store notification tables.

Production must keep `ALLOW_UNVERIFIED_APP_STORE_NOTIFICATIONS` unset. Configure `APP_STORE_NOTIFICATION_ROOT_CERT_PEM` with the trusted Apple root certificate before pointing App Store Connect at this endpoint. The current development/staging flag exists only to test the database contract before App Store Connect is configured with the notification URL.

Optional non-secret tuning vars:

- `APP_STORE_NOTIFICATION_HISTORY_LOOKBACK_HOURS`: defaults to `72`, clamped to `1...168`.
- `APP_STORE_NOTIFICATION_HISTORY_MAX_PAGES`: defaults to `5`, clamped to `1...20`.

## Setup

Install dependencies:

```bash
npm install
```

Generate Worker binding types after real bindings are configured:

```bash
npm run types
```

Create the D1 schema:

```bash
npx wrangler d1 execute autoledger-hotel-folio-inbox-dev \
  --file migrations/0001_hotel_folio_inbox.sql

npx wrangler d1 execute autoledger-hotel-folio-inbox-dev \
  --file migrations/0002_app_store_notifications.sql
```

Use `POST /v1/cloud-hotel-folio-token` from the App or curl to provision a development or staging token only when `ALLOW_UNVERIFIED_TOKEN_CLAIM=true`. Manual `pro_inbox_tokens` inserts are only needed for direct database debugging.

Create queues and object/database resources in Cloudflare before deployment, then replace placeholder D1 IDs in `wrangler.jsonc`:

```bash
npx wrangler r2 bucket create autoledger-hotel-folio-candidates
npx wrangler d1 create autoledger-hotel-folio-inbox
npx wrangler queues create autoledger-hotel-folio-apns
```

Configure APNs secrets; do not commit these values:

```bash
npx wrangler secret put APNS_KEY_ID
npx wrangler secret put APNS_TEAM_ID
npx wrangler secret put APNS_PRIVATE_KEY
```

`APNS_TOPIC` is a non-secret Worker var and defaults to `top.darkrio326.AutoLedger`.

Configure App Store Server API secrets; do not commit these values:

```bash
npx wrangler secret put APP_STORE_CONNECT_ISSUER_ID --env production
npx wrangler secret put APP_STORE_CONNECT_KEY_ID --env production
npx wrangler secret put APP_STORE_CONNECT_PRIVATE_KEY --env production
npx wrangler secret put APP_STORE_NOTIFICATION_ROOT_CERT_PEM --env production
```

`APP_STORE_BUNDLE_ID` and `APP_STORE_SERVER_ENVIRONMENT` are non-secret Worker vars. Production uses `APP_STORE_SERVER_ENVIRONMENT=production`; dev/staging use `sandbox`. `APP_STORE_NOTIFICATION_ROOT_CERT_PEM` is a public trust anchor rather than a credential, but it is stored as a Worker secret to keep long PEM material out of `wrangler.jsonc`.

For dev/staging bootstrap only:

```jsonc
"ALLOW_UNVERIFIED_TOKEN_CLAIM": "true",
"ALLOW_UNVERIFIED_APP_STORE_NOTIFICATIONS": "true",
"UNVERIFIED_TOKEN_TTL_DAYS": "7"
```

Do not enable unauthenticated token claim or unsigned App Store notification decoding in production. Production uses App Store Server API verification for token claim and must only receive App Store notification payloads after `APP_STORE_NOTIFICATION_ROOT_CERT_PEM` is configured and certificate-chain verification passes.

## Current Cloudflare Deployment

Deployed on 2026-06-29 under the `darkrio326` Cloudflare account.

Workers:

- `autoledger-hotel-folio-inbox`
- `autoledger-hotel-folio-inbox-staging`
- `autoledger-hotel-folio-inbox-production`

Domains:

- `https://folio.getautoledger.app`
- `https://staging-folio.getautoledger.app`

Resources:

- R2: `autoledger-hotel-folio-candidates-dev`, `autoledger-hotel-folio-candidates-staging`, `autoledger-hotel-folio-candidates`
- D1: `autoledger-hotel-folio-inbox-dev`, `autoledger-hotel-folio-inbox-staging`, `autoledger-hotel-folio-inbox`
- Queue: `autoledger-hotel-folio-apns-dev`, `autoledger-hotel-folio-apns-staging`, `autoledger-hotel-folio-apns`

Staging App Store Server Notifications:

- `autoledger-hotel-folio-inbox-staging` has `APP_STORE_NOTIFICATION_ROOT_CERT_PEM` configured with Apple Root CA - G3 as of 2026-07-02.
- With the root certificate configured, staging verifies `signedPayload` and no longer accepts unsigned fake notifications for positive smoke tests. Use a real App Store Connect sandbox notification for end-to-end validation.

Email Routing:

- `getautoledger.app` Email Routing is enabled and ready.
- Cloudflare Email Routing subaddressing is enabled.
- `folio@getautoledger.app` routes to `autoledger-hotel-folio-inbox-production` and accepts `folio+<token>@getautoledger.app`.
- Catch-all remains disabled and drops unmatched mail.
- If a forwarded message has no PDF attachment, the Worker stores a short-lived `email-body-folio.pdf` generated from the message body so the App can use the same PDFKit review pipeline.

Still required before production cloud inbox token claim and push notifications work:

- Configure App Store Server API secrets for `POST /v1/cloud-hotel-folio-token` production verification.
- Configure `APP_STORE_NOTIFICATION_ROOT_CERT_PEM` before enabling App Store Server Notifications in App Store Connect.
- Configure `APNS_KEY_ID`, `APNS_TEAM_ID`, and `APNS_PRIVATE_KEY` Worker secrets.
- Provision active `pro_inbox_tokens` rows only after entitlement verification, with `status = active` and a meaningful `pro_expires_at`.

## API

Token claim is server-entitlement gated in production. Dev/staging bootstrap claim is only available when `ALLOW_UNVERIFIED_TOKEN_CLAIM=true`. Candidate listing, PDF download, status update, and APNs device registration still require the raw inbox token in `Authorization: Bearer <token>`.

```http
POST /v1/pro-entitlements/verify
POST /v1/app-store/notifications
POST /v1/cloud-hotel-folio-token
GET /v1/cloud-hotel-folio-candidates
GET /v1/cloud-hotel-folio-candidates/{id}/pdf
POST /v1/cloud-hotel-folio-candidates/{id}/status
POST /v1/cloud-hotel-folio-devices
```

Production token claim body:

```json
{
  "clientID": "<locally-stored-client-id>",
  "platform": "ios",
  "environment": "production",
  "signedTransactionInfo": "<StoreKit signed transaction JWS>"
}
```

App Store Server Notification body:

```json
{
  "signedPayload": "<App Store Server Notification V2 signedPayload>"
}
```

Supported status updates:

```json
{ "status": "converted", "deleteCloudPDF": true }
{ "status": "deleted" }
{ "status": "failed", "failureReason": "pdf text extraction failed" }
```

## Validation

```bash
npm run check
```
