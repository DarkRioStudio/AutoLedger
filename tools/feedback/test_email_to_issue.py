#!/usr/bin/env python3
"""Quick smoke tests for email_to_issue core functions."""
import sys, os, json
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".."))
from tools.feedback.email_to_issue import parse_subject, parse_meta_block, redact, build_labels, extract_bundle, is_github_notification
import tools.feedback.email_to_issue as _m

# 1. Subject parsing
subj = parse_subject("[AutoLedger][L2][iOS][1.1.0(10)][ocr_parse_wrong] 金额识别错误")
assert subj["level"] == "L2"
assert subj["issue_type"] == "ocr_parse_wrong"
assert subj["summary"] == "金额识别错误"
print("✅ parse_subject OK")

# 2. Meta block parsing
body = """hello

--------------------------------
AUTOLEDGER_FEEDBACK_META
feedback_level=L1
issue_type=feedback
app_version=1.1.0
feedback_id=AL-3f8a2c-20260410143025-0001
--------------------------------
"""
meta = parse_meta_block(body)
assert meta["feedback_id"] == "AL-3f8a2c-20260410143025-0001"
assert meta["feedback_level"] == "L1"
print("✅ parse_meta_block OK")

# 3. Redaction
assert redact("call 13812345678 now") == "call [PHONE_MASKED] now"
assert redact("email test@example.com") == "email [EMAIL_MASKED]"
assert redact("card 6222021234567890") == "card [LONG_NUMBER_MASKED]"
print("✅ redact OK")

# 4. Labels
labels = build_labels(subj)
assert "level/L2" in labels
assert "type/ocr_parse_wrong" in labels
assert "feedback" in labels
print("✅ build_labels OK")

# 5. Bundle extraction (empty zip_bytes → empty dict)
result = extract_bundle(b"not a zip")
assert result == {}
print("✅ extract_bundle (bad zip) OK")

# 6. Bundle extraction with real zip
import zipfile, io
buf = io.BytesIO()
with zipfile.ZipFile(buf, "w") as zf:
    zf.writestr("feedback_bundle/issue_bundle.json", json.dumps({"feedback_id": "test-001", "feedback_level": "L1"}))
    zf.writestr("feedback_bundle/summary.txt", "test summary")
    zf.writestr("feedback_bundle/metadata.json", json.dumps({"bundle_version": "1.0"}))
result = extract_bundle(buf.getvalue())
assert result["issue_bundle"]["feedback_id"] == "test-001"
assert "test summary" in result["summary"]
print("✅ extract_bundle (valid zip) OK")

# 7. GitHub notification filter
_orig_repo = _m.GITHUB_REPOSITORY
_m.GITHUB_REPOSITORY = "darkrio326/AutoLedgerRio"
assert is_github_notification("[darkrio326/AutoLedgerRio] PR opened by copilot"), \
    "Should detect GitHub notification label"
assert is_github_notification("[darkrio326/AutoLedgerRio] Some issue title"), \
    "Should detect GitHub notification label (issue)"
assert not is_github_notification("[AutoLedger][L2][iOS][1.1.0(10)][ocr_parse_wrong] 金额识别错误"), \
    "Should not flag a legitimate feedback email"
assert not is_github_notification("Re: unrelated email"), \
    "Should not flag an unrelated email"
_m.GITHUB_REPOSITORY = _orig_repo
print("✅ is_github_notification OK")

print("\n🎉 All tests passed!")
