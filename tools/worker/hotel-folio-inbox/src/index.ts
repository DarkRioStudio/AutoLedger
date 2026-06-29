import { importPKCS8, SignJWT } from "jose";
import PostalMime from "postal-mime";

type CandidateStatus =
  | "received"
  | "stored"
  | "notified"
  | "downloaded"
  | "converted"
  | "expired"
  | "deleted"
  | "failed";

type TokenRow = {
  token_hash: string;
  user_id: string;
  inbox_email: string;
  status: string;
  pro_expires_at: string | null;
};

type CandidateRow = {
  id: string;
  token_hash: string;
  user_id: string;
  source_email_subject: string | null;
  source_email_from: string | null;
  message_id_hash: string | null;
  attachment_file_name: string;
  attachment_hash: string;
  object_storage_key: string;
  object_byte_size: number;
  mime_type: string;
  status: CandidateStatus;
  received_at: string;
  expires_at: string;
  downloaded_at: string | null;
  converted_at: string | null;
  deleted_at: string | null;
  failure_reason: string | null;
  created_at: string;
  updated_at: string;
};

type APNSEnvironment = "development" | "production";

type APNSDeviceRow = {
  id: string;
  token_hash: string;
  user_id: string;
  device_token: string;
  device_token_hash: string;
  platform: string;
  environment: APNSEnvironment;
  status: string;
  last_seen_at: string;
  created_at: string;
  updated_at: string;
};

type APNSRuntimeConfig = {
  keyID: string;
  teamID: string;
  topic: string;
  privateKey: string;
};

type CloudHotelFolioCandidateDTO = {
  id: string;
  sourceType: "cloudWorker";
  tokenHash: string;
  sourceEmailSubject: string | null;
  sourceEmailFrom: string | null;
  messageIDHash: string | null;
  attachmentFileName: string;
  attachmentHash: string;
  objectStorageKey: string;
  objectByteSize: number;
  mimeType: string;
  status: CandidateStatus;
  receivedAt: string;
  expiresAt: string;
  downloadedAt: string | null;
  convertedAt: string | null;
  deletedAt: string | null;
  failureReason: string | null;
};

type InboxTokenClaimDTO = {
  token: string;
  inboxEmail: string;
  tokenHash: string;
  userID: string;
  status: "active";
};

type NotificationPayload = {
  type: "hotel_folio_candidate_created";
  userID: string;
  tokenHash: string;
  candidateID: string;
  attachmentFileName: string;
  objectByteSize: number;
  receivedAt: string;
  deepLink: string;
};

type StoredCandidate = {
  row: CandidateRow;
  inserted: boolean;
};

const encoder = new TextEncoder();
const pdfMimeTypes = new Set(["application/pdf", "application/x-pdf"]);
const inboxLocalPart = "folio";
const inboxDomain = "getautoledger.app";
const inboxTokenAlphabet = "abcdefghijklmnopqrstuvwxyz23456789";
const inboxTokenLength = 26;

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    return routeFetch(request, env);
  },

  async email(message: ForwardableEmailMessage, env: Env, ctx: ExecutionContext): Promise<void> {
    await receiveEmail(message, env, ctx);
  },

  async queue(batch: MessageBatch<unknown>, env: Env): Promise<void> {
    await deliverNotificationBatch(batch, env);
  },

  async scheduled(_controller: ScheduledController, env: Env, ctx: ExecutionContext): Promise<void> {
    ctx.waitUntil(pruneExpiredCandidates(env));
  }
} satisfies ExportedHandler<Env>;

export async function routeFetch(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);

  if (request.method === "OPTIONS") {
    return withCors(new Response(null, { status: 204 }), env);
  }

  if (url.pathname === "/health") {
    return json({ ok: true, service: "autoledger-hotel-folio-inbox" }, env);
  }

  if (request.method === "POST" && url.pathname === "/v1/cloud-hotel-folio-token") {
    return claimInboxToken(request, env);
  }

  const auth = await authenticateRequest(request, env);
  if (!auth.ok) {
    return json({ error: auth.error }, env, 401);
  }

  if (request.method === "GET" && url.pathname === "/v1/cloud-hotel-folio-candidates") {
    const rows = await listCandidates(env, auth.token.token_hash);
    return json({ candidates: rows.map(candidateDTO) }, env);
  }

  if (request.method === "POST" && url.pathname === "/v1/cloud-hotel-folio-devices") {
    return registerDevice(request, env, auth.token);
  }

  const pdfMatch = url.pathname.match(/^\/v1\/cloud-hotel-folio-candidates\/([^/]+)\/pdf$/);
  if (request.method === "GET" && pdfMatch?.[1]) {
    return downloadCandidatePDF(env, auth.token.token_hash, pdfMatch[1]);
  }

  const statusMatch = url.pathname.match(/^\/v1\/cloud-hotel-folio-candidates\/([^/]+)\/status$/);
  if (request.method === "POST" && statusMatch?.[1]) {
    return updateCandidateStatus(request, env, auth.token.token_hash, statusMatch[1]);
  }

  return json({ error: "not_found" }, env, 404);
}

export async function receiveEmail(
  message: ForwardableEmailMessage,
  env: Env,
  ctx: Pick<ExecutionContext, "waitUntil">
): Promise<void> {
  const inbox = parseInboxAddress(message.to);
  if (!inbox) {
    message.setReject("AutoLedger inbox address is invalid.");
    return;
  }

  const tokenHash = await sha256Hex(inbox.token);
  const token = await loadActiveToken(env, tokenHash);
  if (!token) {
    message.setReject("AutoLedger inbox token is inactive.");
    return;
  }

  const rawBuffer = await new Response(message.raw).arrayBuffer();
  const parsed = await PostalMime.parse(rawBuffer);
  const receivedAt = new Date();
  const expiresAt = retentionDate(env, receivedAt);
  const subject = redactMetadata(parsed.subject ?? message.headers.get("subject") ?? "");
  const from = redactMetadata(message.from);
  const messageIDHash = await optionalHash(message.headers.get("message-id") ?? parsed.messageId ?? "");

  const attachments = parsed.attachments.filter((attachment) => isPDFAttachment(attachment));
  for (const attachment of attachments) {
    const bytes = attachmentContentBytes(attachment);
    const attachmentHash = await sha256BytesHex(bytes);
    const fileName = safeFileName(attachment.filename ?? "folio.pdf");
    const objectKey = [
      "hotel-folio-candidates",
      tokenHash,
      `${receivedAt.toISOString()}-${attachmentHash}-${fileName}`
    ].join("/");
    const existing = await findCandidateByAttachmentHash(env, tokenHash, attachmentHash);
    if (existing) {
      continue;
    }

    await env.HOTEL_FOLIO_BUCKET.put(objectKey, bytes, {
      httpMetadata: { contentType: "application/pdf" },
      customMetadata: {
        candidateSource: "cloudWorker",
        tokenHash,
        attachmentHash
      }
    });

    const stored = await insertCandidate(env, {
      id: crypto.randomUUID(),
      token_hash: tokenHash,
      user_id: token.user_id,
      source_email_subject: subject,
      source_email_from: from,
      message_id_hash: messageIDHash,
      attachment_file_name: fileName,
      attachment_hash: attachmentHash,
      object_storage_key: objectKey,
      object_byte_size: bytes.byteLength,
      mime_type: "application/pdf",
      status: "stored",
      received_at: receivedAt.toISOString(),
      expires_at: expiresAt.toISOString(),
      downloaded_at: null,
      converted_at: null,
      deleted_at: null,
      failure_reason: null,
      created_at: receivedAt.toISOString(),
      updated_at: receivedAt.toISOString()
    });

    if (stored.inserted) {
      const notification = notificationPayload(stored.row, env);
      ctx.waitUntil(recordNotification(env, notification));
      ctx.waitUntil(env.APNS_QUEUE.send(notification));
    }
  }
}

async function authenticateRequest(
  request: Request,
  env: Env
): Promise<{ ok: true; token: TokenRow } | { ok: false; error: string }> {
  const rawToken = authToken(request);
  if (!rawToken) {
    return { ok: false, error: "missing_inbox_token" };
  }

  const tokenHash = await sha256Hex(normalizeToken(rawToken));
  const token = await loadActiveToken(env, tokenHash);
  if (!token) {
    return { ok: false, error: "inactive_or_unknown_inbox_token" };
  }

  return { ok: true, token };
}

function authToken(request: Request): string | null {
  const authorization = request.headers.get("authorization") ?? "";
  const bearer = authorization.match(/^Bearer\s+(.+)$/i)?.[1]?.trim();
  if (bearer) {
    return bearer;
  }

  const url = new URL(request.url);
  return url.searchParams.get("token")?.trim() || null;
}

function parseInboxAddress(address: string): { token: string; normalized: string } | null {
  const match = address
    .trim()
    .toLowerCase()
    .match(new RegExp(`^${inboxLocalPart}\\+([a-z0-9_-]+)@${inboxDomain.replace(".", "\\.")}$`));
  if (!match?.[1]) {
    return null;
  }
  const token = normalizeToken(match[1]);
  return token ? { token, normalized: inboxEmailForToken(token) } : null;
}

function normalizeToken(token: string): string {
  return token
    .trim()
    .toLowerCase()
    .split("")
    .filter((character) => /[a-z0-9_-]/.test(character))
    .join("");
}

function inboxEmailForToken(token: string): string {
  return `${inboxLocalPart}+${normalizeToken(token)}@${inboxDomain}`;
}

function normalizeClientID(value: string): string {
  return value
    .trim()
    .toLowerCase()
    .split("")
    .filter((character) => /[a-z0-9_-]/.test(character))
    .join("")
    .slice(0, 80);
}

function generateInboxToken(): string {
  const characters: string[] = [];
  const maxAcceptedByte = 256 - (256 % inboxTokenAlphabet.length);

  while (characters.length < inboxTokenLength) {
    const bytes = new Uint8Array(inboxTokenLength);
    crypto.getRandomValues(bytes);
    for (const byte of bytes) {
      if (byte >= maxAcceptedByte) {
        continue;
      }
      characters.push(inboxTokenAlphabet[byte % inboxTokenAlphabet.length]!);
      if (characters.length === inboxTokenLength) {
        break;
      }
    }
  }

  return characters.join("");
}

async function claimInboxToken(request: Request, env: Env): Promise<Response> {
  const body = await request.json().catch(() => ({})) as Partial<{
    clientID: string;
    platform: string;
    environment: string;
  }>;
  const clientID = normalizeClientID(body.clientID ?? "") || crypto.randomUUID().toLowerCase();
  const userID = `client:${clientID}`;
  const now = new Date().toISOString();
  const token = generateInboxToken();
  const tokenHash = await sha256Hex(token);
  const inboxEmail = inboxEmailForToken(token);

  await env.DB.prepare(
    `INSERT INTO pro_inbox_tokens (
        token_hash, user_id, inbox_email, status, pro_expires_at, created_at, updated_at
     ) VALUES (?, ?, ?, ?, ?, ?, ?)`
  )
    .bind(tokenHash, userID, inboxEmail, "active", null, now, now)
    .run();

  await env.DB.prepare(
    `UPDATE pro_inbox_tokens
        SET status = 'rotated',
            updated_at = ?
      WHERE user_id = ?
        AND token_hash != ?
        AND status = 'active'`
  )
    .bind(now, userID, tokenHash)
    .run();

  const payload: InboxTokenClaimDTO = {
    token,
    inboxEmail,
    tokenHash,
    userID,
    status: "active"
  };
  return json(payload, env, 201);
}

async function loadActiveToken(env: Env, tokenHash: string): Promise<TokenRow | null> {
  const row = await env.DB.prepare(
    `SELECT token_hash, user_id, inbox_email, status, pro_expires_at
       FROM pro_inbox_tokens
      WHERE token_hash = ?`
  )
    .bind(tokenHash)
    .first<TokenRow>();

  if (!row || row.status !== "active") {
    return null;
  }

  if (row.pro_expires_at) {
    const expiresAt = Date.parse(row.pro_expires_at);
    if (Number.isFinite(expiresAt) && expiresAt < Date.now()) {
      return null;
    }
  }

  return row;
}

async function listCandidates(env: Env, tokenHash: string): Promise<CandidateRow[]> {
  const result = await env.DB.prepare(
    `SELECT *
       FROM cloud_hotel_folio_candidates
      WHERE token_hash = ?
        AND status NOT IN ('deleted', 'expired')
      ORDER BY received_at DESC
      LIMIT 100`
  )
    .bind(tokenHash)
    .all<CandidateRow>();

  return result.results ?? [];
}

async function downloadCandidatePDF(env: Env, tokenHash: string, id: string): Promise<Response> {
  const row = await findCandidateByID(env, tokenHash, id);
  if (!row || row.status === "deleted" || row.status === "expired") {
    return json({ error: "candidate_not_found" }, env, 404);
  }

  const object = await env.HOTEL_FOLIO_BUCKET.get(row.object_storage_key);
  if (!object) {
    await markCandidate(env, row, "failed", { failureReason: "object_not_found" });
    return json({ error: "pdf_not_found" }, env, 404);
  }

  await markCandidate(env, row, "downloaded");
  return withCors(
    new Response(object.body, {
      headers: {
        "content-type": row.mime_type,
        "content-disposition": `attachment; filename="${escapeHeaderValue(row.attachment_file_name)}"`,
        "x-autoledger-candidate-id": row.id
      }
    }),
    env
  );
}

async function updateCandidateStatus(
  request: Request,
  env: Env,
  tokenHash: string,
  id: string
): Promise<Response> {
  const row = await findCandidateByID(env, tokenHash, id);
  if (!row) {
    return json({ error: "candidate_not_found" }, env, 404);
  }

  const body = await request.json().catch(() => ({})) as Partial<{
    status: CandidateStatus;
    failureReason: string;
    deleteCloudPDF: boolean;
  }>;
  const status = body.status;
  if (status !== "converted" && status !== "deleted" && status !== "failed") {
    return json({ error: "unsupported_status" }, env, 400);
  }

  const updated = await markCandidate(env, row, status, {
    failureReason: body.failureReason,
    deleteCloudPDF: body.deleteCloudPDF === true || status === "deleted"
  });
  return json({ candidate: candidateDTO(updated) }, env);
}

async function registerDevice(request: Request, env: Env, token: TokenRow): Promise<Response> {
  const body = await request.json().catch(() => ({})) as Partial<{
    deviceToken: string;
    platform: string;
    environment: APNSEnvironment;
  }>;
  const deviceToken = normalizeDeviceToken(body.deviceToken ?? "");
  if (!deviceToken) {
    return json({ error: "invalid_device_token" }, env, 400);
  }

  const environment = normalizeAPNSEnvironment(body.environment);
  const platform = normalizePlatform(body.platform ?? "ios");
  const now = new Date().toISOString();
  const deviceTokenHash = await sha256Hex(deviceToken);

  await env.DB.prepare(
    `INSERT INTO apns_devices (
        id, token_hash, user_id, device_token, device_token_hash, platform, environment,
        status, last_seen_at, created_at, updated_at
     ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
     ON CONFLICT(token_hash, device_token_hash) DO UPDATE SET
        user_id = excluded.user_id,
        device_token = excluded.device_token,
        platform = excluded.platform,
        environment = excluded.environment,
        status = 'active',
        last_seen_at = excluded.last_seen_at,
        updated_at = excluded.updated_at`
  )
    .bind(
      crypto.randomUUID(),
      token.token_hash,
      token.user_id,
      deviceToken,
      deviceTokenHash,
      platform,
      environment,
      "active",
      now,
      now,
      now
    )
    .run();

  return json({ ok: true, deviceTokenHash, environment, platform }, env);
}

async function insertCandidate(env: Env, candidate: CandidateRow): Promise<StoredCandidate> {
  const result = await env.DB.prepare(
    `INSERT OR IGNORE INTO cloud_hotel_folio_candidates (
        id, token_hash, user_id, source_email_subject, source_email_from, message_id_hash,
        attachment_file_name, attachment_hash, object_storage_key, object_byte_size, mime_type,
        status, received_at, expires_at, downloaded_at, converted_at, deleted_at, failure_reason,
        created_at, updated_at
     ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
  )
    .bind(
      candidate.id,
      candidate.token_hash,
      candidate.user_id,
      candidate.source_email_subject,
      candidate.source_email_from,
      candidate.message_id_hash,
      candidate.attachment_file_name,
      candidate.attachment_hash,
      candidate.object_storage_key,
      candidate.object_byte_size,
      candidate.mime_type,
      candidate.status,
      candidate.received_at,
      candidate.expires_at,
      candidate.downloaded_at,
      candidate.converted_at,
      candidate.deleted_at,
      candidate.failure_reason,
      candidate.created_at,
      candidate.updated_at
    )
    .run();

  const stored =
    (await findCandidateByID(env, candidate.token_hash, candidate.id)) ??
    (await findCandidateByAttachmentHash(env, candidate.token_hash, candidate.attachment_hash)) ??
    candidate;
  return { row: stored, inserted: (result.meta.changes ?? 0) > 0 };
}

async function findCandidateByID(env: Env, tokenHash: string, id: string): Promise<CandidateRow | null> {
  return env.DB.prepare(
    `SELECT *
       FROM cloud_hotel_folio_candidates
      WHERE id = ?
        AND token_hash = ?
      LIMIT 1`
  )
    .bind(id, tokenHash)
    .first<CandidateRow>();
}

async function findCandidateByAttachmentHash(
  env: Env,
  tokenHash: string,
  attachmentHash: string
): Promise<CandidateRow | null> {
  return env.DB.prepare(
    `SELECT *
       FROM cloud_hotel_folio_candidates
      WHERE token_hash = ?
        AND attachment_hash = ?
      LIMIT 1`
  )
    .bind(tokenHash, attachmentHash)
    .first<CandidateRow>();
}

async function markCandidate(
  env: Env,
  row: CandidateRow,
  status: CandidateStatus,
  options: { failureReason?: string; deleteCloudPDF?: boolean } = {}
): Promise<CandidateRow> {
  const now = new Date().toISOString();
  const downloadedAt = status === "downloaded" ? now : row.downloaded_at;
  const convertedAt = status === "converted" ? now : row.converted_at;
  const deletedAt = status === "deleted" ? now : row.deleted_at;
  const failureReason = status === "failed" ? options.failureReason ?? "unknown_failure" : null;

  await env.DB.prepare(
    `UPDATE cloud_hotel_folio_candidates
        SET status = ?,
            downloaded_at = ?,
            converted_at = ?,
            deleted_at = ?,
            failure_reason = ?,
            updated_at = ?
      WHERE id = ?
        AND token_hash = ?`
  )
    .bind(status, downloadedAt, convertedAt, deletedAt, failureReason, now, row.id, row.token_hash)
    .run();

  if (options.deleteCloudPDF) {
    await env.HOTEL_FOLIO_BUCKET.delete(row.object_storage_key);
  }

  return (await findCandidateByID(env, row.token_hash, row.id)) ?? {
    ...row,
    status,
    downloaded_at: downloadedAt,
    converted_at: convertedAt,
    deleted_at: deletedAt,
    failure_reason: failureReason,
    updated_at: now
  };
}

async function recordNotification(env: Env, payload: NotificationPayload): Promise<void> {
  const now = new Date().toISOString();
  await env.DB.prepare(
    `INSERT INTO notification_outbox (
        id, token_hash, user_id, candidate_id, kind, status, payload_json,
        delivered_at, failure_reason, created_at, updated_at
     ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
  )
    .bind(
      crypto.randomUUID(),
      payload.tokenHash,
      payload.userID,
      payload.candidateID,
      payload.type,
      "queued",
      JSON.stringify(payload),
      null,
      null,
      now,
      now
    )
    .run();
}

async function deliverNotificationBatch(batch: MessageBatch<unknown>, env: Env): Promise<void> {
  for (const message of batch.messages) {
    const payload = notificationPayloadFromQueueBody(message.body);
    if (!payload) {
      continue;
    }
    await deliverNotification(env, payload).catch((error: unknown) =>
      markNotificationPayload(env, payload, "failed", errorMessage(error))
    );
  }
}

async function deliverNotification(env: Env, payload: NotificationPayload): Promise<void> {
  const config = apnsRuntimeConfig(env);
  if (!config) {
    await markNotificationPayload(env, payload, "waiting_configuration", "APNs configuration is missing");
    return;
  }

  const devices = await listActiveDevices(env, payload.userID);
  if (devices.length === 0) {
    await markNotificationPayload(env, payload, "no_device", "No active device token");
    return;
  }

  const jwt = await apnsJWT(config);
  let deliveredCount = 0;
  const failures: string[] = [];
  for (const device of devices) {
    const result = await sendAPNSNotification(config, jwt, device, payload);
    if (result.ok) {
      deliveredCount += 1;
      continue;
    }
    failures.push(`${device.device_token_hash}:${result.status}:${result.body}`);
    if (result.status === 400 || result.status === 410) {
      await markDeviceInactive(env, device, result.body);
    }
  }

  if (deliveredCount > 0) {
    await markNotificationPayload(env, payload, "delivered", failures.join("; ").slice(0, 500) || null);
  } else {
    await markNotificationPayload(env, payload, "failed", failures.join("; ").slice(0, 500) || "APNs delivery failed");
  }
}

async function listActiveDevices(env: Env, userID: string): Promise<APNSDeviceRow[]> {
  const result = await env.DB.prepare(
    `SELECT *
       FROM apns_devices
      WHERE user_id = ?
        AND status = 'active'
      ORDER BY last_seen_at DESC
      LIMIT 20`
  )
    .bind(userID)
    .all<APNSDeviceRow>();
  return result.results ?? [];
}

async function markDeviceInactive(env: Env, device: APNSDeviceRow, reason: string): Promise<void> {
  const now = new Date().toISOString();
  await env.DB.prepare(
    `UPDATE apns_devices
        SET status = 'inactive',
            updated_at = ?
      WHERE id = ?`
  )
    .bind(now, device.id)
    .run();
  await env.DB.prepare(
    `INSERT INTO notification_outbox (
        id, token_hash, user_id, candidate_id, kind, status, payload_json,
        delivered_at, failure_reason, created_at, updated_at
     ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
  )
    .bind(
      crypto.randomUUID(),
      device.token_hash,
      device.user_id,
      "",
      "apns_device_inactive",
      "recorded",
      JSON.stringify({ deviceTokenHash: device.device_token_hash }),
      null,
      reason.slice(0, 500),
      now,
      now
    )
    .run();
}

async function markNotificationPayload(
  env: Env,
  payload: NotificationPayload,
  status: string,
  failureReason: string | null
): Promise<void> {
  const now = new Date().toISOString();
  const deliveredAt = status === "delivered" ? now : null;
  await env.DB.prepare(
    `UPDATE notification_outbox
        SET status = ?,
            delivered_at = COALESCE(?, delivered_at),
            failure_reason = ?,
            updated_at = ?
      WHERE candidate_id = ?
        AND token_hash = ?
        AND kind = ?`
  )
    .bind(status, deliveredAt, failureReason, now, payload.candidateID, payload.tokenHash, payload.type)
    .run();
}

async function pruneExpiredCandidates(env: Env): Promise<void> {
  const now = new Date().toISOString();
  const result = await env.DB.prepare(
    `SELECT *
       FROM cloud_hotel_folio_candidates
      WHERE status NOT IN ('converted', 'deleted', 'expired')
        AND expires_at < ?
      LIMIT 200`
  )
    .bind(now)
    .all<CandidateRow>();

  for (const row of result.results ?? []) {
    await markCandidate(env, row, "expired", { deleteCloudPDF: true });
  }
}

function retentionDate(env: Env, receivedAt: Date): Date {
  const configured = Number.parseInt(env.CANDIDATE_RETENTION_DAYS ?? "7", 10);
  const days = Math.min(Math.max(Number.isFinite(configured) ? configured : 7, 1), 30);
  return new Date(receivedAt.getTime() + days * 24 * 60 * 60 * 1000);
}

function notificationPayload(row: CandidateRow, env: Env): NotificationPayload {
  const origin = env.PUBLIC_CANDIDATE_API_ORIGIN.replace(/\/+$/, "");
  return {
    type: "hotel_folio_candidate_created",
    userID: row.user_id,
    tokenHash: row.token_hash,
    candidateID: row.id,
    attachmentFileName: row.attachment_file_name,
    objectByteSize: row.object_byte_size,
    receivedAt: row.received_at,
    deepLink: `autoledger://hotel-cloud-candidate/${row.id}?origin=${encodeURIComponent(origin)}`
  };
}

function notificationPayloadFromQueueBody(value: unknown): NotificationPayload | null {
  if (!value || typeof value !== "object") {
    return null;
  }
  const payload = value as Partial<NotificationPayload>;
  const requiredValues = [
    payload.type,
    payload.userID,
    payload.tokenHash,
    payload.candidateID,
    payload.attachmentFileName,
    payload.receivedAt,
    payload.deepLink
  ];
  const hasRequiredStrings = requiredValues.every((item) => typeof item === "string" && item.length > 0);
  if (!hasRequiredStrings || typeof payload.objectByteSize !== "number") {
    return null;
  }
  if (payload.type !== "hotel_folio_candidate_created") {
    return null;
  }
  return {
    type: payload.type,
    userID: payload.userID!,
    tokenHash: payload.tokenHash!,
    candidateID: payload.candidateID!,
    attachmentFileName: payload.attachmentFileName!,
    objectByteSize: payload.objectByteSize,
    receivedAt: payload.receivedAt!,
    deepLink: payload.deepLink!
  };
}

function apnsRuntimeConfig(env: Env): APNSRuntimeConfig | null {
  const runtime = env as Env & {
    APNS_KEY_ID?: string;
    APNS_TEAM_ID?: string;
    APNS_TOPIC?: string;
    APNS_PRIVATE_KEY?: string;
  };
  const keyID = runtime.APNS_KEY_ID?.trim() ?? "";
  const teamID = runtime.APNS_TEAM_ID?.trim() ?? "";
  const topic = runtime.APNS_TOPIC?.trim() ?? "";
  const privateKey = runtime.APNS_PRIVATE_KEY?.trim() ?? "";
  if (!keyID || !teamID || !topic || !privateKey) {
    return null;
  }
  return { keyID, teamID, topic, privateKey };
}

async function apnsJWT(config: APNSRuntimeConfig): Promise<string> {
  const key = await importPKCS8(config.privateKey.replace(/\\n/g, "\n"), "ES256");
  return new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: config.keyID })
    .setIssuer(config.teamID)
    .setIssuedAt()
    .setExpirationTime("50m")
    .sign(key);
}

async function sendAPNSNotification(
  config: APNSRuntimeConfig,
  jwt: string,
  device: APNSDeviceRow,
  payload: NotificationPayload
): Promise<{ ok: true } | { ok: false; status: number; body: string }> {
  const host = device.environment === "production"
    ? "https://api.push.apple.com"
    : "https://api.sandbox.push.apple.com";
  const response = await fetch(`${host}/3/device/${device.device_token}`, {
    method: "POST",
    headers: {
      authorization: `bearer ${jwt}`,
      "apns-topic": config.topic,
      "apns-push-type": "alert",
      "apns-priority": "10",
      "content-type": "application/json"
    },
    body: JSON.stringify(makeAPNSNotificationBody(payload))
  });

  if (response.ok) {
    return { ok: true };
  }
  return {
    ok: false,
    status: response.status,
    body: await response.text().catch(() => "")
  };
}

function makeAPNSNotificationBody(payload: NotificationPayload): Record<string, unknown> {
  return {
    aps: {
      alert: {
        title: "酒店水单待确认",
        body: "有新的酒店消费候选待识别。"
      },
      sound: "default"
    },
    autoledgerDeepLink: payload.deepLink,
    candidateID: payload.candidateID
  };
}

function normalizeDeviceToken(value: string): string | null {
  const token = value.trim().toLowerCase().replace(/[^a-f0-9]/g, "");
  return token.length >= 32 && token.length <= 256 ? token : null;
}

function normalizeAPNSEnvironment(value: string | undefined): APNSEnvironment {
  return value === "production" ? "production" : "development";
}

function normalizePlatform(value: string): string {
  const platform = value.trim().toLowerCase().replace(/[^a-z0-9_-]/g, "");
  return platform || "ios";
}

function candidateDTO(row: CandidateRow): CloudHotelFolioCandidateDTO {
  return {
    id: row.id,
    sourceType: "cloudWorker",
    tokenHash: row.token_hash,
    sourceEmailSubject: row.source_email_subject,
    sourceEmailFrom: row.source_email_from,
    messageIDHash: row.message_id_hash,
    attachmentFileName: row.attachment_file_name,
    attachmentHash: row.attachment_hash,
    objectStorageKey: row.object_storage_key,
    objectByteSize: row.object_byte_size,
    mimeType: row.mime_type,
    status: row.status,
    receivedAt: row.received_at,
    expiresAt: row.expires_at,
    downloadedAt: row.downloaded_at,
    convertedAt: row.converted_at,
    deletedAt: row.deleted_at,
    failureReason: row.failure_reason
  };
}

function isPDFAttachment(attachment: { filename?: string | null; mimeType?: string | null }): boolean {
  const mimeType = attachment.mimeType?.toLowerCase() ?? "";
  const fileName = attachment.filename?.toLowerCase() ?? "";
  return pdfMimeTypes.has(mimeType) || fileName.endsWith(".pdf");
}

function attachmentContentBytes(attachment: { content?: unknown }): Uint8Array {
  const content = attachment.content;
  if (content instanceof Uint8Array) {
    return content;
  }
  if (content instanceof ArrayBuffer) {
    return new Uint8Array(content);
  }
  if (typeof content === "string") {
    return encoder.encode(content);
  }
  return new Uint8Array();
}

function safeFileName(fileName: string): string {
  const trimmed = fileName.trim() || "folio.pdf";
  const safe = trimmed
    .split("")
    .map((character) => (/[a-zA-Z0-9._-]/.test(character) ? character : "-"))
    .join("")
    .replace(/-+/g, "-")
    .toLowerCase();
  return safe.endsWith(".pdf") ? safe : `${safe}.pdf`;
}

function redactMetadata(value: string): string | null {
  const redacted = value
    .trim()
    .replace(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi, "[redacted-email]")
    .replace(/(?<!\d)(?:\+?\d[\d\s-]{6,}\d)(?!\d)/g, "[redacted-number]");
  return redacted.length > 0 ? redacted : null;
}

async function optionalHash(value: string): Promise<string | null> {
  const trimmed = value.trim();
  return trimmed ? sha256Hex(trimmed) : null;
}

async function sha256Hex(value: string): Promise<string> {
  return sha256BytesHex(encoder.encode(value));
}

async function sha256BytesHex(value: Uint8Array | ArrayBuffer): Promise<string> {
  const bytes = value instanceof Uint8Array ? new Uint8Array(value) : new Uint8Array(value);
  const digest = await crypto.subtle.digest("SHA-256", bytes.buffer);
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function json(payload: unknown, env: Env, status = 200): Response {
  return withCors(
    new Response(JSON.stringify(payload), {
      status,
      headers: { "content-type": "application/json; charset=utf-8" }
    }),
    env
  );
}

function withCors(response: Response, env: Env): Response {
  const headers = new Headers(response.headers);
  headers.set("access-control-allow-origin", env.PUBLIC_CANDIDATE_API_ORIGIN);
  headers.set("access-control-allow-methods", "GET, POST, OPTIONS");
  headers.set("access-control-allow-headers", "authorization, content-type");
  return new Response(response.body, { status: response.status, statusText: response.statusText, headers });
}

function escapeHeaderValue(value: string): string {
  return value.replace(/["\\\r\n]/g, "_");
}

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

export const testInternals = {
  parseInboxAddress,
  normalizeToken,
  inboxEmailForToken,
  normalizeClientID,
  generateInboxToken,
  normalizeDeviceToken,
  normalizeAPNSEnvironment,
  redactMetadata,
  safeFileName,
  isPDFAttachment,
  candidateDTO,
  makeAPNSNotificationBody,
  notificationPayloadFromQueueBody,
  retentionDate,
  sha256Hex
};
