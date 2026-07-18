#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
TOOL = ROOT / "tools" / "asc-metadata"


def require(text: str, snippet: str, label: str, failures: list[str]) -> None:
    if snippet not in text:
        failures.append(f"{label} missing snippet: {snippet}")


def yaml_block_scalar(text: str, key: str) -> str:
    marker = f"    {key}: |-"
    lines = text.splitlines()
    try:
        start = lines.index(marker) + 1
    except ValueError:
        return ""

    value: list[str] = []
    for line in lines[start:]:
        if line and not line.startswith("      "):
            break
        value.append(line[6:] if line.startswith("      ") else "")
    return "\n".join(value).rstrip()


def main() -> int:
    failures: list[str] = []
    script = (TOOL / "asc_metadata.rb").read_text(encoding="utf-8")
    screenshot_uploader = (TOOL / "asc_screenshot_upload.rb").read_text(encoding="utf-8")
    preview_uploader_path = TOOL / "asc_app_preview_upload.rb"
    preview_uploader = preview_uploader_path.read_text(encoding="utf-8") if preview_uploader_path.exists() else ""
    build_binder_path = TOOL / "asc_build_bind.rb"
    build_binder = build_binder_path.read_text(encoding="utf-8") if build_binder_path.exists() else ""
    readme = (TOOL / "README.md").read_text(encoding="utf-8")
    config_path = TOOL / "metadata.yml"

    if not config_path.exists():
        failures.append("tools/asc-metadata/metadata.yml is missing")
        config = ""
    else:
        config = config_path.read_text(encoding="utf-8")

    for snippet in [
        'when "push-config"',
        'when "export-config"',
        'when "create-version"',
        "def push_config",
        "def export_config",
        "def create_version",
        'attrs["appStoreState"] == "PREPARE_FOR_SUBMISSION"',
        "YAML.safe_load",
        "subscriptionGroupLocalizations",
        "subscriptionLocalizations",
        "appStoreReviewDetails",
        "push_review_notes_config",
        "print_review_details",
        "appStoreVersionLocalizations",
        "appInfoLocalizations",
        "DRY-RUN",
        'DEFAULT_VERSION = "1.6.0"',
        "zh-Hans zh-Hant en-US ja ko",
    ]:
        require(script, snippet, "asc_metadata.rb", failures)

    for snippet in [
        "push-config",
        "export-config",
        "create-version",
        "--source-version",
        "--output",
        "--skip-app-info",
        "--shared-create-only",
        "--locale",
        "metadata.yml",
        "--config",
        "dry-run",
        "subscription",
        "asc_app_preview_upload.rb",
        "videoDeliveryState",
        "asc_build_bind.rb",
    ]:
        require(readme, snippet, "ASC metadata README", failures)

    for snippet in [
        "app_id:",
        "version:",
        "planned_locales:",
        "app_info:",
        "version_localizations:",
        "subscription_group:",
        "subscriptions:",
        "review_notes:",
        "platform_profiles:",
        "IOS: main",
        "TV_OS: readonly",
        "top.darkrio326.AutoLedger.pro.monthly",
        "top.darkrio326.AutoLedger.pro.yearly",
        "ko:",
    ]:
        require(config, snippet, "metadata.yml", failures)

    for locale in ["zh-Hans", "zh-Hant", "en-US", "ja", "ko"]:
        require(config, f"{locale}:", "metadata.yml", failures)

    for snippet in [
        "TRANSIENT_HTTP_CODES",
        "with_retry",
        "upload_operations",
        "wait_for_screenshot_set",
        "screenshots_processing?",
        "state=COMPLETE",
    ]:
        require(screenshot_uploader, snippet, "ASC screenshot uploader", failures)

    for snippet in [
        "appPreviewSets",
        "appPreviews",
        "sourceFileChecksum",
        "videoDeliveryState",
        "previewFrameTimeCode",
        "--poster-frame-time-code",
        "wait_for_poster_frame",
        "wait_for_preview",
        "delete_stale",
        "COMPLETE",
    ]:
        require(preview_uploader, snippet, "ASC App Preview uploader", failures)

    for snippet in [
        "--build-number",
        "--expected-source-commit",
        "ciProduct",
        "buildRuns",
        "APP_STORE_ELIGIBLE",
        "PREPARE_FOR_SUBMISSION",
        "relationships/build",
        "verified",
    ]:
        require(build_binder, snippet, "ASC build binder", failures)

    subscription_block = config.split("\nsubscriptions:", 1)[1] if "\nsubscriptions:" in config else ""
    descriptions = re.findall(r'description:\s*"([^"]+)"', subscription_block)
    over_limit = [text for text in descriptions if len(text) > 55]
    if over_limit:
        failures.append("subscription descriptions must stay within ASC 55-character limit")

    for profile in ["main", "readonly"]:
        review_notes = yaml_block_scalar(config, profile)
        if not review_notes:
            failures.append(f"review note profile {profile} must not be empty")
            continue
        if len(review_notes) > 4000:
            failures.append(f"review note profile {profile} exceeds ASC 4000-character limit")
        for sensitive_term in ["ASC_ISSUER_ID", "ASC_PRIVATE_KEY", "BEGIN PRIVATE KEY"]:
            if sensitive_term in review_notes:
                failures.append(f"review note profile {profile} contains forbidden secret marker")

    main_review_notes = yaml_block_scalar(config, "main")
    readonly_review_notes = yaml_block_scalar(config, "readonly")
    for snippet in [
        "No demo account is required",
        "Crash Data, Performance Data, and Product Interaction",
        "not linked",
        "not used for tracking",
    ]:
        require(main_review_notes, snippet, "main review notes", failures)
        require(readonly_review_notes, snippet, "readonly review notes", failures)

    if failures:
        print("ASC metadata-as-code smoke failed:")
        for failure in failures:
            print(f" - {failure}")
        return 1

    print("ASC metadata-as-code smoke passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
