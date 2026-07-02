import { describe, expect, it } from "vitest";
import { importPKCS8, SignJWT } from "jose";
import { testInternals } from "../src/index";

function unsignedJWS(payload: Record<string, unknown>): string {
  const encoded = Buffer.from(JSON.stringify(payload)).toString("base64url");
  return `header.${encoded}.signature`;
}

const testRootCertificatePEM = `-----BEGIN CERTIFICATE-----
MIIBnTCCAUOgAwIBAgIUHklCHoe9Jcy1LFjPDht6xgxS200wCgYIKoZIzj0EAwIw
JDEiMCAGA1UEAwwZQXV0b0xlZGdlciBBU1NOIFRlc3QgUm9vdDAeFw0yNjA3MDIx
NDAxMTBaFw0zNjA2MjkxNDAxMTBaMCQxIjAgBgNVBAMMGUF1dG9MZWRnZXIgQVNT
TiBUZXN0IFJvb3QwWTATBgcqhkjOPQIBBggqhkjOPQMBBwNCAASz7GTR+O9m+0NS
OAi6ffPjJKomcmnlnu0h0SpYs+36lI3k+FfQ2ebpw9bGXE8CVXmQwrkbL2X/x+rn
ISq0FzHto1MwUTAdBgNVHQ4EFgQU+wVBakJxrW0hT2CAHcaVrkRrEvowHwYDVR0j
BBgwFoAU+wVBakJxrW0hT2CAHcaVrkRrEvowDwYDVR0TAQH/BAUwAwEB/zAKBggq
hkjOPQQDAgNIADBFAiBOuZiwpa7we4Hr70exCUHCEDpovBSEQE06xew4uHQu9gIh
AKgJ5u3GU8XQRCoWs3vhewOSGxPyRpiGDGUcQhyiF0bQ
-----END CERTIFICATE-----`;

const wrongRootCertificatePEM = `-----BEGIN CERTIFICATE-----
MIIBljCCATugAwIBAgIUA36uf6gvWUqgKqnX/mTE1NI/jlEwCgYIKoZIzj0EAwIw
IDEeMBwGA1UEAwwVQXV0b0xlZGdlciBXcm9uZyBSb290MB4XDTI2MDcwMjE0MDQy
NVoXDTM2MDYyOTE0MDQyNVowIDEeMBwGA1UEAwwVQXV0b0xlZGdlciBXcm9uZyBS
b290MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAENADUoJ/9icqvdwXKGr7Z/jJS
fuIVgmwEQS2VBYvVUswA68HxYLMKPbpg3OlJkG6RLRCZOGrj4eho+M2yjcgOWKNT
MFEwHQYDVR0OBBYEFMUbLAkTpP4XW5ARqEmIC6t47VX8MB8GA1UdIwQYMBaAFMUb
LAkTpP4XW5ARqEmIC6t47VX8MA8GA1UdEwEB/wQFMAMBAf8wCgYIKoZIzj0EAwID
SQAwRgIhANRuJymXBjBMuK5h2c1otz20YTnoJDMeErarvf+6gReAAiEAoM3+SONr
s6zfLDoSr3I1lbUANcRVh3gClwRAq05NHA=
-----END CERTIFICATE-----`;

const testLeafPrivateKeyPKCS8 = `-----BEGIN PRIVATE KEY-----
MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQg+hOvGkHrU8/JtvCt
yvIpLZqTMPLvuojPKXkMhvM3YkGhRANCAAQuEcU3E0zcdyR2WhIMlVs+P8b4bGmF
X1gKk/X8Xrez9jVg5K4gWGZht+fZrAZjxsnGHpPIIkjwltmKJHn0Qxhk
-----END PRIVATE KEY-----`;

const testLeafCertificateDERBase64 = "MIIBizCCATKgAwIBAgIUC+QokLg2lzz4AORbZvtzItdUBsEwCgYIKoZIzj0EAwIwJDEiMCAGA1UEAwwZQXV0b0xlZGdlciBBU1NOIFRlc3QgUm9vdDAeFw0yNjA3MDIxNDAxMTFaFw0zNjA2MjkxNDAxMTFaMCQxIjAgBgNVBAMMGUF1dG9MZWRnZXIgQVNTTiBUZXN0IExlYWYwWTATBgcqhkjOPQIBBggqhkjOPQMBBwNCAAQuEcU3E0zcdyR2WhIMlVs+P8b4bGmFX1gKk/X8Xrez9jVg5K4gWGZht+fZrAZjxsnGHpPIIkjwltmKJHn0Qxhko0IwQDAdBgNVHQ4EFgQUmKpYhvIjUQsvxC5kD6MWpEBrgeswHwYDVR0jBBgwFoAU+wVBakJxrW0hT2CAHcaVrkRrEvowCgYIKoZIzj0EAwIDRwAwRAIgH9qZsqP4Gb3CCHefXp0rkj/k8e83RwYtjXG5Hh6kGD8CIB5h/1VSFLZPCER+u7XpEVreLbhl0ievmoD/icvCqB93";

async function signedNotificationJWS(payload: Record<string, unknown>): Promise<string> {
  const key = await importPKCS8(testLeafPrivateKeyPKCS8, "ES256");
  return new SignJWT(payload)
    .setProtectedHeader({
      alg: "ES256",
      x5c: [testLeafCertificateDERBase64]
    })
    .sign(key);
}

describe("hotel folio inbox worker contract", () => {
  it("accepts only AutoLedger folio plus-token addresses", () => {
    expect(testInternals.parseInboxAddress("folio+abc_123@getautoledger.app")).toEqual({
      token: "abc_123",
      normalized: "folio+abc_123@getautoledger.app"
    });
    expect(testInternals.parseInboxAddress("folio@getautoledger.app")).toBeNull();
    expect(testInternals.parseInboxAddress("support@getautoledger.app")).toBeNull();
    expect(testInternals.parseInboxAddress("folio+abc@example.com")).toBeNull();
  });

  it("keeps token hashes stable with Core token normalization", async () => {
    const hash = await testInternals.sha256Hex(testInternals.normalizeToken("  AbC-123_ "));
    expect(hash).toHaveLength(64);
    expect(hash).toBe(await testInternals.sha256Hex("abc-123_"));
  });

  it("generates stable dedicated inbox addresses for claimed tokens", () => {
    const token = testInternals.generateInboxToken();
    expect(token).toMatch(/^[a-z2-9]{26}$/);
    expect(testInternals.inboxEmailForToken(` ${token.toUpperCase()} `)).toBe(`folio+${token}@getautoledger.app`);
  });

  it("normalizes client identifiers before token provisioning", () => {
    expect(testInternals.normalizeClientID(" Device:ABC-123_ / extra ")).toBe("deviceabc-123_extra");
    expect(testInternals.normalizeClientID("")).toBe("");
  });

  it("keeps unauthenticated token claim disabled unless explicitly enabled", () => {
    expect(testInternals.allowsUnverifiedTokenClaim({ ALLOW_UNVERIFIED_TOKEN_CLAIM: "true" } as never)).toBe(true);
    expect(testInternals.allowsUnverifiedTokenClaim({ ALLOW_UNVERIFIED_TOKEN_CLAIM: "1" } as never)).toBe(true);
    expect(testInternals.allowsUnverifiedTokenClaim({ ALLOW_UNVERIFIED_TOKEN_CLAIM: "false" } as never)).toBe(false);
    expect(testInternals.allowsUnverifiedTokenClaim({} as never)).toBe(false);
  });

  it("limits unverified token bootstrap to a short expiry window", () => {
    const now = new Date("2026-06-30T00:00:00.000Z");
    expect(testInternals.unverifiedTokenExpirationDate({ UNVERIFIED_TOKEN_TTL_DAYS: "7" } as never, now).toISOString()).toBe(
      "2026-07-07T00:00:00.000Z"
    );
    expect(testInternals.unverifiedTokenExpirationDate({ UNVERIFIED_TOKEN_TTL_DAYS: "365" } as never, now).toISOString()).toBe(
      "2026-07-30T00:00:00.000Z"
    );
  });

  it("decodes StoreKit signed transaction payloads for server-side checks", () => {
    const payload = {
      transactionId: "2000000000000001",
      originalTransactionId: "1000000000000001",
      bundleId: "top.darkrio326.AutoLedger",
      productId: "top.darkrio326.AutoLedger.pro.yearly",
      expiresDate: 1790726400000
    };
    expect(testInternals.decodeJWSPayload(unsignedJWS(payload))).toMatchObject(payload);
    expect(testInternals.decodeJWSPayload("not-a-jws")).toBeNull();
  });

  it("validates App Store transaction payload boundaries", () => {
    const now = new Date("2026-06-30T00:00:00.000Z");
    const valid = {
      transactionId: "2000000000000001",
      originalTransactionId: "1000000000000001",
      bundleId: "top.darkrio326.AutoLedger",
      productId: "top.darkrio326.AutoLedger.pro.monthly",
      expiresDate: "1790726400000"
    };
    expect(testInternals.validateAppStoreTransactionPayload({ bundleID: "top.darkrio326.AutoLedger" }, valid, now)).toMatchObject({
      allowed: true,
      originalTransactionID: "1000000000000001",
      productID: "top.darkrio326.AutoLedger.pro.monthly"
    });
    expect(testInternals.validateAppStoreTransactionPayload({ bundleID: "top.darkrio326.AutoLedger" }, {
      ...valid,
      bundleId: "com.example.other"
    }, now)).toMatchObject({ allowed: false, reason: "bundle_id_mismatch" });
    expect(testInternals.validateAppStoreTransactionPayload({ bundleID: "top.darkrio326.AutoLedger" }, {
      ...valid,
      productId: "top.darkrio326.AutoLedger.tip.small"
    }, now)).toMatchObject({ allowed: false, reason: "unsupported_product" });
    expect(testInternals.validateAppStoreTransactionPayload({ bundleID: "top.darkrio326.AutoLedger" }, {
      ...valid,
      expiresDate: "2026-01-01T00:00:00.000Z"
    }, now)).toMatchObject({ allowed: false, reason: "subscription_expired" });
  });

  it("keeps App Store Server Notifications disabled until verifier mode is explicit", async () => {
    const payload = {
      notificationUUID: "5b833f42-3f8d-470a-8ee5-6d98f0b7b7da",
      notificationType: "DID_RENEW",
      data: {}
    };
    const signedPayload = unsignedJWS(payload);

    await expect(testInternals.decodeAppStoreServerNotificationPayload({} as never, signedPayload)).resolves.toMatchObject({
      ok: false,
      status: 503,
      code: "app_store_notification_verifier_unconfigured"
    });
    await expect(testInternals.decodeAppStoreServerNotificationPayload({
      ALLOW_UNVERIFIED_APP_STORE_NOTIFICATIONS: "true"
    } as never, signedPayload)).resolves.toMatchObject({
      ok: true,
      payload
    });
  });

  it("verifies App Store Server Notification signedPayload with an x5c certificate chain", async () => {
    const payload = {
      notificationUUID: "5b833f42-3f8d-470a-8ee5-6d98f0b7b7da",
      notificationType: "DID_RENEW",
      data: {
        bundleId: "top.darkrio326.AutoLedger",
        environment: "Sandbox"
      }
    };
    const signedPayload = await signedNotificationJWS(payload);

    await expect(testInternals.decodeAppStoreServerNotificationPayload({
      APP_STORE_NOTIFICATION_ROOT_CERT_PEM: testRootCertificatePEM
    } as never, signedPayload)).resolves.toMatchObject({
      ok: true,
      payload,
      verificationMode: "certificate_chain"
    });
    await expect(testInternals.decodeAppStoreServerNotificationPayload({
      APP_STORE_NOTIFICATION_ROOT_CERT_PEM: wrongRootCertificatePEM
    } as never, signedPayload)).resolves.toMatchObject({
      ok: false,
      code: "invalid_signed_payload_certificate_chain"
    });
  });

  it("rejects malformed App Store Server Notification JWS values when certificate verification is enabled", async () => {
    await expect(testInternals.decodeAppStoreServerNotificationPayload({
      APP_STORE_NOTIFICATION_ROOT_CERT_PEM: testRootCertificatePEM
    } as never, unsignedJWS({ notificationUUID: "bad-header" }))).resolves.toMatchObject({
      ok: false,
      status: 400,
      code: "invalid_signed_payload"
    });
  });

  it("prepares App Store Server Notification scopes without storing raw transaction IDs", async () => {
    const transaction = {
      transactionId: "2000000000000001",
      originalTransactionId: "1000000000000001",
      bundleId: "top.darkrio326.AutoLedger",
      productId: "top.darkrio326.AutoLedger.pro.yearly",
      expiresDate: 1790726400000
    };
    const notification = {
      notificationUUID: "5b833f42-3f8d-470a-8ee5-6d98f0b7b7da",
      notificationType: "DID_RENEW",
      version: "2.0",
      signedDate: 1782864000000,
      data: {
        bundleId: "top.darkrio326.AutoLedger",
        environment: "Sandbox",
        signedTransactionInfo: unsignedJWS(transaction)
      }
    };

    const prepared = await testInternals.prepareAppStoreNotification(
      { bundleID: "top.darkrio326.AutoLedger", environment: "sandbox" },
      unsignedJWS(notification),
      notification
    );

    expect(prepared).toMatchObject({
      ok: true,
      scope: {
        notificationUUID: "5b833f42-3f8d-470a-8ee5-6d98f0b7b7da",
        notificationType: "DID_RENEW",
        userID: expect.stringMatching(/^appstore:[a-f0-9]{64}$/),
        originalTransactionIDHash: expect.stringMatching(/^[a-f0-9]{64}$/),
        productID: "top.darkrio326.AutoLedger.pro.yearly",
        expiresAt: "2026-09-30T00:00:00.000Z"
      }
    });
    if (!prepared.ok) {
      throw new Error("notification should prepare");
    }
    expect(JSON.stringify(prepared.scope)).not.toContain("1000000000000001");
    expect(prepared.scope.rawPayloadHash).toMatch(/^[a-f0-9]{64}$/);
  });

  it("rejects App Store Server Notifications for the wrong environment or product", async () => {
    const transaction = {
      transactionId: "2000000000000001",
      originalTransactionId: "1000000000000001",
      bundleId: "top.darkrio326.AutoLedger",
      productId: "top.darkrio326.AutoLedger.tip.small",
      expiresDate: 1790726400000
    };
    const notification = {
      notificationUUID: "5b833f42-3f8d-470a-8ee5-6d98f0b7b7da",
      notificationType: "DID_RENEW",
      data: {
        bundleId: "top.darkrio326.AutoLedger",
        environment: "Production",
        signedTransactionInfo: unsignedJWS(transaction)
      }
    };

    const environmentMismatch = await testInternals.prepareAppStoreNotification(
      { bundleID: "top.darkrio326.AutoLedger", environment: "sandbox" },
      unsignedJWS(notification),
      notification
    );
    expect(environmentMismatch).toMatchObject({ ok: false, code: "environment_mismatch" });

    const unsupportedProduct = await testInternals.prepareAppStoreNotification(
      { bundleID: "top.darkrio326.AutoLedger", environment: "production" },
      unsignedJWS(notification),
      notification
    );
    expect(unsupportedProduct).toMatchObject({ ok: false, code: "unsupported_product" });
  });

  it("maps App Store notification lifecycle events to service entitlement states", () => {
    const now = new Date("2026-07-01T00:00:00.000Z");
    const activeTransaction = {
      bundleId: "top.darkrio326.AutoLedger",
      productId: "top.darkrio326.AutoLedger.pro.monthly",
      originalTransactionId: "1000000000000001",
      expiresDate: "2026-08-01T00:00:00.000Z"
    };
    const expiredTransaction = {
      ...activeTransaction,
      expiresDate: "2026-06-01T00:00:00.000Z"
    };

    expect(testInternals.appStoreEntitlementStateForNotification("DID_RENEW", null, activeTransaction, null, now)).toMatchObject({
      status: "active",
      active: true,
      expiresAt: "2026-08-01T00:00:00.000Z"
    });
    expect(testInternals.appStoreEntitlementStateForNotification("DID_FAIL_TO_RENEW", null, activeTransaction, {
      gracePeriodExpiresDate: "2026-07-07T00:00:00.000Z"
    }, now)).toMatchObject({
      status: "grace_period",
      active: true,
      expiresAt: "2026-07-07T00:00:00.000Z"
    });
    expect(testInternals.appStoreEntitlementStateForNotification("DID_FAIL_TO_RENEW", null, expiredTransaction, null, now)).toMatchObject({
      status: "billing_retry",
      active: false
    });
    expect(testInternals.appStoreEntitlementStateForNotification("EXPIRED", null, expiredTransaction, null, now)).toMatchObject({
      status: "expired",
      active: false
    });
    expect(testInternals.appStoreEntitlementStateForNotification("REFUND", null, activeTransaction, null, now)).toMatchObject({
      status: "refunded",
      active: false
    });
    expect(testInternals.appStoreEntitlementStateForNotification("REVOKE", null, activeTransaction, null, now)).toMatchObject({
      status: "revoked",
      active: false
    });
  });

  it("hashes App Store transaction identifiers before using them as Worker user IDs", async () => {
    const originalTransactionID = "1000000000000001";
    const userID = await testInternals.appStoreUserID(originalTransactionID);

    expect(userID).toMatch(/^appstore:[a-f0-9]{64}$/);
    expect(userID).not.toContain(originalTransactionID);
  });

  it("selects the correct App Store Server API host", () => {
    expect(testInternals.appStoreServerAPIHost("production")).toBe("https://api.storekit.itunes.apple.com");
    expect(testInternals.appStoreServerAPIHost("sandbox")).toBe("https://api.storekit-sandbox.itunes.apple.com");
  });

  it("accepts Swift UUID path casing for candidate detail endpoints", () => {
    expect(testInternals.normalizeCandidateID(" 9A91F1E2-0A3F-414E-8B6C-99236F58AAF9 ")).toBe(
      "9a91f1e2-0a3f-414e-8b6c-99236f58aaf9"
    );
  });

  it("only lists still-actionable inbox candidates", () => {
    expect(testInternals.isVisibleInboxCandidateStatus("stored")).toBe(true);
    expect(testInternals.isVisibleInboxCandidateStatus("notified")).toBe(true);
    expect(testInternals.isVisibleInboxCandidateStatus("downloaded")).toBe(false);
    expect(testInternals.isVisibleInboxCandidateStatus("converted")).toBe(false);
    expect(testInternals.isVisibleInboxCandidateStatus("deleted")).toBe(false);
    expect(testInternals.isVisibleInboxCandidateStatus("expired")).toBe(false);
    expect(testInternals.isVisibleInboxCandidateStatus("failed")).toBe(false);
  });

  it("redacts privacy-sensitive email metadata", () => {
    expect(testInternals.redactMetadata("Moxy Folio for user@example.com 13800138000")).toBe(
      "Moxy Folio for [redacted-email] [redacted-number]"
    );
  });

  it("turns email body folios into generated PDF candidates when no PDF attachment exists", () => {
    const inputs = testInternals.candidatePDFInputs(
      {
        attachments: [],
        text: "重庆 Moxy 酒店\nFolio 账单\nTotal CNY 369.39",
        html: null
      },
      "931 账单"
    );

    expect(inputs).toHaveLength(1);
    const generated = inputs[0]!;
    expect(generated).toMatchObject({
      fileName: "email-body-folio.pdf",
      source: "emailBody"
    });
    expect(new TextDecoder().decode(generated.bytes.slice(0, 8))).toBe("%PDF-1.7");
  });

  it("prefers real PDF attachments over generated body PDFs", () => {
    const inputs = testInternals.candidatePDFInputs(
      {
        attachments: [
          {
            filename: "folio.pdf",
            mimeType: "application/pdf",
            content: new TextEncoder().encode("%PDF-1.7 attachment")
          }
        ],
        text: "Body folio should not create another candidate",
        html: null
      },
      "Folio"
    );

    expect(inputs).toHaveLength(1);
    const attachment = inputs[0]!;
    expect(attachment.source).toBe("attachment");
    expect(attachment.fileName).toBe("folio.pdf");
  });

  it("stores only safe pdf object names", () => {
    expect(testInternals.safeFileName("Moxy Chongqing Folio 42902.pdf")).toBe("moxy-chongqing-folio-42902.pdf");
    expect(testInternals.safeFileName("folio")).toBe("folio.pdf");
  });

  it("normalizes APNs device registration inputs", () => {
    expect(testInternals.normalizeDeviceToken("AA BB-cc".repeat(8))).toBe("aabbcc".repeat(8));
    expect(testInternals.normalizeDeviceToken("short")).toBeNull();
    expect(testInternals.normalizeAPNSEnvironment("production")).toBe("production");
    expect(testInternals.normalizeAPNSEnvironment("sandbox")).toBe("development");
  });

  it("keeps APNs payload private and routes through the App deep link", () => {
    const payload = {
      type: "hotel_folio_candidate_created" as const,
      userID: "user-1",
      tokenHash: "token-hash",
      candidateID: "candidate-1",
      attachmentFileName: "folio.pdf",
      objectByteSize: 42,
      receivedAt: "2026-06-29T00:00:00.000Z",
      deepLink: "autoledger://hotel-cloud-candidate/candidate-1"
    };
    const body = testInternals.makeAPNSNotificationBody({
      ...payload
    });

    expect(testInternals.notificationPayloadFromQueueBody(payload)).toEqual(payload);
    expect(testInternals.notificationPayloadFromQueueBody({ type: "other" })).toBeNull();
    expect(body).toMatchObject({
      autoledgerDeepLink: "autoledger://hotel-cloud-candidate/candidate-1",
      candidateID: "candidate-1"
    });
    expect(JSON.stringify(body)).not.toContain("folio.pdf");
    expect(JSON.stringify(body)).not.toContain("token-hash");
  });

  it("serializes Worker candidates in the Swift CloudHotelFolioCandidate shape", () => {
    const dto = testInternals.candidateDTO({
      id: "8e4e9f94-44d4-4d9d-8e2d-3a2f3be61b0c",
      token_hash: "token-hash",
      user_id: "user-1",
      source_email_subject: "Moxy Folio",
      source_email_from: "[redacted-email]",
      message_id_hash: "message-hash",
      attachment_file_name: "folio.pdf",
      attachment_hash: "attachment-hash",
      object_storage_key: "hotel-folio-candidates/token-hash/folio.pdf",
      object_byte_size: 42,
      mime_type: "application/pdf",
      status: "stored",
      received_at: "2026-06-29T00:00:00.000Z",
      expires_at: "2026-07-06T00:00:00.000Z",
      downloaded_at: null,
      converted_at: null,
      deleted_at: null,
      failure_reason: null,
      created_at: "2026-06-29T00:00:00.000Z",
      updated_at: "2026-06-29T00:00:00.000Z"
    });

    expect(dto).toMatchObject({
      sourceType: "cloudWorker",
      sourceEmailSubject: "Moxy Folio",
      attachmentFileName: "folio.pdf",
      objectByteSize: 42,
      receivedAt: "2026-06-29T00:00:00.000Z"
    });
  });
});
