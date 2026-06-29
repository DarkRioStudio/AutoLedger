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

  it("redacts privacy-sensitive email metadata", () => {
    expect(testInternals.redactMetadata("Moxy Folio for user@example.com 13800138000")).toBe(
      "Moxy Folio for [redacted-email] [redacted-number]"
    );
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
