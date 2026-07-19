import { compactVerify, decodeProtectedHeader, importPKCS8, importX509, SignJWT } from "jose";
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
  access_token_hash: string | null;
  user_id: string;
  inbox_email: string;
  status: string;
  pro_expires_at: string | null;
};

type DataCleaningMerchantFeature = {
  merchantKeyHash: string;
  transactionCount: number;
};

type DataCleaningAssistRequest = {
  signedTransactionInfo?: string;
  payload?: {
    schemaVersion?: number;
    privacyMode?: string;
    merchantFeatures?: DataCleaningMerchantFeature[];
  };
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

type AppStoreServerEnvironment = "production" | "sandbox";

type AppStoreServerAPIConfig = {
  issuerID: string;
  keyID: string;
  bundleID: string;
  privateKey: string;
  environment: AppStoreServerEnvironment;
};

type AppStoreTransactionPayload = {
  transactionId?: string;
  transactionID?: string;
  originalTransactionId?: string;
  originalTransactionID?: string;
  productId?: string;
  productID?: string;
  bundleId?: string;
  bundleID?: string;
  environment?: string;
  expiresDate?: number | string | null;
  revocationDate?: number | string | null;
};

type AppStoreRenewalPayload = {
  originalTransactionId?: string;
  originalTransactionID?: string;
  productId?: string;
  productID?: string;
  autoRenewProductId?: string;
  autoRenewProductID?: string;
  autoRenewStatus?: number | string | null;
  expirationIntent?: number | string | null;
  gracePeriodExpiresDate?: number | string | null;
  isInBillingRetryPeriod?: boolean | number | string | null;
};

type AppStoreNotificationDataPayload = {
  appAppleId?: number;
  bundleId?: string;
  bundleID?: string;
  bundleVersion?: string;
  environment?: string;
  signedTransactionInfo?: string;
  signedRenewalInfo?: string;
  status?: number;
};

type AppStoreNotificationPayload = {
  notificationType?: string;
  subtype?: string;
  notificationUUID?: string;
  version?: string;
  signedDate?: number | string;
  data?: AppStoreNotificationDataPayload;
};

type AppStoreNotificationScope = {
  notificationUUID: string;
  notificationType: string;
  subtype: string | null;
  version: string | null;
  signedDate: string | null;
  environment: string;
  bundleID: string | null;
  appAppleID: string | null;
  transactionID: string | null;
  originalTransactionIDHash: string;
  userID: string;
  productID: string;
  expiresAt: string | null;
  rawPayloadHash: string;
};

type AppStoreEntitlementState = {
  status: "active" | "grace_period" | "billing_retry" | "expired" | "revoked" | "refunded" | "ignored";
  active: boolean;
  expiresAt: string | null;
  reason: string;
};

type VerifiedAppStoreSignedPayload = {
  payload: AppStoreNotificationPayload;
  verificationMode: "certificate_chain" | "unsigned_test";
};

type AppStoreNotificationProcessResult =
  | {
      ok: true;
      duplicate: boolean;
      notificationUUID: string;
      userID?: string;
      entitlementStatus?: AppStoreEntitlementState["status"];
      active?: boolean;
      expiresAt?: string | null;
    }
  | { ok: false; status: number; code: string; message: string };

type AppStoreNotificationHistoryRequest = {
  startDate: number;
  endDate: number;
  onlyFailures: boolean;
};

type AppStoreNotificationHistoryResponse = {
  paginationToken?: string;
  hasMore?: boolean;
  notificationHistory?: Array<{ signedPayload?: string }>;
};

type AppStoreNotificationHistoryCollectResult = {
  signedPayloads: string[];
  pages: number;
  hasMore: boolean;
};

type AppStoreNotificationHistoryProcessResult = {
  ok: boolean;
  skippedReason?: string;
  collected: number;
  processed: number;
  duplicates: number;
  failed: number;
  pages: number;
  hasMore: boolean;
};

type ParsedCertificate = {
  derBytes: Uint8Array;
  pem: string;
  tbsBytes: Uint8Array;
  signatureAlgorithmOID: string;
  signatureBytes: Uint8Array;
  notBefore: Date | null;
  notAfter: Date | null;
};

type EntitlementVerificationResult = {
  allowed: boolean;
  reason?: string;
  expiresAt?: string;
  originalTransactionID?: string;
  productID?: string;
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
  proExpiresAt: string;
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

type CandidatePDFInput = {
  fileName: string;
  bytes: Uint8Array;
  source: "attachment" | "emailBody";
};

const encoder = new TextEncoder();
const pdfMimeTypes = new Set(["application/pdf", "application/x-pdf"]);
const inboxLocalPart = "folio";
const inboxDomain = "getautoledger.app";
const inboxTokenAlphabet = "abcdefghijklmnopqrstuvwxyz23456789";
const inboxTokenLength = 26;
const proProductIDs = new Set([
  "top.darkrio326.AutoLedger.pro.monthly",
  "top.darkrio326.AutoLedger.pro.yearly"
]);

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
    ctx.waitUntil(processAppStoreNotificationHistory(env).catch((error) => {
      console.error("app_store_notification_history_failed", errorMessage(error));
    }));
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

  if (request.method === "POST" && url.pathname === "/v1/pro-entitlements/verify") {
    return verifyProEntitlement(request, env);
  }

  if (request.method === "POST" && url.pathname === "/v1/data-cleaning-assist") {
    return dataCleaningAssist(request, env);
  }

  if (request.method === "POST" && url.pathname === "/v1/app-store/notifications") {
    return receiveAppStoreServerNotification(request, env);
  }

  const auth = await authenticateRequest(request, env);
  if (!auth.ok) {
    return json({ error: auth.error }, env, 401);
  }

  if (request.method === "GET" && url.pathname === "/v1/cloud-hotel-folio-candidates") {
    const rows = await listCandidates(env, auth.token.token_hash);
    return json(candidateListEnvelope(rows.map(candidateDTO), auth.token.inbox_email), env);
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
  const token = await loadActiveRoutingToken(env, tokenHash);
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

  const pdfInputs = candidatePDFInputs(parsed, subject);
  for (const input of pdfInputs) {
    const bytes = input.bytes;
    const attachmentHash = await sha256BytesHex(bytes);
    const fileName = safeFileName(input.fileName);
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
        candidateSource: input.source === "emailBody" ? "cloudWorkerEmailBody" : "cloudWorker",
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
  const token = await loadActiveAccessToken(env, tokenHash);
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
  return null;
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

async function makeInboxCredentialPair(): Promise<{
  routingToken: string;
  accessToken: string;
  routingTokenHash: string;
  accessTokenHash: string;
}> {
  const routingToken = generateInboxToken();
  let accessToken = generateInboxToken();
  while (accessToken === routingToken) {
    accessToken = generateInboxToken();
  }
  return {
    routingToken,
    accessToken,
    routingTokenHash: await sha256Hex(routingToken),
    accessTokenHash: await sha256Hex(accessToken)
  };
}

async function claimInboxToken(request: Request, env: Env): Promise<Response> {
  const body = await request.json().catch(() => ({})) as Partial<{
    clientID: string;
    platform: string;
    environment: string;
    signedTransactionInfo: string;
    existingAccessToken: string;
  }>;
  let serverEntitlement: EntitlementVerificationResult | null = null;
  if (!allowsUnverifiedTokenClaim(env)) {
    serverEntitlement = await verifyAppStoreEntitlement(env, body.signedTransactionInfo);
    if (serverEntitlement.allowed !== true) {
      return json(
        {
          error: "server_entitlement_required",
          reason: serverEntitlement.reason ?? "server_entitlement_denied",
          message: "Cloud folio inbox token claim requires server-side Pro entitlement verification."
        },
        env,
        403
      );
    }
  }

  if (allowsUnverifiedTokenClaim(env) && !body.signedTransactionInfo) {
    serverEntitlement = null;
  } else if (!serverEntitlement) {
    serverEntitlement = await verifyAppStoreEntitlement(env, body.signedTransactionInfo);
  }

  if (body.signedTransactionInfo && serverEntitlement?.allowed !== true) {
    return json(
      {
        error: "server_entitlement_required",
        reason: serverEntitlement?.reason ?? "server_entitlement_denied",
        message: "Cloud folio inbox token claim requires server-side Pro entitlement verification."
      },
      env,
      403
    );
  }

  const clientID = normalizeClientID(body.clientID ?? "") || crypto.randomUUID().toLowerCase();
  const userID = serverEntitlement?.originalTransactionID
    ? await appStoreUserID(serverEntitlement.originalTransactionID)
    : `client:${clientID}`;
  const now = new Date().toISOString();
  const proExpiresAt = serverEntitlement?.expiresAt ?? unverifiedTokenExpirationDate(env, new Date()).toISOString();
  const existingAccessToken = normalizeToken(body.existingAccessToken ?? "");
  if (existingAccessToken) {
    const existingAccessTokenHash = await sha256Hex(existingAccessToken);
    const existing = await env.DB.prepare(
      `SELECT token_hash, access_token_hash, user_id, inbox_email, status, pro_expires_at
        FROM pro_inbox_tokens
        WHERE access_token_hash = ?
          AND status = 'active'`
    )
      .bind(existingAccessTokenHash)
      .first<TokenRow>();
    if (existing) {
      await env.DB.prepare(
        `UPDATE pro_inbox_tokens
            SET user_id = ?,
                pro_expires_at = ?,
                updated_at = ?
          WHERE access_token_hash = ?`
      )
        .bind(userID, proExpiresAt, now, existingAccessTokenHash)
        .run();
      console.info({ event: "cloud_folio_token_claim", result: "reused" });
      return json({
        token: existingAccessToken,
        inboxEmail: existing.inbox_email,
        tokenHash: existingAccessTokenHash,
        userID,
        status: "active",
        proExpiresAt
      } satisfies InboxTokenClaimDTO, env, 200);
    }
  }
  const {
    routingToken,
    accessToken,
    routingTokenHash: tokenHash,
    accessTokenHash
  } = await makeInboxCredentialPair();
  const inboxEmail = inboxEmailForToken(routingToken);

  await env.DB.prepare(
    `INSERT INTO pro_inbox_tokens (
        token_hash, access_token_hash, user_id, inbox_email, status, pro_expires_at, created_at, updated_at
     ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`
  )
    .bind(tokenHash, accessTokenHash, userID, inboxEmail, "active", proExpiresAt, now, now)
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
    token: accessToken,
    inboxEmail,
    tokenHash: accessTokenHash,
    userID,
    status: "active",
    proExpiresAt
  };
  console.info({ event: "cloud_folio_token_claim", result: "created" });
  return json(payload, env, 201);
}

async function verifyProEntitlement(request: Request, env: Env): Promise<Response> {
  const body = await request.json().catch(() => ({})) as Partial<{
    capability: string;
    signedTransactionInfo: string;
  }>;
  if (body.capability !== "cloudFolioInbox") {
    return json({ allowed: false, reason: "unsupported_capability" }, env);
  }
  const result = await verifyAppStoreEntitlement(env, body.signedTransactionInfo);
  return json({ allowed: result.allowed, reason: result.reason, expiresAt: result.expiresAt }, env);
}

async function dataCleaningAssist(request: Request, env: Env): Promise<Response> {
  const body = await request.json().catch(() => ({})) as DataCleaningAssistRequest;
  const entitlement = await verifyAppStoreEntitlement(env, body.signedTransactionInfo);
  if (entitlement.allowed !== true) {
    return json({ error: "server_entitlement_required", reason: entitlement.reason }, env, 403);
  }
  const payload = body.payload;
  if (payload?.schemaVersion !== 1 || payload.privacyMode !== "hashed_aggregate_v1") {
    return json({ error: "unsupported_data_cleaning_payload" }, env, 400);
  }
  const features = (payload.merchantFeatures ?? [])
    .filter((feature) => /^m_[a-f0-9]{16}$/.test(feature.merchantKeyHash))
    .slice(0, 500);
  const byHash = new Map(features.map((feature) => [feature.merchantKeyHash, feature]));
  const suggestions: Array<{
    kind: "merchantNormalization";
    candidateMerchantHash: string;
    targetMerchantHash: string;
    confidence: number;
    reasonCode: string;
  }> = [];

  for (const aliases of dataCleaningMerchantAliasCatalog) {
    const matches = aliases
      .map((alias) => byHash.get(stableMerchantHash(alias)))
      .filter((feature): feature is DataCleaningMerchantFeature => Boolean(feature));
    if (matches.length < 2) {
      continue;
    }
    const target = matches.slice().sort((left, right) => (
      right.transactionCount - left.transactionCount || left.merchantKeyHash.localeCompare(right.merchantKeyHash)
    ))[0]!;
    for (const candidate of matches) {
      if (candidate.merchantKeyHash === target.merchantKeyHash) {
        continue;
      }
      suggestions.push({
        kind: "merchantNormalization",
        candidateMerchantHash: candidate.merchantKeyHash,
        targetMerchantHash: target.merchantKeyHash,
        confidence: 0.96,
        reasonCode: "cloud_alias_catalog"
      });
    }
  }

  return json({ schemaVersion: 1, privacyMode: "hashed_suggestions_v1", suggestions }, env);
}

const dataCleaningMerchantAliasCatalog = [
  ["麦当劳", "mcdonalds", "mcdonald"],
  ["肯德基", "kfc"],
  ["星巴克", "starbucks"],
  ["瑞幸咖啡", "瑞幸", "luckincoffee", "luckin"],
  ["携程", "携程旅行", "ctrip", "tripcom"],
  ["滴滴", "滴滴出行", "didichuxing", "didi"],
  ["美团", "美团外卖", "meituan"],
  ["支付宝", "alipay"],
  ["微信支付", "wechatpay"]
] as const;

function stableMerchantHash(value: string): string {
  const normalized = [...value.trim().toLocaleLowerCase()]
    .filter((character) => /[\p{L}\p{N}]/u.test(character))
    .join("");
  let hash = 14_695_981_039_346_656_037n;
  for (const byte of encoder.encode(normalized)) {
    hash ^= BigInt(byte);
    hash = BigInt.asUintN(64, hash * 1_099_511_628_211n);
  }
  return `m_${hash.toString(16).padStart(16, "0")}`;
}

async function receiveAppStoreServerNotification(request: Request, env: Env): Promise<Response> {
  const body = await request.json().catch(() => ({})) as Partial<{ signedPayload: string }>;
  const signedPayload = typeof body.signedPayload === "string" ? body.signedPayload.trim() : "";
  if (!signedPayload) {
    return json({ error: "missing_signed_payload" }, env, 400);
  }

  const result = await processAppStoreServerNotificationPayload(env, signedPayload);
  if (!result.ok) {
    return json({ error: result.code, message: result.message }, env, result.status);
  }
  return json(result, env);
}

async function processAppStoreServerNotificationPayload(
  env: Env,
  signedPayload: string
): Promise<AppStoreNotificationProcessResult> {
  const decoded = await decodeAppStoreServerNotificationPayload(env, signedPayload);
  if (!decoded.ok) {
    return decoded;
  }

  const config = appStoreRuntimeConfig(env);
  const prepared = await prepareAppStoreNotification(config, signedPayload, decoded.payload);
  if (!prepared.ok) {
    return prepared;
  }

  const inserted = await insertAppStoreNotificationEvent(env, prepared.scope);
  if (!inserted) {
    return {
      ok: true,
      duplicate: true,
      notificationUUID: prepared.scope.notificationUUID
    };
  }

  const state = appStoreEntitlementStateForNotification(
    prepared.scope.notificationType,
    prepared.scope.subtype,
    prepared.transactionPayload,
    prepared.renewalPayload
  );

  try {
    await applyAppStoreEntitlementState(env, prepared.scope, state);
    await markAppStoreNotificationEvent(env, prepared.scope.notificationUUID, "processed", null, state);
    return {
      ok: true,
      duplicate: false,
      notificationUUID: prepared.scope.notificationUUID,
      userID: prepared.scope.userID,
      entitlementStatus: state.status,
      active: state.active,
      expiresAt: state.expiresAt
    };
  } catch (caught) {
    await markAppStoreNotificationEvent(
      env,
      prepared.scope.notificationUUID,
      "failed",
      errorMessage(caught),
      state
    );
    return {
      ok: false,
      status: 500,
      code: "app_store_notification_processing_failed",
      message: errorMessage(caught)
    };
  }
}

async function decodeAppStoreServerNotificationPayload(
  env: Env,
  signedPayload: string
): Promise<{ ok: true; payload: AppStoreNotificationPayload; verificationMode: VerifiedAppStoreSignedPayload["verificationMode"] } | { ok: false; status: number; code: string; message: string }> {
  const rootCertificates = appStoreNotificationRootCertificates(env);
  if (rootCertificates.length > 0) {
    return verifyAppStoreSignedPayload(signedPayload, rootCertificates);
  }

  if (allowsUnsignedAppStoreNotifications(env)) {
    const payload = decodeJWSPayload<AppStoreNotificationPayload>(signedPayload);
    if (!payload) {
      return {
        ok: false,
        status: 400,
        code: "invalid_signed_payload",
        message: "signedPayload is not a decodable App Store Server Notification V2 JWS."
      };
    }
    return { ok: true, payload, verificationMode: "unsigned_test" };
  }

  return {
    ok: false,
    status: 503,
    code: "app_store_notification_verifier_unconfigured",
    message: "App Store Server Notifications require APP_STORE_NOTIFICATION_ROOT_CERT_PEM before production use."
  };
}

async function verifyAppStoreSignedPayload(
  signedPayload: string,
  rootCertificatePEMs: string[],
  now: Date = new Date()
): Promise<{ ok: true; payload: AppStoreNotificationPayload; verificationMode: "certificate_chain" } | { ok: false; status: number; code: string; message: string }> {
  let header: ReturnType<typeof decodeProtectedHeader>;
  try {
    header = decodeProtectedHeader(signedPayload);
  } catch {
    return {
      ok: false,
      status: 400,
      code: "invalid_signed_payload",
      message: "signedPayload is not a valid JWS."
    };
  }

  if (header.alg !== "ES256") {
    return {
      ok: false,
      status: 400,
      code: "unsupported_signed_payload_algorithm",
      message: "App Store Server Notifications signedPayload must use ES256."
    };
  }

  const x5c = header.x5c;
  if (!Array.isArray(x5c) || x5c.length === 0) {
    return {
      ok: false,
      status: 400,
      code: "missing_signed_payload_certificate_chain",
      message: "signedPayload header must contain an x5c certificate chain."
    };
  }

  let chain: ParsedCertificate[];
  let trustedRoot: ParsedCertificate | null;
  try {
    chain = x5c.map((certificate) => parseCertificate(base64ToBytes(certificate)));
    trustedRoot = await selectTrustedRootCertificate(chain, rootCertificatePEMs);
  } catch (caught) {
    return {
      ok: false,
      status: 400,
      code: "invalid_signed_payload_certificate_chain",
      message: errorMessage(caught)
    };
  }

  if (!trustedRoot) {
    return {
      ok: false,
      status: 400,
      code: "untrusted_signed_payload_root",
      message: "signedPayload certificate chain does not anchor to the configured Apple root certificate."
    };
  }

  const fullChain = certificateDERKey(chain[chain.length - 1]!) === certificateDERKey(trustedRoot)
    ? chain
    : [...chain, trustedRoot];
  for (const certificate of fullChain) {
    if (!certificateIsCurrentlyValid(certificate, now)) {
      return {
        ok: false,
        status: 400,
        code: "signed_payload_certificate_expired",
        message: "signedPayload certificate chain contains an expired or not-yet-valid certificate."
      };
    }
  }

  for (let index = 0; index < fullChain.length - 1; index += 1) {
    const verified = await verifyCertificateSignature(fullChain[index]!, fullChain[index + 1]!).catch(() => false);
    if (!verified) {
      return {
        ok: false,
        status: 400,
        code: "invalid_signed_payload_certificate_signature",
        message: "signedPayload certificate chain signature verification failed."
      };
    }
  }

  const leafKey = await importX509(fullChain[0]!.pem, "ES256").catch(() => null);
  if (!leafKey) {
    return {
      ok: false,
      status: 400,
      code: "invalid_signed_payload_certificate_chain",
      message: "signedPayload leaf certificate is not usable for ES256 verification."
    };
  }

  const verified = await compactVerify(signedPayload, leafKey, { algorithms: ["ES256"] }).catch(() => null);
  if (!verified) {
    return {
      ok: false,
      status: 400,
      code: "invalid_signed_payload_signature",
      message: "signedPayload JWS signature verification failed."
    };
  }

  try {
    const payloadText = new TextDecoder().decode(verified.payload);
    return { ok: true, payload: JSON.parse(payloadText) as AppStoreNotificationPayload, verificationMode: "certificate_chain" };
  } catch {
    return {
      ok: false,
      status: 400,
      code: "invalid_signed_payload",
      message: "signedPayload payload is not valid JSON."
    };
  }
}

async function prepareAppStoreNotification(
  config: Pick<AppStoreServerAPIConfig, "bundleID" | "environment">,
  signedPayload: string,
  payload: AppStoreNotificationPayload
): Promise<
  | {
      ok: true;
      scope: AppStoreNotificationScope;
      transactionPayload: AppStoreTransactionPayload;
      renewalPayload: AppStoreRenewalPayload | null;
    }
  | { ok: false; status: number; code: string; message: string }
> {
  const notificationUUID = stringPayloadValue(payload, "notificationUUID");
  const notificationType = normalizeAppStoreNotificationType(payload.notificationType);
  if (!notificationUUID || !notificationType) {
    return {
      ok: false,
      status: 400,
      code: "invalid_notification_header",
      message: "notificationUUID and notificationType are required."
    };
  }

  const data = payload.data;
  if (!data) {
    return { ok: false, status: 400, code: "missing_notification_data", message: "Notification data is required." };
  }

  const bundleID = stringPayloadValue(data, "bundleId", "bundleID");
  if (bundleID !== config.bundleID) {
    return { ok: false, status: 400, code: "bundle_id_mismatch", message: "Notification bundleId does not match this app." };
  }

  const environment = normalizeAppStoreEnvironment(data.environment);
  if (environment !== config.environment) {
    return {
      ok: false,
      status: 400,
      code: "environment_mismatch",
      message: "Notification environment does not match this Worker environment."
    };
  }

  const transactionPayload = decodeJWSPayload<AppStoreTransactionPayload>(data.signedTransactionInfo ?? "");
  if (!transactionPayload) {
    return {
      ok: false,
      status: 400,
      code: "invalid_signed_transaction_info",
      message: "Notification signedTransactionInfo is required and must be decodable."
    };
  }

  const transactionScope = await appStoreNotificationTransactionScope(config, transactionPayload);
  if (!transactionScope.ok) {
    return { ok: false, status: 400, code: transactionScope.code, message: transactionScope.message };
  }

  const renewalPayload = data.signedRenewalInfo
    ? decodeJWSPayload<AppStoreRenewalPayload>(data.signedRenewalInfo)
    : null;
  const signedDate = appleDate(payload.signedDate)?.toISOString() ?? null;
  const rawPayloadHash = await sha256Hex(signedPayload);

  return {
    ok: true,
    scope: {
      notificationUUID,
      notificationType,
      subtype: stringPayloadValue(payload, "subtype"),
      version: stringPayloadValue(payload, "version"),
      signedDate,
      environment,
      bundleID,
      appAppleID: typeof data.appAppleId === "number" ? String(data.appAppleId) : null,
      transactionID: transactionScope.transactionID,
      originalTransactionIDHash: transactionScope.originalTransactionIDHash,
      userID: transactionScope.userID,
      productID: transactionScope.productID,
      expiresAt: transactionScope.expiresAt,
      rawPayloadHash
    },
    transactionPayload,
    renewalPayload
  };
}

async function appStoreNotificationTransactionScope(
  config: Pick<AppStoreServerAPIConfig, "bundleID">,
  payload: AppStoreTransactionPayload
): Promise<
  | {
      ok: true;
      transactionID: string | null;
      originalTransactionID: string;
      originalTransactionIDHash: string;
      userID: string;
      productID: string;
      expiresAt: string | null;
    }
  | { ok: false; code: string; message: string }
> {
  const bundleID = transactionPayloadValue(payload, "bundleId", "bundleID");
  if (bundleID !== config.bundleID) {
    return { ok: false, code: "transaction_bundle_id_mismatch", message: "Transaction bundleId does not match this app." };
  }

  const productID = transactionPayloadValue(payload, "productId", "productID");
  if (!productID || !proProductIDs.has(productID)) {
    return { ok: false, code: "unsupported_product", message: "Notification productId is not an AutoLedger Pro subscription." };
  }

  const originalTransactionID = transactionPayloadValue(payload, "originalTransactionId", "originalTransactionID");
  if (!originalTransactionID) {
    return { ok: false, code: "missing_original_transaction_id", message: "originalTransactionId is required." };
  }

  const originalTransactionIDHash = await sha256Hex(normalizeClientID(originalTransactionID) || originalTransactionID.trim());
  return {
    ok: true,
    transactionID: transactionPayloadValue(payload, "transactionId", "transactionID"),
    originalTransactionID,
    originalTransactionIDHash,
    userID: `appstore:${originalTransactionIDHash}`,
    productID,
    expiresAt: appleDate(payload.expiresDate)?.toISOString() ?? null
  };
}

function appStoreEntitlementStateForNotification(
  notificationType: string,
  subtype: string | null,
  transactionPayload: AppStoreTransactionPayload,
  renewalPayload: AppStoreRenewalPayload | null,
  now: Date = new Date()
): AppStoreEntitlementState {
  const type = normalizeAppStoreNotificationType(notificationType) ?? notificationType;
  const expiresAt = appleDate(transactionPayload.expiresDate);
  const expiresAtISO = expiresAt?.toISOString() ?? null;
  const graceExpiresAt = appleDate(renewalPayload?.gracePeriodExpiresDate);
  const graceExpiresAtISO = graceExpiresAt?.toISOString() ?? null;
  const revokedAt = appleDate(transactionPayload.revocationDate);

  if (revokedAt || type === "REVOKE") {
    return { status: "revoked", active: false, expiresAt: revokedAt?.toISOString() ?? expiresAtISO, reason: "transaction_revoked" };
  }
  if (type === "REFUND") {
    return { status: "refunded", active: false, expiresAt: expiresAtISO, reason: "transaction_refunded" };
  }
  if (type === "EXPIRED" || type === "GRACE_PERIOD_EXPIRED") {
    return { status: "expired", active: false, expiresAt: expiresAtISO, reason: "subscription_expired" };
  }
  if (type === "DID_FAIL_TO_RENEW") {
    if (graceExpiresAt && graceExpiresAt.getTime() > now.getTime()) {
      return { status: "grace_period", active: true, expiresAt: graceExpiresAtISO, reason: "grace_period_active" };
    }
    return { status: "billing_retry", active: false, expiresAt: expiresAtISO, reason: "billing_retry_without_grace" };
  }
  if (expiresAt && expiresAt.getTime() > now.getTime()) {
    return { status: "active", active: true, expiresAt: expiresAtISO, reason: "subscription_active" };
  }
  if (expiresAt) {
    return { status: "expired", active: false, expiresAt: expiresAtISO, reason: "transaction_expired" };
  }

  return {
    status: "ignored",
    active: false,
    expiresAt: null,
    reason: subtype ? `ignored_${type}_${subtype}` : `ignored_${type}`
  };
}

async function insertAppStoreNotificationEvent(env: Env, scope: AppStoreNotificationScope): Promise<boolean> {
  const now = new Date().toISOString();
  const result = await env.DB.prepare(
    `INSERT OR IGNORE INTO app_store_notification_events (
        notification_uuid, environment, bundle_id, app_apple_id, notification_type, subtype,
        version, signed_date, original_transaction_id_hash, user_id, product_id, transaction_id,
        transaction_expires_at, entitlement_status, raw_payload_hash, status, failure_reason,
        received_at, processed_at, created_at, updated_at
     ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
  )
    .bind(
      scope.notificationUUID,
      scope.environment,
      scope.bundleID,
      scope.appAppleID,
      scope.notificationType,
      scope.subtype,
      scope.version,
      scope.signedDate,
      scope.originalTransactionIDHash,
      scope.userID,
      scope.productID,
      scope.transactionID,
      scope.expiresAt,
      null,
      scope.rawPayloadHash,
      "received",
      null,
      now,
      null,
      now,
      now
    )
    .run();
  return (result.meta.changes ?? 0) > 0;
}

async function applyAppStoreEntitlementState(
  env: Env,
  scope: AppStoreNotificationScope,
  state: AppStoreEntitlementState
): Promise<void> {
  const now = new Date().toISOString();
  await env.DB.prepare(
    `INSERT INTO app_store_entitlements (
        user_id, original_transaction_id_hash, environment, bundle_id, product_id, status,
        expires_at, last_notification_uuid, last_notification_type, last_subtype,
        last_reason, created_at, updated_at
     ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
     ON CONFLICT(user_id) DO UPDATE SET
        original_transaction_id_hash = excluded.original_transaction_id_hash,
        environment = excluded.environment,
        bundle_id = excluded.bundle_id,
        product_id = excluded.product_id,
        status = excluded.status,
        expires_at = excluded.expires_at,
        last_notification_uuid = excluded.last_notification_uuid,
        last_notification_type = excluded.last_notification_type,
        last_subtype = excluded.last_subtype,
        last_reason = excluded.last_reason,
        updated_at = excluded.updated_at`
  )
    .bind(
      scope.userID,
      scope.originalTransactionIDHash,
      scope.environment,
      scope.bundleID,
      scope.productID,
      state.status,
      state.expiresAt,
      scope.notificationUUID,
      scope.notificationType,
      scope.subtype,
      state.reason,
      now,
      now
    )
    .run();

  await updateInboxTokensForEntitlementState(env, scope.userID, state, now);
}

async function updateInboxTokensForEntitlementState(
  env: Env,
  userID: string,
  state: AppStoreEntitlementState,
  now: string
): Promise<void> {
  if (state.status === "ignored") {
    return;
  }

  if (state.active) {
    await env.DB.prepare(
      `UPDATE pro_inbox_tokens
          SET status = 'active',
              pro_expires_at = COALESCE(?, pro_expires_at),
              updated_at = ?
        WHERE user_id = ?
          AND status IN ('active', 'expired', 'billing_retry', 'grace_period')`
    )
      .bind(state.expiresAt, now, userID)
      .run();
    return;
  }

  await env.DB.prepare(
    `UPDATE pro_inbox_tokens
        SET status = ?,
            pro_expires_at = COALESCE(?, pro_expires_at),
            updated_at = ?
      WHERE user_id = ?
        AND status = 'active'`
  )
    .bind(state.status, state.expiresAt, now, userID)
    .run();
}

async function markAppStoreNotificationEvent(
  env: Env,
  notificationUUID: string,
  status: "processed" | "failed",
  failureReason: string | null,
  state: AppStoreEntitlementState
): Promise<void> {
  const now = new Date().toISOString();
  await env.DB.prepare(
    `UPDATE app_store_notification_events
        SET status = ?,
            entitlement_status = ?,
            failure_reason = ?,
            processed_at = COALESCE(processed_at, ?),
            updated_at = ?
      WHERE notification_uuid = ?`
  )
    .bind(status, state.status, failureReason?.slice(0, 500) ?? null, now, now, notificationUUID)
    .run();
}

async function verifyAppStoreEntitlement(env: Env, signedTransactionInfo: string | undefined): Promise<EntitlementVerificationResult> {
  const trimmedJWS = signedTransactionInfo?.trim() ?? "";
  if (!trimmedJWS) {
    return { allowed: false, reason: "missing_signed_transaction" };
  }

  const config = appStoreServerAPIConfig(env);
  if (!config) {
    return { allowed: false, reason: "app_store_server_api_unconfigured" };
  }

  const clientPayload = decodeJWSPayload<AppStoreTransactionPayload>(trimmedJWS);
  if (!clientPayload) {
    return { allowed: false, reason: "invalid_signed_transaction" };
  }
  const transactionID = transactionPayloadValue(clientPayload, "transactionId", "transactionID");
  if (!transactionID) {
    return { allowed: false, reason: "missing_transaction_id" };
  }

  const jwt = await appStoreServerJWT(config);
  const lookupEnvironments = appStoreServerLookupEnvironments(config.environment, clientPayload);
  let response: Response | null = null;
  for (const environment of lookupEnvironments) {
    response = await fetch(`${appStoreServerAPIHost(environment)}/inApps/v1/transactions/${encodeURIComponent(transactionID)}`, {
      headers: {
        authorization: `Bearer ${jwt}`,
        accept: "application/json"
      }
    });
    if (response.status !== 404) {
      break;
    }
  }

  if (!response?.ok) {
    return {
      allowed: false,
      reason: `app_store_server_api_status_${response?.status ?? 503}`
    };
  }

  const body = await response.json().catch(() => ({})) as Partial<{ signedTransactionInfo: string }>;
  const serverPayload = decodeJWSPayload<AppStoreTransactionPayload>(body.signedTransactionInfo ?? "");
  if (!serverPayload) {
    return { allowed: false, reason: "invalid_app_store_response" };
  }
  return validateAppStoreTransactionPayload(config, serverPayload);
}

function validateAppStoreTransactionPayload(
  config: Pick<AppStoreServerAPIConfig, "bundleID">,
  payload: AppStoreTransactionPayload,
  now: Date = new Date()
): EntitlementVerificationResult {
  const bundleID = transactionPayloadValue(payload, "bundleId", "bundleID");
  if (bundleID !== config.bundleID) {
    return { allowed: false, reason: "bundle_id_mismatch" };
  }

  const productID = transactionPayloadValue(payload, "productId", "productID");
  if (!productID || !proProductIDs.has(productID)) {
    return { allowed: false, reason: "unsupported_product" };
  }

  if (payload.revocationDate !== undefined && payload.revocationDate !== null) {
    return { allowed: false, reason: "transaction_revoked" };
  }

  const expiresAt = appleDate(payload.expiresDate);
  if (!expiresAt) {
    return { allowed: false, reason: "missing_expiration" };
  }
  if (expiresAt.getTime() <= now.getTime()) {
    return {
      allowed: false,
      reason: "subscription_expired",
      expiresAt: expiresAt.toISOString(),
      productID
    };
  }

  const originalTransactionID = transactionPayloadValue(payload, "originalTransactionId", "originalTransactionID") ?? undefined;
  return {
    allowed: true,
    expiresAt: expiresAt.toISOString(),
    originalTransactionID,
    productID
  };
}

function appStoreServerAPIConfig(env: Env): AppStoreServerAPIConfig | null {
  const runtime = appStoreRuntimeEnv(env);
  const issuerID = runtime.APP_STORE_CONNECT_ISSUER_ID?.trim() ?? "";
  const keyID = runtime.APP_STORE_CONNECT_KEY_ID?.trim() ?? "";
  const privateKey = runtime.APP_STORE_CONNECT_PRIVATE_KEY?.trim() ?? "";
  const { bundleID, environment } = appStoreRuntimeConfig(env);
  if (!issuerID || !keyID || !privateKey || !bundleID) {
    return null;
  }
  return { issuerID, keyID, privateKey, bundleID, environment };
}

function appStoreRuntimeConfig(env: Env): Pick<AppStoreServerAPIConfig, "bundleID" | "environment"> {
  const runtime = appStoreRuntimeEnv(env);
  const bundleID = runtime.APP_STORE_BUNDLE_ID?.trim() || "top.darkrio326.AutoLedger";
  const environment = runtime.APP_STORE_SERVER_ENVIRONMENT?.trim() === "sandbox" ? "sandbox" : "production";
  return { bundleID, environment };
}

function appStoreRuntimeEnv(env: Env): Env & {
  APP_STORE_CONNECT_ISSUER_ID?: string;
  APP_STORE_CONNECT_KEY_ID?: string;
  APP_STORE_CONNECT_PRIVATE_KEY?: string;
  APP_STORE_BUNDLE_ID?: string;
  APP_STORE_SERVER_ENVIRONMENT?: string;
  ALLOW_UNVERIFIED_APP_STORE_NOTIFICATIONS?: string;
  APP_STORE_NOTIFICATION_ROOT_CERT_PEM?: string;
  APP_STORE_NOTIFICATION_HISTORY_LOOKBACK_HOURS?: string;
  APP_STORE_NOTIFICATION_HISTORY_MAX_PAGES?: string;
} {
  return env as Env & {
    APP_STORE_CONNECT_ISSUER_ID?: string;
    APP_STORE_CONNECT_KEY_ID?: string;
    APP_STORE_CONNECT_PRIVATE_KEY?: string;
    APP_STORE_BUNDLE_ID?: string;
    APP_STORE_SERVER_ENVIRONMENT?: string;
    ALLOW_UNVERIFIED_APP_STORE_NOTIFICATIONS?: string;
    APP_STORE_NOTIFICATION_ROOT_CERT_PEM?: string;
    APP_STORE_NOTIFICATION_HISTORY_LOOKBACK_HOURS?: string;
    APP_STORE_NOTIFICATION_HISTORY_MAX_PAGES?: string;
  };
}

function appStoreNotificationRootCertificates(env: Env): string[] {
  return pemCertificates(appStoreRuntimeEnv(env).APP_STORE_NOTIFICATION_ROOT_CERT_PEM ?? "");
}

function pemCertificates(value: string): string[] {
  const matches = value.match(/-----BEGIN CERTIFICATE-----[\s\S]+?-----END CERTIFICATE-----/g);
  return matches?.map((certificate) => certificate.trim()) ?? [];
}

async function appStoreServerJWT(config: AppStoreServerAPIConfig): Promise<string> {
  const key = await importPKCS8(config.privateKey.replace(/\\n/g, "\n"), "ES256");
  return new SignJWT({ bid: config.bundleID })
    .setProtectedHeader({ alg: "ES256", kid: config.keyID, typ: "JWT" })
    .setIssuer(config.issuerID)
    .setAudience("appstoreconnect-v1")
    .setIssuedAt()
    .setExpirationTime("5m")
    .sign(key);
}

function appStoreServerAPIHost(environment: AppStoreServerEnvironment): string {
  return environment === "sandbox"
    ? "https://api.storekit-sandbox.itunes.apple.com"
    : "https://api.storekit.itunes.apple.com";
}

function appStoreServerLookupEnvironments(
  configuredEnvironment: AppStoreServerEnvironment,
  transactionPayload: AppStoreTransactionPayload
): AppStoreServerEnvironment[] {
  const rawEnvironment = transactionPayload.environment?.trim().toLowerCase();
  if (rawEnvironment === "sandbox" || rawEnvironment === "production") {
    return [rawEnvironment];
  }

  const fallbackEnvironment: AppStoreServerEnvironment =
    configuredEnvironment === "production" ? "sandbox" : "production";
  return [configuredEnvironment, fallbackEnvironment];
}

function appStoreNotificationHistoryLookbackHours(env: Env): number {
  const raw = appStoreRuntimeEnv(env).APP_STORE_NOTIFICATION_HISTORY_LOOKBACK_HOURS?.trim() ?? "";
  const parsed = Number.parseInt(raw, 10);
  if (!Number.isFinite(parsed)) {
    return 72;
  }
  return Math.min(168, Math.max(1, parsed));
}

function appStoreNotificationHistoryMaxPages(env: Env): number {
  const raw = appStoreRuntimeEnv(env).APP_STORE_NOTIFICATION_HISTORY_MAX_PAGES?.trim() ?? "";
  const parsed = Number.parseInt(raw, 10);
  if (!Number.isFinite(parsed)) {
    return 5;
  }
  return Math.min(20, Math.max(1, parsed));
}

function appStoreNotificationHistoryRequestBody(
  now: Date = new Date(),
  lookbackHours = 72
): AppStoreNotificationHistoryRequest {
  const safeHours = Math.min(168, Math.max(1, Math.floor(lookbackHours)));
  const endDate = now.getTime();
  const startDate = endDate - safeHours * 60 * 60 * 1000;
  return { startDate, endDate, onlyFailures: true };
}

function appStoreNotificationHistoryEndpoint(
  config: Pick<AppStoreServerAPIConfig, "environment">,
  paginationToken: string | null = null
): string {
  const url = new URL(`${appStoreServerAPIHost(config.environment)}/inApps/v1/notifications/history`);
  if (paginationToken) {
    url.searchParams.set("paginationToken", paginationToken);
  }
  return url.toString();
}

async function collectAppStoreNotificationHistorySignedPayloads(
  config: Pick<AppStoreServerAPIConfig, "environment">,
  jwt: string,
  requestBody: AppStoreNotificationHistoryRequest,
  fetcher: (input: string, init: RequestInit) => Promise<Response> = fetch,
  maxPages = 5
): Promise<AppStoreNotificationHistoryCollectResult> {
  const signedPayloads: string[] = [];
  let paginationToken: string | null = null;
  let pages = 0;
  let hasMore = false;
  const safeMaxPages = Math.min(20, Math.max(1, Math.floor(maxPages)));

  do {
    const response = await fetcher(appStoreNotificationHistoryEndpoint(config, paginationToken), {
      method: "POST",
      headers: {
        authorization: `Bearer ${jwt}`,
        accept: "application/json",
        "content-type": "application/json"
      },
      body: JSON.stringify(requestBody)
    });
    pages += 1;

    if (!response.ok) {
      throw new Error(`App Store notification history request failed with HTTP ${response.status}`);
    }

    const body = await response.json().catch(() => ({})) as AppStoreNotificationHistoryResponse;
    for (const item of body.notificationHistory ?? []) {
      const signedPayload = item.signedPayload?.trim() ?? "";
      if (signedPayload) {
        signedPayloads.push(signedPayload);
      }
    }

    paginationToken = typeof body.paginationToken === "string" && body.paginationToken.trim()
      ? body.paginationToken.trim()
      : null;
    hasMore = body.hasMore === true && paginationToken !== null;
  } while (hasMore && pages < safeMaxPages);

  return { signedPayloads, pages, hasMore };
}

async function processAppStoreNotificationHistory(
  env: Env,
  now: Date = new Date(),
  fetcher: (input: string, init: RequestInit) => Promise<Response> = fetch
): Promise<AppStoreNotificationHistoryProcessResult> {
  const config = appStoreServerAPIConfig(env);
  if (!config) {
    return {
      ok: false,
      skippedReason: "app_store_server_api_unconfigured",
      collected: 0,
      processed: 0,
      duplicates: 0,
      failed: 0,
      pages: 0,
      hasMore: false
    };
  }

  const jwt = await appStoreServerJWT(config);
  const requestBody = appStoreNotificationHistoryRequestBody(now, appStoreNotificationHistoryLookbackHours(env));
  const collected = await collectAppStoreNotificationHistorySignedPayloads(
    config,
    jwt,
    requestBody,
    fetcher,
    appStoreNotificationHistoryMaxPages(env)
  );

  let processed = 0;
  let duplicates = 0;
  let failed = 0;
  for (const signedPayload of collected.signedPayloads) {
    const result = await processAppStoreServerNotificationPayload(env, signedPayload);
    if (!result.ok) {
      failed += 1;
      continue;
    }
    if (result.duplicate) {
      duplicates += 1;
    } else {
      processed += 1;
    }
  }

  return {
    ok: failed === 0,
    collected: collected.signedPayloads.length,
    processed,
    duplicates,
    failed,
    pages: collected.pages,
    hasMore: collected.hasMore
  };
}

function decodeJWSPayload<T>(jws: string): T | null {
  const payload = jws.split(".")[1];
  if (!payload) {
    return null;
  }
  try {
    const base64 = payload.replace(/-/g, "+").replace(/_/g, "/");
    const padded = base64.padEnd(Math.ceil(base64.length / 4) * 4, "=");
    const jsonText = atob(padded);
    return JSON.parse(jsonText) as T;
  } catch {
    return null;
  }
}

function transactionPayloadValue<T extends string>(
  payload: AppStoreTransactionPayload,
  primary: keyof AppStoreTransactionPayload,
  fallback: keyof AppStoreTransactionPayload
): T | null {
  const value = payload[primary] ?? payload[fallback];
  return typeof value === "string" && value.trim() ? value.trim() as T : null;
}

function stringPayloadValue<T extends object>(
  payload: T,
  primary: keyof T,
  fallback?: keyof T
): string | null {
  const value = payload[primary] ?? (fallback ? payload[fallback] : undefined);
  return typeof value === "string" && value.trim() ? value.trim() : null;
}

function normalizeAppStoreNotificationType(value: string | undefined): string | null {
  const normalized = value?.trim().toUpperCase().replace(/[^A-Z0-9_]/g, "") ?? "";
  return normalized || null;
}

function normalizeAppStoreEnvironment(value: string | undefined): AppStoreServerEnvironment {
  return value?.trim().toLowerCase() === "sandbox" ? "sandbox" : "production";
}

async function selectTrustedRootCertificate(
  chain: ParsedCertificate[],
  rootCertificatePEMs: string[]
): Promise<ParsedCertificate | null> {
  const last = chain[chain.length - 1];
  if (!last) {
    return null;
  }

  for (const rootPEM of rootCertificatePEMs) {
    const root = parseCertificate(pemCertificateToDER(rootPEM));
    if (certificateDERKey(root) === certificateDERKey(last)) {
      return root;
    }
    if (await verifyCertificateSignature(last, root)) {
      return root;
    }
  }
  return null;
}

async function verifyCertificateSignature(certificate: ParsedCertificate, issuer: ParsedCertificate): Promise<boolean> {
  const config = certificateSignatureVerificationConfig(certificate.signatureAlgorithmOID);
  if (!config) {
    return false;
  }

  const key = await importX509(issuer.pem, config.importAlgorithm);
  const signature = config.type === "ecdsa"
    ? ecdsaDERSignatureToRaw(certificate.signatureBytes, config.coordinateLength)
    : certificate.signatureBytes;
  if (!signature) {
    return false;
  }
  return crypto.subtle.verify(
    config.verifyAlgorithm,
    key,
    arrayBufferFromBytes(signature),
    arrayBufferFromBytes(certificate.tbsBytes)
  );
}

function certificateSignatureVerificationConfig(oid: string): null | {
  type: "ecdsa" | "rsa";
  importAlgorithm: "ES256" | "ES384" | "RS256" | "RS384";
  verifyAlgorithm: AlgorithmIdentifier | RsaPssParams | EcdsaParams;
  coordinateLength: number;
} {
  switch (oid) {
    case "1.2.840.10045.4.3.2":
      return {
        type: "ecdsa",
        importAlgorithm: "ES256",
        verifyAlgorithm: { name: "ECDSA", hash: "SHA-256" },
        coordinateLength: 32
      };
    case "1.2.840.10045.4.3.3":
      return {
        type: "ecdsa",
        importAlgorithm: "ES384",
        verifyAlgorithm: { name: "ECDSA", hash: "SHA-384" },
        coordinateLength: 48
      };
    case "1.2.840.113549.1.1.11":
      return {
        type: "rsa",
        importAlgorithm: "RS256",
        verifyAlgorithm: "RSASSA-PKCS1-v1_5",
        coordinateLength: 0
      };
    case "1.2.840.113549.1.1.12":
      return {
        type: "rsa",
        importAlgorithm: "RS384",
        verifyAlgorithm: "RSASSA-PKCS1-v1_5",
        coordinateLength: 0
      };
    default:
      return null;
  }
}

function certificateIsCurrentlyValid(certificate: ParsedCertificate, now: Date): boolean {
  const time = now.getTime();
  if (certificate.notBefore && certificate.notBefore.getTime() > time) {
    return false;
  }
  if (certificate.notAfter && certificate.notAfter.getTime() < time) {
    return false;
  }
  return true;
}

function parseCertificate(derBytes: Uint8Array): ParsedCertificate {
  const certificate = readDERElement(derBytes, 0);
  if (certificate.tag !== 0x30 || certificate.end !== derBytes.length) {
    throw new Error("Certificate must be a DER sequence.");
  }
  const certificateChildren = readDERChildren(derBytes, certificate);
  const tbs = certificateChildren[0];
  const signatureAlgorithm = certificateChildren[1];
  const signatureValue = certificateChildren[2];
  if (!tbs || !signatureAlgorithm || !signatureValue || tbs.tag !== 0x30 || signatureAlgorithm.tag !== 0x30 || signatureValue.tag !== 0x03) {
    throw new Error("Certificate is missing TBS, signature algorithm, or signature value.");
  }

  const algorithmOID = parseAlgorithmOID(derBytes, signatureAlgorithm);
  const signatureBytes = parseBitStringBytes(derBytes, signatureValue);
  const validity = parseCertificateValidity(derBytes, tbs);
  return {
    derBytes,
    pem: derBytesToPEM(derBytes),
    tbsBytes: derBytes.slice(tbs.headerStart, tbs.end),
    signatureAlgorithmOID: algorithmOID,
    signatureBytes,
    notBefore: validity.notBefore,
    notAfter: validity.notAfter
  };
}

function parseCertificateValidity(bytes: Uint8Array, tbs: DERElement): { notBefore: Date | null; notAfter: Date | null } {
  const children = readDERChildren(bytes, tbs);
  const hasVersion = children[0]?.tag === 0xa0;
  const validity = children[hasVersion ? 4 : 3];
  if (!validity || validity.tag !== 0x30) {
    return { notBefore: null, notAfter: null };
  }
  const validityChildren = readDERChildren(bytes, validity);
  return {
    notBefore: validityChildren[0] ? parseDERTime(bytes, validityChildren[0]) : null,
    notAfter: validityChildren[1] ? parseDERTime(bytes, validityChildren[1]) : null
  };
}

type DERElement = {
  tag: number;
  headerStart: number;
  contentStart: number;
  contentLength: number;
  end: number;
};

function readDERElement(bytes: Uint8Array, offset: number): DERElement {
  if (offset >= bytes.length) {
    throw new Error("Unexpected end of DER data.");
  }
  const tag = bytes[offset]!;
  const firstLengthByte = bytes[offset + 1];
  if (firstLengthByte === undefined) {
    throw new Error("DER length is missing.");
  }

  let length = firstLengthByte;
  let contentStart = offset + 2;
  if ((firstLengthByte & 0x80) !== 0) {
    const lengthByteCount = firstLengthByte & 0x7f;
    if (lengthByteCount === 0 || lengthByteCount > 4) {
      throw new Error("Unsupported DER length.");
    }
    length = 0;
    contentStart = offset + 2 + lengthByteCount;
    for (let index = 0; index < lengthByteCount; index += 1) {
      const value = bytes[offset + 2 + index];
      if (value === undefined) {
        throw new Error("DER length exceeds input.");
      }
      length = (length << 8) | value;
    }
  }

  const end = contentStart + length;
  if (end > bytes.length) {
    throw new Error("DER element exceeds input length.");
  }
  return { tag, headerStart: offset, contentStart, contentLength: length, end };
}

function readDERChildren(bytes: Uint8Array, parent: DERElement): DERElement[] {
  const children: DERElement[] = [];
  let offset = parent.contentStart;
  while (offset < parent.end) {
    const child = readDERElement(bytes, offset);
    children.push(child);
    offset = child.end;
  }
  if (offset !== parent.end) {
    throw new Error("DER children do not align with parent length.");
  }
  return children;
}

function parseAlgorithmOID(bytes: Uint8Array, algorithm: DERElement): string {
  const oidElement = readDERChildren(bytes, algorithm)[0];
  if (!oidElement || oidElement.tag !== 0x06) {
    throw new Error("DER algorithm identifier is missing an OID.");
  }
  return parseOID(bytes.slice(oidElement.contentStart, oidElement.end));
}

function parseOID(bytes: Uint8Array): string {
  const first = bytes[0];
  if (first === undefined) {
    throw new Error("OID is empty.");
  }
  const arcs = [Math.floor(first / 40), first % 40];
  let value = 0;
  for (const byte of bytes.slice(1)) {
    value = (value << 7) | (byte & 0x7f);
    if ((byte & 0x80) === 0) {
      arcs.push(value);
      value = 0;
    }
  }
  return arcs.join(".");
}

function parseBitStringBytes(bytes: Uint8Array, element: DERElement): Uint8Array {
  const unusedBits = bytes[element.contentStart];
  if (unusedBits !== 0) {
    throw new Error("Only zero-unused-bit DER BIT STRING values are supported.");
  }
  return bytes.slice(element.contentStart + 1, element.end);
}

function parseDERTime(bytes: Uint8Array, element: DERElement): Date | null {
  if (element.tag !== 0x17 && element.tag !== 0x18) {
    return null;
  }
  const text = new TextDecoder().decode(bytes.slice(element.contentStart, element.end));
  const match = element.tag === 0x17
    ? text.match(/^(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})Z$/)
    : text.match(/^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})Z$/);
  if (!match) {
    return null;
  }
  const yearText = match[1]!;
  const year = element.tag === 0x17
    ? Number.parseInt(yearText, 10) + (Number.parseInt(yearText, 10) >= 50 ? 1900 : 2000)
    : Number.parseInt(yearText, 10);
  const month = Number.parseInt(match[2]!, 10) - 1;
  const day = Number.parseInt(match[3]!, 10);
  const hour = Number.parseInt(match[4]!, 10);
  const minute = Number.parseInt(match[5]!, 10);
  const second = Number.parseInt(match[6]!, 10);
  return new Date(Date.UTC(year, month, day, hour, minute, second));
}

function ecdsaDERSignatureToRaw(signature: Uint8Array, coordinateLength: number): Uint8Array | null {
  const sequence = readDERElement(signature, 0);
  if (sequence.tag !== 0x30 || sequence.end !== signature.length) {
    return null;
  }
  const integers = readDERChildren(signature, sequence);
  const r = integers[0] ? derIntegerToFixedWidth(signature, integers[0], coordinateLength) : null;
  const s = integers[1] ? derIntegerToFixedWidth(signature, integers[1], coordinateLength) : null;
  if (!r || !s) {
    return null;
  }
  const raw = new Uint8Array(coordinateLength * 2);
  raw.set(r, 0);
  raw.set(s, coordinateLength);
  return raw;
}

function derIntegerToFixedWidth(bytes: Uint8Array, element: DERElement, width: number): Uint8Array | null {
  if (element.tag !== 0x02) {
    return null;
  }
  let value = bytes.slice(element.contentStart, element.end);
  while (value.length > 0 && value[0] === 0) {
    value = value.slice(1);
  }
  if (value.length > width) {
    return null;
  }
  const output = new Uint8Array(width);
  output.set(value, width - value.length);
  return output;
}

function pemCertificateToDER(pem: string): Uint8Array {
  const base64 = pem
    .replace(/-----BEGIN CERTIFICATE-----/g, "")
    .replace(/-----END CERTIFICATE-----/g, "")
    .replace(/\s+/g, "");
  return base64ToBytes(base64);
}

function derBytesToPEM(bytes: Uint8Array): string {
  const base64 = bytesToBase64(bytes);
  const lines = base64.match(/.{1,64}/g) ?? [];
  return `-----BEGIN CERTIFICATE-----\n${lines.join("\n")}\n-----END CERTIFICATE-----`;
}

function base64ToBytes(value: string): Uint8Array {
  const binary = atob(value);
  const output = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) {
    output[index] = binary.charCodeAt(index);
  }
  return output;
}

function bytesToBase64(bytes: Uint8Array): string {
  let binary = "";
  for (let index = 0; index < bytes.length; index += 0x8000) {
    binary += String.fromCharCode(...bytes.slice(index, index + 0x8000));
  }
  return btoa(binary);
}

function certificateDERKey(certificate: ParsedCertificate): string {
  return bytesToBase64(certificate.derBytes);
}

function arrayBufferFromBytes(bytes: Uint8Array): ArrayBuffer {
  const copy = new Uint8Array(bytes.length);
  copy.set(bytes);
  return copy.buffer as ArrayBuffer;
}

function appleDate(value: number | string | null | undefined): Date | null {
  if (typeof value === "number" && Number.isFinite(value)) {
    return new Date(value);
  }
  if (typeof value === "string" && value.trim()) {
    const numeric = Number(value);
    if (Number.isFinite(numeric)) {
      return new Date(numeric);
    }
    const parsed = Date.parse(value);
    if (Number.isFinite(parsed)) {
      return new Date(parsed);
    }
  }
  return null;
}

async function appStoreUserID(originalTransactionID: string): Promise<string> {
  const normalized = normalizeClientID(originalTransactionID);
  const stableValue = normalized || originalTransactionID.trim();
  return `appstore:${await sha256Hex(stableValue)}`;
}

function allowsUnverifiedTokenClaim(env: Env): boolean {
  const runtime = env as Env & { ALLOW_UNVERIFIED_TOKEN_CLAIM?: string };
  return ["1", "true", "yes", "on"].includes((runtime.ALLOW_UNVERIFIED_TOKEN_CLAIM ?? "").trim().toLowerCase());
}

function allowsUnsignedAppStoreNotifications(env: Env): boolean {
  const runtime = appStoreRuntimeEnv(env);
  return ["1", "true", "yes", "on"].includes(
    (runtime.ALLOW_UNVERIFIED_APP_STORE_NOTIFICATIONS ?? "").trim().toLowerCase()
  );
}

function unverifiedTokenExpirationDate(env: Env, now: Date = new Date()): Date {
  const runtime = env as Env & { UNVERIFIED_TOKEN_TTL_DAYS?: string };
  const parsed = Number.parseInt(runtime.UNVERIFIED_TOKEN_TTL_DAYS ?? "7", 10);
  const days = Number.isFinite(parsed) && parsed > 0 ? Math.min(parsed, 30) : 7;
  return new Date(now.getTime() + days * 24 * 60 * 60 * 1000);
}

async function loadActiveRoutingToken(env: Env, tokenHash: string): Promise<TokenRow | null> {
  const row = await env.DB.prepare(
    `SELECT token_hash, access_token_hash, user_id, inbox_email, status, pro_expires_at
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

async function loadActiveAccessToken(env: Env, accessTokenHash: string): Promise<TokenRow | null> {
  const row = await env.DB.prepare(
    `SELECT token_hash, access_token_hash, user_id, inbox_email, status, pro_expires_at
       FROM pro_inbox_tokens
      WHERE access_token_hash = ?
         OR (access_token_hash IS NULL AND token_hash = ?)`
  )
    .bind(accessTokenHash, accessTokenHash)
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
        AND status IN ('stored', 'notified')
      ORDER BY received_at DESC
      LIMIT 100`
  )
    .bind(tokenHash)
    .all<CandidateRow>();

  return result.results ?? [];
}

function isVisibleInboxCandidateStatus(status: string): boolean {
  return status === "stored" || status === "notified";
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
  const normalizedID = normalizeCandidateID(id);
  return env.DB.prepare(
    `SELECT *
       FROM cloud_hotel_folio_candidates
      WHERE id = ?
        AND token_hash = ?
      LIMIT 1`
  )
    .bind(normalizedID, tokenHash)
    .first<CandidateRow>();
}

function normalizeCandidateID(value: string): string {
  return value.trim().toLowerCase();
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

function candidateListEnvelope<T>(candidates: T[], inboxEmail: string): {
  candidates: T[];
  inboxEmail: string;
} {
  return { candidates, inboxEmail };
}

function candidatePDFInputs(
  parsed: { attachments: Array<{ filename?: string | null; mimeType?: string | null; content?: unknown }>; text?: string | null; html?: string | null },
  subject: string | null
): CandidatePDFInput[] {
  const pdfAttachments = parsed.attachments
    .filter((attachment) => isPDFAttachment(attachment))
    .map((attachment): CandidatePDFInput => ({
      fileName: attachment.filename ?? "folio.pdf",
      bytes: attachmentContentBytes(attachment),
      source: "attachment"
    }))
    .filter((input) => input.bytes.byteLength > 0);

  if (pdfAttachments.length > 0) {
    return pdfAttachments;
  }

  const bodyText = emailBodyText(parsed);
  if (!bodyText) {
    return [];
  }

  return [{
    fileName: "email-body-folio.pdf",
    bytes: makeEmailBodyPDF(bodyText, subject ?? "Hotel folio email body"),
    source: "emailBody"
  }];
}

function isPDFAttachment(attachment: { filename?: string | null; mimeType?: string | null }): boolean {
  const mimeType = attachment.mimeType?.toLowerCase() ?? "";
  const fileName = attachment.filename?.toLowerCase() ?? "";
  return pdfMimeTypes.has(mimeType) || fileName.endsWith(".pdf");
}

function emailBodyText(parsed: { text?: string | null; html?: string | null }): string | null {
  const text = parsed.text?.trim();
  if (text) {
    return limitBodyText(text);
  }

  const html = parsed.html?.trim();
  if (!html) {
    return null;
  }

  const stripped = htmlToText(html).trim();
  return stripped ? limitBodyText(stripped) : null;
}

function htmlToText(html: string): string {
  return decodeHTMLEntities(
    html
      .replace(/<\s*br\s*\/?\s*>/gi, "\n")
      .replace(/<\/\s*(p|div|tr|li|table|h[1-6])\s*>/gi, "\n")
      .replace(/<[^>]+>/g, " ")
      .replace(/[ \t]{2,}/g, " ")
      .replace(/\n{3,}/g, "\n\n")
  );
}

function decodeHTMLEntities(value: string): string {
  return value
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, "\"")
    .replace(/&#39;/g, "'");
}

function limitBodyText(value: string): string {
  return value.trim().slice(0, 12_000);
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

function makeEmailBodyPDF(text: string, title: string): Uint8Array {
  const lines = normalizedPDFLines(text, title);
  let nextCID = 1;
  const mappings: string[] = [];
  let content = "BT /F1 11 Tf 50 760 Td 14 TL\n";

  for (const line of lines) {
    if (line.length === 0) {
      content += "T*\n";
      continue;
    }

    let run = "";
    for (const character of Array.from(line)) {
      const cid = nextCID++;
      run += fourDigitHex(cid);
      mappings.push(`<${fourDigitHex(cid)}> <${utf16BEHex(character)}>`);
    }
    content += `<${run}> Tj T*\n`;
  }
  content += "ET";

  const cmap = makeToUnicodeCMap(mappings);
  const objects = [
    "<< /Type /Catalog /Pages 2 0 R >>",
    "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 4 0 R >> >> /Contents 8 0 R >>",
    "<< /Type /Font /Subtype /Type0 /BaseFont /Helvetica /Encoding /Identity-H /DescendantFonts [5 0 R] /ToUnicode 7 0 R >>",
    "<< /Type /Font /Subtype /CIDFontType2 /BaseFont /Helvetica /CIDSystemInfo << /Registry (Adobe) /Ordering (Identity) /Supplement 0 >> /FontDescriptor 6 0 R /DW 600 >>",
    "<< /Type /FontDescriptor /FontName /Helvetica /Flags 32 /FontBBox [-166 -225 1000 931] /ItalicAngle 0 /Ascent 931 /Descent -225 /CapHeight 718 /StemV 80 >>",
    streamObject(cmap),
    streamObject(content)
  ];
  return makePDF(objects);
}

function normalizedPDFLines(text: string, title: string): string[] {
  const fallback = title.trim() || "Hotel folio email body";
  const capped = (text.trim() || fallback)
    .replace(/\r\n/g, "\n")
    .replace(/\r/g, "\n")
    .slice(0, 12_000);
  return capped.split("\n").flatMap((line) => wrapPDFLine(line, 72));
}

function wrapPDFLine(line: string, maxLength: number): string[] {
  const characters = Array.from(line);
  if (characters.length <= maxLength) {
    return [line];
  }

  const wrapped: string[] = [];
  for (let index = 0; index < characters.length; index += maxLength) {
    wrapped.push(characters.slice(index, index + maxLength).join(""));
  }
  return wrapped;
}

function makeToUnicodeCMap(mappings: string[]): string {
  const chunks: string[] = [];
  for (let index = 0; index < mappings.length; index += 100) {
    const chunk = mappings.slice(index, index + 100);
    chunks.push(`${chunk.length} beginbfchar\n${chunk.join("\n")}\nendbfchar`);
  }
  return `/CIDInit /ProcSet findresource begin
12 dict begin
begincmap
/CIDSystemInfo << /Registry (Adobe) /Ordering (UCS) /Supplement 0 >> def
/CMapName /AutoLedgerUnicode def
/CMapType 2 def
1 begincodespacerange
<0000> <FFFF>
endcodespacerange
${chunks.join("\n")}
endcmap
CMapName currentdict /CMap defineresource pop
end
end`;
}

function streamObject(content: string): string {
  return `<< /Length ${encoder.encode(content).byteLength} >>\nstream\n${content}\nendstream`;
}

function makePDF(objects: string[]): Uint8Array {
  let pdf = "%PDF-1.7\n";
  const offsets = [0];
  for (const [index, object] of objects.entries()) {
    offsets.push(encoder.encode(pdf).byteLength);
    pdf += `${index + 1} 0 obj\n${object}\nendobj\n`;
  }

  const xrefOffset = encoder.encode(pdf).byteLength;
  pdf += `xref\n0 ${objects.length + 1}\n0000000000 65535 f \n`;
  for (const offset of offsets.slice(1)) {
    pdf += `${String(offset).padStart(10, "0")} 00000 n \n`;
  }
  pdf += `trailer << /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n${xrefOffset}\n%%EOF\n`;
  return encoder.encode(pdf);
}

function fourDigitHex(value: number): string {
  return value.toString(16).padStart(4, "0").toUpperCase();
}

function utf16BEHex(value: string): string {
  const units: number[] = [];
  for (let index = 0; index < value.length; index++) {
    units.push(value.charCodeAt(index));
  }
  return units.map(fourDigitHex).join("");
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
  makeInboxCredentialPair,
  normalizeDeviceToken,
  normalizeAPNSEnvironment,
  redactMetadata,
  safeFileName,
  normalizeCandidateID,
  candidatePDFInputs,
  emailBodyText,
  makeEmailBodyPDF,
  isPDFAttachment,
  isVisibleInboxCandidateStatus,
  candidateDTO,
  candidateListEnvelope,
  makeAPNSNotificationBody,
  notificationPayloadFromQueueBody,
  retentionDate,
  allowsUnverifiedTokenClaim,
  unverifiedTokenExpirationDate,
  decodeJWSPayload,
  validateAppStoreTransactionPayload,
  decodeAppStoreServerNotificationPayload,
  prepareAppStoreNotification,
  appStoreEntitlementStateForNotification,
  allowsUnsignedAppStoreNotifications,
  normalizeAppStoreNotificationType,
  normalizeAppStoreEnvironment,
  appStoreServerLookupEnvironments,
  appStoreNotificationTransactionScope,
  appStoreServerAPIHost,
  appStoreNotificationHistoryRequestBody,
  appStoreNotificationHistoryEndpoint,
  collectAppStoreNotificationHistorySignedPayloads,
  processAppStoreNotificationHistory,
  appStoreUserID,
  stableMerchantHash,
  sha256Hex
};
