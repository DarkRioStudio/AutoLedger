import { describe, expect, it } from "vitest";
import { testInternals } from "../src/index";

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
