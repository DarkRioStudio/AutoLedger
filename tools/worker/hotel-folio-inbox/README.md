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
- `pro_expires_at`: optional ISO timestamp. Expired values reject new inbound email and API requests.

The App-side gate should use `AutoLedgerCapability.cloudFolioInbox`.

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

The Worker returns the raw token once, stores only its SHA-256 hash in D1, and marks any previous active token for the same `client:<clientID>` user as `rotated`:

```json
{
  "token": "<raw-token>",
  "inboxEmail": "folio+<raw-token>@getautoledger.app",
  "tokenHash": "<sha256-normalized-token>",
  "userID": "client:<clientID>",
  "status": "active"
}
```

Until a subscription backend is connected, this endpoint is the bootstrap provisioning path. The App still gates the UI with Pro entitlement locally; a future service-side subscription check can be added before inserting `pro_inbox_tokens`.

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
```

Use `POST /v1/cloud-hotel-folio-token` from the App or curl to provision a development token. Manual `pro_inbox_tokens` inserts are only needed for direct database debugging.

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

Email Routing:

- `getautoledger.app` Email Routing is enabled and ready.
- `folio@getautoledger.app` routes to `autoledger-hotel-folio-inbox-production`.
- Catch-all remains disabled and drops unmatched mail.

Still required before push notifications work:

- Configure `APNS_KEY_ID`, `APNS_TEAM_ID`, and `APNS_PRIVATE_KEY` Worker secrets.
- Use the App cloud inbox screen to claim a dedicated address and provision an active `pro_inbox_tokens` row.

## API

Token claim is unauthenticated bootstrap. All candidate API calls require the raw inbox token in `Authorization: Bearer <token>`.

```http
POST /v1/cloud-hotel-folio-token
GET /v1/cloud-hotel-folio-candidates
GET /v1/cloud-hotel-folio-candidates/{id}/pdf
POST /v1/cloud-hotel-folio-candidates/{id}/status
POST /v1/cloud-hotel-folio-devices
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
