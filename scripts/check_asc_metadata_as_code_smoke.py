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


def main() -> int:
    failures: list[str] = []
    script = (TOOL / "asc_metadata.rb").read_text(encoding="utf-8")
    readme = (TOOL / "README.md").read_text(encoding="utf-8")
    config_path = TOOL / "metadata.yml"

    if not config_path.exists():
        failures.append("tools/asc-metadata/metadata.yml is missing")
        config = ""
    else:
        config = config_path.read_text(encoding="utf-8")

    for snippet in [
        'when "push-config"',
        "def push_config",
        "YAML.safe_load",
        "subscriptionGroupLocalizations",
        "subscriptionLocalizations",
        "appStoreVersionLocalizations",
        "appInfoLocalizations",
        "DRY-RUN",
    ]:
        require(script, snippet, "asc_metadata.rb", failures)

    for snippet in [
        "push-config",
        "metadata.yml",
        "--config",
        "dry-run",
        "subscription",
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
        "top.darkrio326.AutoLedger.pro.monthly",
        "top.darkrio326.AutoLedger.pro.yearly",
        "ko:",
    ]:
        require(config, snippet, "metadata.yml", failures)

    for locale in ["zh-Hans", "zh-Hant", "en-US", "ja", "ko"]:
        require(config, f"{locale}:", "metadata.yml", failures)

    subscription_block = config.split("\nsubscriptions:", 1)[1] if "\nsubscriptions:" in config else ""
    descriptions = re.findall(r'description:\s*"([^"]+)"', subscription_block)
    over_limit = [text for text in descriptions if len(text) > 55]
    if over_limit:
        failures.append("subscription descriptions must stay within ASC 55-character limit")

    if failures:
        print("ASC metadata-as-code smoke failed:")
        for failure in failures:
            print(f" - {failure}")
        return 1

    print("ASC metadata-as-code smoke passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
