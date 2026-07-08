type APIError = {
  error: {
    code: string;
    message: string;
  };
};

type AnalyticsEventInput = {
  eventName?: unknown;
  event_name?: unknown;
  appVersion?: unknown;
  app_version?: unknown;
  buildNumber?: unknown;
  build_number?: unknown;
  osMajor?: unknown;
  os_major?: unknown;
  deviceClass?: unknown;
  device_class?: unknown;
  payload?: unknown;
};

type AnalyticsRequestBody = {
  schemaVersion?: unknown;
  app?: unknown;
  events?: unknown;
};

type ValidAnalyticsEvent = {
  eventName: string;
  eventID: string | null;
  appVersion: string | null;
  buildNumber: string | null;
  osMajor: string | null;
  deviceClass: string | null;
  payload: Record<string, string | number | boolean | null>;
};

type AnalyticsValidationErrorCode =
  | "analytics_invalid_body"
  | "analytics_invalid_app"
  | "analytics_invalid_event"
  | "analytics_forbidden_field"
  | "analytics_unsupported_field"
  | "analytics_payload_too_large";

class AnalyticsValidationError extends Error {
  constructor(
    readonly code: AnalyticsValidationErrorCode,
    message: string,
    readonly status: number = 400
  ) {
    super(message);
  }
}

const maxRequestBytes = 32 * 1024;
const maxEventsPerRequest = 25;
const allowedFieldsByEventName: Record<string, Set<string>> = {
  al_perf_app_launch: new Set([
    "event_id",
    "app_version",
    "build_number",
    "os_major",
    "device_class",
    "launch_type",
    "duration_ms_bucket",
    "result",
    "error_code"
  ]),
  al_import_flow_started: new Set([
    "event_id",
    "app_version",
    "flow_type",
    "input_type",
    "entry_surface",
    "is_pro_surface",
    "start_status"
  ]),
  al_import_flow_completed: new Set([
    "event_id",
    "app_version",
    "flow_type",
    "input_type",
    "status",
    "duration_ms_bucket",
    "retry_count_bucket",
    "error_code"
  ]),
  al_confirmation_state: new Set([
    "event_id",
    "app_version",
    "flow_type",
    "required_field_count_bucket",
    "edited_field_count_bucket",
    "confirm_status",
    "discard_reason_code"
  ]),
  al_currency_lookup_status: new Set([
    "event_id",
    "app_version",
    "lookup_context",
    "has_foreign_currency",
    "rate_lookup_status",
    "latency_ms_bucket",
    "error_code",
    "cache_status"
  ]),
  al_hotel_pdf_flow_status: new Set([
    "event_id",
    "app_version",
    "flow_type",
    "page_count_bucket",
    "status",
    "duration_ms_bucket",
    "error_code"
  ]),
  al_common_api_request_status: new Set([
    "event_id",
    "app_version",
    "endpoint_group",
    "http_status_bucket",
    "latency_ms_bucket",
    "error_code",
    "cache_status"
  ]),
  al_pro_gate_viewed: new Set([
    "event_id",
    "app_version",
    "surface",
    "pro_feature_area",
    "copy_variant",
    "user_action",
    "dismiss_reason_code"
  ]),
  al_purchase_flow_status: new Set([
    "event_id",
    "app_version",
    "product_tier",
    "storekit_step",
    "storekit_status",
    "error_code",
    "duration_ms_bucket"
  ]),
  al_privacy_payload_guard_violation: new Set([
    "event_id",
    "app_version",
    "event_name_checked",
    "violation_type",
    "blocked_field_category",
    "build_number"
  ])
};

const forbiddenKeyFragments = [
  "amount",
  "merchant",
  "screenshot",
  "photo",
  "image",
  "pdf",
  "file_name",
  "filename",
  "email",
  "mail_subject",
  "mail_body",
  "hotel_name",
  "hotelname",
  "room",
  "latitude",
  "longitude",
  "geo",
  "precise_location",
  "exact_location",
  "raw_text",
  "ocr_text",
  "receipt_text",
  "receipt",
  "transaction_id",
  "transactionid",
  "apple_id",
  "app_account_token",
  "payment_method",
  "billing_address"
];

export async function analyticsEventsEndpoint(request: Request, env: Env): Promise<Response> {
  if (!env.COMMON_API_DB) {
    return json(error("analytics_database_unconfigured", "Analytics database is not configured."), 503);
  }

  try {
    const body = await parseAnalyticsBody(request);
    const events = validateAnalyticsRequest(body);
    const receivedAt = new Date().toISOString();
    const schemaVersion = integerValue(body.schemaVersion) ?? 1;

    for (const event of events) {
      await env.COMMON_API_DB.prepare(`
        INSERT INTO autoledger_analytics_events (
          id,
          app_id,
          event_name,
          event_id,
          app_version,
          build_number,
          os_major,
          device_class,
          payload_json,
          received_at,
          schema_version
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `).bind(
        `autoledger_analytics_${crypto.randomUUID()}`,
        "autoledger",
        event.eventName,
        event.eventID,
        event.appVersion,
        event.buildNumber,
        event.osMajor,
        event.deviceClass,
        JSON.stringify(event.payload),
        receivedAt,
        schemaVersion
      ).run();
    }

    return json({
      ok: true,
      accepted: events.length,
      privacy: "Accepted payloads are validated against the AutoLedger analytics allow-list. Ledger amounts, merchants, documents, emails, hotel identifiers, precise location, OCR text, StoreKit identifiers, and payment data are rejected."
    }, 202);
  } catch (caught) {
    if (caught instanceof AnalyticsValidationError) {
      return json(error(caught.code, caught.message), caught.status);
    }
    const message = caught instanceof Error ? caught.message : "Unknown analytics ingestion error.";
    return json(error("analytics_ingest_failed", message), 500);
  }
}

async function parseAnalyticsBody(request: Request): Promise<AnalyticsRequestBody> {
  const contentLength = integerValue(request.headers.get("content-length"));
  if (contentLength != null && contentLength > maxRequestBytes) {
    throw new AnalyticsValidationError("analytics_payload_too_large", "Analytics payload is too large.", 413);
  }

  const text = await request.text();
  if (text.length > maxRequestBytes) {
    throw new AnalyticsValidationError("analytics_payload_too_large", "Analytics payload is too large.", 413);
  }

  try {
    const parsed = JSON.parse(text) as unknown;
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
      throw new AnalyticsValidationError("analytics_invalid_body", "Analytics request body must be a JSON object.");
    }
    return parsed as AnalyticsRequestBody;
  } catch (caught) {
    if (caught instanceof AnalyticsValidationError) {
      throw caught;
    }
    throw new AnalyticsValidationError("analytics_invalid_body", "Analytics request body must be valid JSON.");
  }
}

function validateAnalyticsRequest(body: AnalyticsRequestBody): ValidAnalyticsEvent[] {
  const appID = stringValue(body.app)?.toLowerCase();
  if (appID !== "autoledger") {
    throw new AnalyticsValidationError("analytics_invalid_app", "Analytics events must declare app=autoledger.");
  }
  if (!Array.isArray(body.events) || body.events.length === 0 || body.events.length > maxEventsPerRequest) {
    throw new AnalyticsValidationError("analytics_invalid_event", `Analytics requests must include 1-${maxEventsPerRequest} events.`);
  }
  return body.events.map(validateAnalyticsEvent);
}

function validateAnalyticsEvent(rawEvent: unknown): ValidAnalyticsEvent {
  if (!rawEvent || typeof rawEvent !== "object" || Array.isArray(rawEvent)) {
    throw new AnalyticsValidationError("analytics_invalid_event", "Each analytics event must be an object.");
  }
  const event = rawEvent as AnalyticsEventInput;
  const eventName = stringValue(event.eventName) ?? stringValue(event.event_name);
  if (!eventName || !allowedFieldsByEventName[eventName]) {
    throw new AnalyticsValidationError("analytics_invalid_event", "Analytics event name is not supported.");
  }
  if (!event.payload || typeof event.payload !== "object" || Array.isArray(event.payload)) {
    throw new AnalyticsValidationError("analytics_invalid_event", "Analytics event payload must be an object.");
  }

  const payload = event.payload as Record<string, unknown>;
  const allowedFields = allowedFieldsByEventName[eventName];
  const sanitizedPayload: Record<string, string | number | boolean | null> = {};

  for (const [key, value] of Object.entries(payload)) {
    if (isForbiddenField(key)) {
      throw new AnalyticsValidationError("analytics_forbidden_field", `Analytics payload contains forbidden field category: ${safeFieldName(key)}.`);
    }
    if (!allowedFields.has(key)) {
      throw new AnalyticsValidationError("analytics_unsupported_field", `Analytics payload field is not supported for ${eventName}: ${safeFieldName(key)}.`);
    }
    if (!isPrimitivePayloadValue(value)) {
      throw new AnalyticsValidationError("analytics_unsupported_field", `Analytics payload field must be primitive: ${safeFieldName(key)}.`);
    }
    sanitizedPayload[key] = value;
  }

  return {
    eventName,
    eventID: stringValue(sanitizedPayload.event_id),
    appVersion: stringValue(event.appVersion) ?? stringValue(event.app_version) ?? stringValue(sanitizedPayload.app_version),
    buildNumber: stringValue(event.buildNumber) ?? stringValue(event.build_number) ?? stringValue(sanitizedPayload.build_number),
    osMajor: stringValue(event.osMajor) ?? stringValue(event.os_major) ?? stringValue(sanitizedPayload.os_major),
    deviceClass: stringValue(event.deviceClass) ?? stringValue(event.device_class) ?? stringValue(sanitizedPayload.device_class),
    payload: sanitizedPayload
  };
}

function isForbiddenField(key: string): boolean {
  const normalized = normalizeKey(key);
  return forbiddenKeyFragments.some((fragment) => normalized.includes(fragment));
}

function safeFieldName(key: string): string {
  return normalizeKey(key).slice(0, 80);
}

function normalizeKey(key: string): string {
  return key
    .trim()
    .toLowerCase()
    .replace(/[-\s]+/g, "_");
}

function isPrimitivePayloadValue(value: unknown): value is string | number | boolean | null {
  return value == null || typeof value === "string" || typeof value === "number" || typeof value === "boolean";
}

function stringValue(value: unknown): string | null {
  return typeof value === "string" && value.trim() ? value.trim() : null;
}

function integerValue(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) {
    return Math.trunc(value);
  }
  if (typeof value === "string" && /^\d+$/.test(value.trim())) {
    return Number(value.trim());
  }
  return null;
}

function error(code: string, message: string): APIError {
  return { error: { code, message } };
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store"
    }
  });
}
