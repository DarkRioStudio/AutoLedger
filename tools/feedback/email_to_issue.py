#!/usr/bin/env python3
"""
AutoLedger Feedback Email → GitHub Issue Processor

Reads unread feedback emails from Gmail (IMAP), parses subject / body /
attachment bundle, performs server-side redaction, and creates a GitHub
Issue via the REST API.  Idempotent: duplicate feedback_id → skip.

Environment variables (required):
    GMAIL_USERNAME          Gmail address
    GMAIL_APP_PASSWORD      Gmail App Password (16 chars, spaces okay)
    GH_PAT_TOKEN            GitHub PAT with Issues:write scope
    GITHUB_REPOSITORY       owner/repo  (e.g. darkrio326/AutoLedgerRio)

Environment variables (optional):
    FEEDBACK_SUBJECT_PREFIX  Default: [AutoLedger]
    DRY_RUN                  Set to "1" to skip issue creation & email marking
"""

from __future__ import annotations

import email
import imaplib
import json
import logging
import os
import re
import sys
import zipfile
from email.header import decode_header
from io import BytesIO
from typing import Any
from urllib.error import HTTPError
from urllib.request import Request, urlopen

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

GMAIL_USERNAME: str = os.environ.get("GMAIL_USERNAME", "")
GMAIL_APP_PASSWORD: str = os.environ.get("GMAIL_APP_PASSWORD", "")
GH_PAT_TOKEN: str = os.environ.get("GH_PAT_TOKEN", "")
GITHUB_REPOSITORY: str = os.environ.get("GITHUB_REPOSITORY", "")
SUBJECT_PREFIX: str = os.environ.get("FEEDBACK_SUBJECT_PREFIX", "[AutoLedger]")
DRY_RUN: bool = os.environ.get("DRY_RUN", "0") == "1"

LOG = logging.getLogger("feedback")
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)

# ---------------------------------------------------------------------------
# Server-side redaction (second pass — client already redacted once)
# ---------------------------------------------------------------------------

_REDACT_PATTERNS: list[tuple[re.Pattern[str], str]] = [
    (re.compile(r"[\w.+-]+@[\w-]+\.[\w.-]+"), "[EMAIL_MASKED]"),
    (re.compile(r"1[3-9]\d{9}"), "[PHONE_MASKED]"),
    (re.compile(r"\b\d{8,19}\b"), "[LONG_NUMBER_MASKED]"),
]


def redact(text: str) -> str:
    """Apply server-side redaction patterns."""
    for pattern, replacement in _REDACT_PATTERNS:
        text = pattern.sub(replacement, text)
    return text


# ---------------------------------------------------------------------------
# GitHub notification filter
# ---------------------------------------------------------------------------


def is_github_notification(subject: str) -> bool:
    """Return True if the subject is a GitHub repository notification email.

    GitHub (and Copilot) notification emails carry a ``[owner/repo]`` label at
    the start of the subject, e.g. ``[darkrio326/AutoLedgerRio] PR opened``.
    These must be skipped so the bot does not create garbage issues from them.
    """
    if not GITHUB_REPOSITORY:
        return False
    return f"[{GITHUB_REPOSITORY}]" in subject


# ---------------------------------------------------------------------------
# Subject parsing
# ---------------------------------------------------------------------------

# [AutoLedger][L2][iOS][1.0.0(5)][ocr_parse_wrong] 金额识别错误
_SUBJECT_RE = re.compile(
    r"\[AutoLedger\]"
    r"\[(?P<level>L[123])\]"
    r"\[(?P<platform>[^\]]+)\]"
    r"\[(?P<version>[^\]]+)\]"
    r"\[(?P<issue_type>[^\]]+)\]"
    r"\s*(?P<summary>.+)",
)


def parse_subject(raw: str) -> dict[str, str]:
    """Return structured fields from the email subject line."""
    m = _SUBJECT_RE.search(raw)
    if not m:
        return {"level": "L1", "platform": "iOS", "version": "?", "issue_type": "other", "summary": raw}
    return m.groupdict()


# ---------------------------------------------------------------------------
# AUTOLEDGER_FEEDBACK_META block parsing
# ---------------------------------------------------------------------------

_META_RE = re.compile(
    r"AUTOLEDGER_FEEDBACK_META\s*\n(.*?)(?:\n-{5,}|\Z)",
    re.DOTALL,
)


def parse_meta_block(body: str) -> dict[str, str]:
    """Extract key=value pairs from the AUTOLEDGER_FEEDBACK_META block."""
    m = _META_RE.search(body)
    if not m:
        return {}
    meta: dict[str, str] = {}
    for line in m.group(1).strip().splitlines():
        line = line.strip()
        if "=" in line:
            k, _, v = line.partition("=")
            meta[k.strip()] = v.strip()
    return meta


# ---------------------------------------------------------------------------
# Zip bundle extraction
# ---------------------------------------------------------------------------


def extract_bundle(zip_bytes: bytes) -> dict[str, Any]:
    """
    Extract known files from the feedback zip bundle.

    Returns a dict with keys like 'issue_bundle', 'summary', 'metadata',
    each holding parsed JSON / raw text as appropriate.
    """
    result: dict[str, Any] = {}
    try:
        with zipfile.ZipFile(BytesIO(zip_bytes)) as zf:
            for name in zf.namelist():
                basename = name.rsplit("/", 1)[-1] if "/" in name else name
                if basename == "issue_bundle.json":
                    result["issue_bundle"] = json.loads(zf.read(name))
                elif basename == "summary.txt":
                    result["summary"] = zf.read(name).decode("utf-8", errors="replace")
                elif basename == "metadata.json":
                    result["metadata"] = json.loads(zf.read(name))
                elif basename == "trace.log":
                    result["trace"] = zf.read(name).decode("utf-8", errors="replace")
                elif basename == "redacted_ocr_context.txt":
                    result["redacted_ocr"] = zf.read(name).decode("utf-8", errors="replace")
                # Intentionally skip full_ocr_text.txt and attachments/
                # to avoid uploading sensitive content to GitHub Issues.
    except zipfile.BadZipFile:
        LOG.warning("Attachment is not a valid zip file — skipping bundle extraction")
    return result


# ---------------------------------------------------------------------------
# Gmail IMAP helpers
# ---------------------------------------------------------------------------


def decode_mime_header(raw: str | None) -> str:
    """Decode a possibly-encoded MIME header value."""
    if not raw:
        return ""
    parts = decode_header(raw)
    decoded: list[str] = []
    for data, charset in parts:
        if isinstance(data, bytes):
            decoded.append(data.decode(charset or "utf-8", errors="replace"))
        else:
            decoded.append(data)
    return " ".join(decoded)


def get_body_text(msg: email.message.Message) -> str:
    """Return the plain-text body of a MIME message."""
    if msg.is_multipart():
        for part in msg.walk():
            ct = part.get_content_type()
            if ct == "text/plain":
                payload = part.get_payload(decode=True)
                if payload:
                    charset = part.get_content_charset() or "utf-8"
                    return payload.decode(charset, errors="replace")
    else:
        payload = msg.get_payload(decode=True)
        if payload:
            charset = msg.get_content_charset() or "utf-8"
            return payload.decode(charset, errors="replace")
    return ""


def get_zip_attachment(msg: email.message.Message) -> tuple[str, bytes] | None:
    """Return (filename, raw_bytes) of the first zip attachment, or None."""
    for part in msg.walk():
        ct = part.get_content_type()
        fn = part.get_filename()
        if fn and (ct == "application/zip" or fn.lower().endswith(".zip")):
            payload = part.get_payload(decode=True)
            if payload:
                return (decode_mime_header(fn), payload)
    return None


def fetch_feedback_emails() -> list[dict[str, Any]]:
    """
    Connect to Gmail IMAP, fetch all unread emails matching SUBJECT_PREFIX.

    Returns a list of dicts:
        {uid, subject, body, zip_filename, zip_bytes, message_id}
    """
    results: list[dict[str, Any]] = []

    imap = imaplib.IMAP4_SSL("imap.gmail.com")
    try:
        imap.login(GMAIL_USERNAME, GMAIL_APP_PASSWORD)
        imap.select("INBOX")

        # Search for unread emails containing our prefix
        search_query = f'(UNSEEN SUBJECT "{SUBJECT_PREFIX}")'
        status, data = imap.search(None, search_query)
        if status != "OK" or not data[0]:
            LOG.info("No unread feedback emails found.")
            return results

        uids = data[0].split()
        LOG.info("Found %d unread feedback email(s).", len(uids))

        for uid in uids:
            status, msg_data = imap.fetch(uid, "(RFC822)")
            if status != "OK" or not msg_data or not msg_data[0]:
                continue
            raw_email = msg_data[0][1]
            msg = email.message_from_bytes(raw_email)

            subject = decode_mime_header(msg.get("Subject"))
            body = get_body_text(msg)
            message_id = msg.get("Message-ID", "")

            zip_info = get_zip_attachment(msg)
            zip_filename = zip_info[0] if zip_info else ""
            zip_bytes = zip_info[1] if zip_info else b""

            results.append({
                "uid": uid,
                "subject": subject,
                "body": body,
                "zip_filename": zip_filename,
                "zip_bytes": zip_bytes,
                "message_id": message_id,
            })

        return results
    finally:
        try:
            imap.close()
        except Exception:
            pass
        imap.logout()


def mark_as_read(uid: bytes) -> None:
    """Re-connect and mark a single email as read (\\Seen)."""
    imap = imaplib.IMAP4_SSL("imap.gmail.com")
    try:
        imap.login(GMAIL_USERNAME, GMAIL_APP_PASSWORD)
        imap.select("INBOX")
        imap.store(uid, "+FLAGS", "\\Seen")
    finally:
        try:
            imap.close()
        except Exception:
            pass
        imap.logout()


# ---------------------------------------------------------------------------
# GitHub Issue helpers
# ---------------------------------------------------------------------------

_API_BASE = "https://api.github.com"


def _gh_request(method: str, path: str, body: dict | None = None) -> dict:
    """Make an authenticated request to the GitHub REST API."""
    url = f"{_API_BASE}{path}"
    data = json.dumps(body).encode() if body else None
    req = Request(url, data=data, method=method)
    req.add_header("Authorization", f"Bearer {GH_PAT_TOKEN}")
    req.add_header("Accept", "application/vnd.github+json")
    req.add_header("X-GitHub-Api-Version", "2022-11-28")
    if data:
        req.add_header("Content-Type", "application/json")
    try:
        with urlopen(req) as resp:
            return json.loads(resp.read())
    except HTTPError as e:
        err_body = e.read().decode("utf-8", errors="replace") if e.fp else ""
        LOG.error("GitHub API %s %s → %d: %s", method, path, e.code, err_body)
        raise


def issue_exists(feedback_id: str) -> bool:
    """Check if an issue with the given feedback_id already exists."""
    query = f"Feedback-ID: {feedback_id} repo:{GITHUB_REPOSITORY} is:issue"
    path = f"/search/issues?q={query.replace(' ', '+')}&per_page=1"
    try:
        result = _gh_request("GET", path)
        return result.get("total_count", 0) > 0
    except HTTPError:
        return False


def create_issue(title: str, body: str, labels: list[str]) -> str | None:
    """Create a GitHub Issue. Returns the issue URL or None on failure."""
    path = f"/repos/{GITHUB_REPOSITORY}/issues"
    payload = {"title": title, "body": body, "labels": labels}
    try:
        result = _gh_request("POST", path, payload)
        return result.get("html_url", "")
    except HTTPError:
        return None


# ---------------------------------------------------------------------------
# Issue body builder
# ---------------------------------------------------------------------------


def build_issue_title(subj: dict[str, str]) -> str:
    """Build the GitHub Issue title from parsed subject fields."""
    return f"[{subj['platform']} {subj['version']}][{subj['issue_type']}][{subj['level']}] {subj['summary']}"


def build_issue_body(
    subj: dict[str, str],
    meta: dict[str, str],
    bundle: dict[str, Any],
    body_text: str,
) -> str:
    """Compose the GitHub Issue body in Markdown."""
    feedback_id = meta.get("feedback_id", bundle.get("issue_bundle", {}).get("feedback_id", "unknown"))
    issue_bundle: dict = bundle.get("issue_bundle", {})
    metadata: dict = bundle.get("metadata", {})

    # App info
    app_info = issue_bundle.get("app", {})
    event_info = issue_bundle.get("event", {})
    debug_info = issue_bundle.get("debug", {})
    privacy_info = issue_bundle.get("privacy", {})

    sections: list[str] = []

    # Header
    sections.append(f"## Feedback Report\n\n**Feedback-ID:** `{feedback_id}`")

    # Device / App
    sections.append(
        "### Environment\n"
        f"| Key | Value |\n|---|---|\n"
        f"| App Version | {app_info.get('version', meta.get('app_version', '?'))} ({app_info.get('build', meta.get('build', '?'))}) |\n"
        f"| Platform | {app_info.get('platform', 'iOS')} |\n"
        f"| iOS Version | {app_info.get('ios_version', meta.get('ios_version', '?'))} |\n"
        f"| Device | {app_info.get('device_model', meta.get('device_model', '?'))} |\n"
        f"| Level | {subj['level']} |\n"
        f"| Issue Type | `{subj['issue_type']}` |\n"
        f"| Entry Point | {event_info.get('entry_point', meta.get('entry_point', '?'))} |\n"
        f"| Event Time | {event_info.get('time_local', '?')} |"
    )

    # User description (redacted)
    user_desc = issue_bundle.get("user_description", "")
    expected = issue_bundle.get("expected_result", "")
    actual = issue_bundle.get("actual_result", "")
    reproducible = issue_bundle.get("reproducible", "")

    sections.append(
        "### User Report\n"
        f"**Problem:** {redact(user_desc)}\n\n"
        f"**Expected:** {redact(expected)}\n\n"
        f"**Actual:** {redact(actual)}\n\n"
        f"**Reproducible:** {reproducible}"
    )

    # Debug info
    if debug_info:
        parsed = debug_info.get("parsed_result", {})
        debug_lines = [
            "### Debug Info\n",
            f"- OCR Status: {debug_info.get('ocr_status', '?')}",
            f"- Parse Status: {debug_info.get('parse_status', '?')}",
            f"- Save Status: {debug_info.get('save_status', '?')}",
        ]
        if parsed:
            debug_lines.append(f"- Parsed Amount: {redact(str(parsed.get('amount', '?')))}")
            debug_lines.append(f"- Parsed Merchant: {redact(str(parsed.get('merchant', '?')))}")
            debug_lines.append(f"- Parsed Time: {parsed.get('time', '?')}")
            if "confidence" in parsed:
                debug_lines.append(f"- Confidence: {parsed['confidence']}")
        sections.append("\n".join(debug_lines))

    # Trace (L2+)
    trace_text = bundle.get("trace", "")
    if trace_text:
        # Truncate very long traces
        if len(trace_text) > 3000:
            trace_text = trace_text[:3000] + "\n... (truncated)"
        sections.append(f"### Trace Log\n\n```\n{redact(trace_text)}\n```")

    # Redacted OCR context (L2+)
    ocr_ctx = bundle.get("redacted_ocr", "")
    if ocr_ctx:
        if len(ocr_ctx) > 2000:
            ocr_ctx = ocr_ctx[:2000] + "\n... (truncated)"
        sections.append(f"### Redacted OCR Context\n\n```\n{redact(ocr_ctx)}\n```")

    # Privacy note
    sections.append(
        "### Privacy\n"
        f"- Redacted: {privacy_info.get('redacted', True)}\n"
        f"- Contains full OCR text: {privacy_info.get('contains_full_ocr_text', False)}\n"
        f"- Contains raw image: {privacy_info.get('contains_raw_image', False)}\n\n"
        "> ⚠️ Server-side redaction has been applied. "
        "Full OCR text and raw images are intentionally excluded from this issue."
    )

    return "\n\n---\n\n".join(sections)


def build_labels(subj: dict[str, str]) -> list[str]:
    """Build GitHub Issue labels from parsed subject."""
    labels = [
        "feedback",
        f"source/email",
        f"level/{subj['level']}",
        f"type/{subj['issue_type']}",
        "status/new",
    ]
    return labels


# ---------------------------------------------------------------------------
# Main processing
# ---------------------------------------------------------------------------


def process_email(mail: dict[str, Any]) -> bool:
    """Process a single feedback email. Returns True if issue was created."""
    subject = mail["subject"]
    body = mail["body"]
    zip_bytes = mail["zip_bytes"]

    LOG.info("Processing: %s", subject)

    # 0. Skip GitHub repository notification emails (e.g. from Copilot).
    #    These carry a [owner/repo] label in the subject and must not be
    #    turned into feedback issues.
    if is_github_notification(subject):
        LOG.info("Skipping GitHub notification email: %s", subject)
        if not DRY_RUN:
            mark_as_read(mail["uid"])
        return False

    # 1. Parse subject
    subj = parse_subject(subject)

    # 2. Parse meta block from body
    meta = parse_meta_block(body)

    # 3. Extract bundle from zip
    bundle: dict[str, Any] = {}
    if zip_bytes:
        bundle = extract_bundle(zip_bytes)

    # 4. Determine feedback_id for idempotency
    feedback_id = (
        meta.get("feedback_id")
        or bundle.get("issue_bundle", {}).get("feedback_id")
        or ""
    )
    if not feedback_id:
        # Fallback: hash of Message-ID
        import hashlib
        mid = mail.get("message_id", subject)
        feedback_id = f"AL-{hashlib.sha256(mid.encode()).hexdigest()[:12]}"
        LOG.warning("No feedback_id found — using fallback: %s", feedback_id)

    # 5. Check idempotency
    if issue_exists(feedback_id):
        LOG.info("Issue already exists for feedback_id=%s — skipping.", feedback_id)
        # Still mark as read to avoid re-processing
        if not DRY_RUN:
            mark_as_read(mail["uid"])
        return False

    # 6. Build issue
    title = build_issue_title(subj)
    issue_body = build_issue_body(subj, meta, bundle, body)
    labels = build_labels(subj)

    if DRY_RUN:
        LOG.info("[DRY_RUN] Would create issue: %s", title)
        LOG.info("[DRY_RUN] Labels: %s", labels)
        LOG.info("[DRY_RUN] Body preview (first 500 chars):\n%s", issue_body[:500])
        return True

    # 7. Create issue
    url = create_issue(title, issue_body, labels)
    if url:
        LOG.info("Created issue: %s", url)
    else:
        LOG.error("Failed to create issue for feedback_id=%s", feedback_id)
        return False

    # 8. Mark email as read
    mark_as_read(mail["uid"])
    LOG.info("Marked email as read (uid=%s).", mail["uid"])

    return True


def main() -> None:
    """Entry point."""
    # Validate required env vars
    missing = []
    if not GMAIL_USERNAME:
        missing.append("GMAIL_USERNAME")
    if not GMAIL_APP_PASSWORD:
        missing.append("GMAIL_APP_PASSWORD")
    if not GH_PAT_TOKEN:
        missing.append("GH_PAT_TOKEN")
    if not GITHUB_REPOSITORY:
        missing.append("GITHUB_REPOSITORY")
    if missing:
        LOG.error("Missing required environment variables: %s", ", ".join(missing))
        sys.exit(1)

    LOG.info(
        "Starting feedback processor (repo=%s, prefix=%s, dry_run=%s)",
        GITHUB_REPOSITORY, SUBJECT_PREFIX, DRY_RUN,
    )

    # Fetch emails
    emails = fetch_feedback_emails()
    if not emails:
        LOG.info("No emails to process. Done.")
        return

    created = 0
    for mail in emails:
        try:
            if process_email(mail):
                created += 1
        except Exception:
            LOG.exception("Error processing email: %s", mail.get("subject", "?"))

    LOG.info("Done. Created %d issue(s) from %d email(s).", created, len(emails))


if __name__ == "__main__":
    main()
