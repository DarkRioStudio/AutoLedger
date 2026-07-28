#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import re
import sys
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / "docs"
DOC_CATEGORIES = {
    "product",
    "architecture",
    "capabilities",
    "platforms",
    "operations",
    "archive",
}
ROOT_DOCS = {"README.md", "ROADMAP.md"}


def require(text: str, snippet: str, label: str, failures: list[str]) -> None:
    if snippet not in text:
        failures.append(f"{label} missing snippet: {snippet}")


def markdown_link_failures(path: Path) -> list[str]:
    failures: list[str] = []
    source = path.read_text(encoding="utf-8")
    for raw_target in re.findall(r"\[[^\]]*\]\(([^)\n]+)\)", source):
        target = raw_target.strip().split(maxsplit=1)[0].strip("<>")
        if not target or target.startswith(("#", "http://", "https://", "mailto:", "/")):
            continue
        relative_target = unquote(target.split("#", 1)[0])
        if not relative_target:
            continue
        resolved = (path.parent / relative_target).resolve()
        if not resolved.exists():
            failures.append(f"{path.relative_to(ROOT)} has broken link: {target}")
    return failures


def main() -> int:
    failures: list[str] = []

    required_truth_files = [
        ROOT / "PROJECT_STATUS.md",
        DOCS / "ROADMAP.md",
        DOCS / "product" / "GLOBAL_PRODUCT_STRATEGY.md",
        DOCS / "product" / "I18N_ROADMAP.md",
        DOCS / "README.md",
        ROOT / "versions" / "v1.7.0-plan.md",
        ROOT / "versions" / "v1.7.0-i18n-release-matrix.md",
        ROOT / "versions" / "v1.8.0-plan.md",
        ROOT / "versions" / "v1.8.0-i18n-release-matrix.md",
    ]
    for path in required_truth_files:
        if not path.exists():
            failures.append(f"missing truth-source document: {path.relative_to(ROOT)}")

    if failures:
        print("Documentation truth-source smoke failed:")
        for failure in failures:
            print(f" - {failure}")
        return 1

    project_status = (ROOT / "PROJECT_STATUS.md").read_text(encoding="utf-8")
    readme_cn = (ROOT / "README.md").read_text(encoding="utf-8")
    roadmap = (DOCS / "ROADMAP.md").read_text(encoding="utf-8")
    i18n_roadmap = (DOCS / "product" / "I18N_ROADMAP.md").read_text(encoding="utf-8")
    docs_index = (DOCS / "README.md").read_text(encoding="utf-8")
    v17_plan = (ROOT / "versions" / "v1.7.0-plan.md").read_text(encoding="utf-8")
    v17_i18n = (ROOT / "versions" / "v1.7.0-i18n-release-matrix.md").read_text(encoding="utf-8")
    v18_plan = (ROOT / "versions" / "v1.8.0-plan.md").read_text(encoding="utf-8")
    v18_i18n = (ROOT / "versions" / "v1.8.0-i18n-release-matrix.md").read_text(encoding="utf-8")

    for snippet in [
        "文档状态：Canonical",
        "docs/ROADMAP.md",
        "docs/product/GLOBAL_PRODUCT_STRATEGY.md",
        "docs/product/I18N_ROADMAP.md",
        "versions/v1.7.0-plan.md",
        "## v1.7.0 Release Closeout",
        "## Source Of Truth Map",
    ]:
        require(project_status, snippet, "PROJECT_STATUS.md", failures)

    for snippet in [
        "文档状态：Canonical",
        "../PROJECT_STATUS.md",
        "product/GLOBAL_PRODUCT_STRATEGY.md",
        "## Roadmap Horizon",
        "### Released - v1.7.0 / ASC 1.6.0",
        "### Now - Ship v1.8.0 / ASC 1.7.0: Global Readiness & Review/Close",
        "## Language Expansion Cadence",
        "### Not Planned",
        "## Source Of Truth Boundaries",
    ]:
        require(roadmap, snippet, "docs/ROADMAP.md", failures)

    for snippet in [
        "文档状态：Canonical",
        "## English Primary Language",
        "语言 / 市场能力",
        "`v1.8.0`",
        "`v1.8.0` 改为英语五市场质量组",
        "## Six Release Gates",
    ]:
        require(i18n_roadmap, snippet, "docs/product/I18N_ROADMAP.md", failures)

    for snippet in [
        "docs/",
        "├── ROADMAP.md",
        "product/GLOBAL_PRODUCT_STRATEGY.md",
        "product/I18N_ROADMAP.md",
        "architecture/LedgerTextInterpreter.md",
        "operations/pro-access-audit.md",
        "archive/MVP1.0.md",
        "核心路线图是唯一允许",
    ]:
        require(docs_index, snippet, "docs/README.md", failures)

    for snippet in [
        "docs/product/I18N_ROADMAP.md",
        "Primary Language",
        "`v1.8.0` 改为美国、英国、加拿大、澳大利亚和新加坡英语市场质量组",
        "不改变本版本只新增韩语的历史范围",
    ]:
        require(v17_plan, snippet, "versions/v1.7.0-plan.md", failures)

    for snippet in [
        "文档状态：Released Snapshot",
        "## English Primary Language Gate",
        "`English (U.S.) / en-US`",
        "## Scheduled Cohorts",
        "不新增 UI 语言",
    ]:
        require(v17_i18n, snippet, "versions/v1.7.0-i18n-release-matrix.md", failures)

    for snippet in [
        "文档状态：Draft / Early Execution",
        "Review & Close",
        "### 1. Global Foundation",
        "### 6. English-Market Cohort",
        "`GOAL-2460`",
        "`GOAL-2470`",
    ]:
        require(v18_plan, snippet, "versions/v1.8.0-plan.md", failures)

    for snippet in [
        "文档状态：Draft",
        "## Market Contract",
        "United States",
        "Singapore",
        "## Market-Gate Matrix",
    ]:
        require(v18_i18n, snippet, "versions/v1.8.0-i18n-release-matrix.md", failures)

    for snippet in [
        "https://apps.apple.com/app/id6761892533",
        "https://testflight.apple.com/join/T3Wu6ngk",
        "## 下载与 TestFlight",
    ]:
        require(readme_cn, snippet, "README.md", failures)

    docs_files = sorted(DOCS.rglob("*.md"))
    allowed_statuses = {"Canonical", "Active", "Reference", "Draft", "Historical", "Superseded"}
    for path in docs_files:
        relative_doc = path.relative_to(DOCS).as_posix()
        relative_parts = Path(relative_doc).parts
        if len(relative_parts) == 1:
            if relative_doc not in ROOT_DOCS:
                failures.append(
                    f"{path.relative_to(ROOT)} must be moved into a docs category directory"
                )
        elif len(relative_parts) != 2 or relative_parts[0] not in DOC_CATEGORIES:
            failures.append(
                f"{path.relative_to(ROOT)} is outside the allowed docs category layout"
            )

        header = "\n".join(path.read_text(encoding="utf-8").splitlines()[:12])
        status_match = re.search(
            r"(?:文档状态|Document status)\s*[:：]\s*([A-Za-z]+)",
            header,
        )
        if status_match is None:
            failures.append(f"{path.relative_to(ROOT)} is missing lifecycle status in its first 12 lines")
        else:
            status = status_match.group(1)
            if status not in allowed_statuses:
                failures.append(f"{path.relative_to(ROOT)} has unsupported lifecycle status: {status}")
            if path.name != "README.md":
                index_row = re.compile(
                    rf"\|\s*\[{re.escape(relative_doc)}\]\({re.escape(relative_doc)}\)\s*\|\s*{re.escape(status)}\s*\|"
                )
                if index_row.search(docs_index) is None:
                    failures.append(
                        f"docs/README.md lifecycle status does not match {relative_doc}: {status}"
                    )
        if path.name != "README.md" and f"({relative_doc})" not in docs_index:
            failures.append(f"docs/README.md does not index {relative_doc}")

    for readme_name in ["README.md", "README.zh-Hant.md", "README.en.md", "README.ja.md"]:
        readme = (ROOT / readme_name).read_text(encoding="utf-8")
        require(readme, "(PROJECT_STATUS.md)", readme_name, failures)
        require(readme, "(docs/ROADMAP.md)", readme_name, failures)
        require(readme, "(docs/product/I18N_ROADMAP.md)", readme_name, failures)
        require(readme, "https://apps.apple.com/app/id6761892533", readme_name, failures)
        require(readme, "https://testflight.apple.com/join/T3Wu6ngk", readme_name, failures)

    stale_checks = {
        DOCS / "operations" / "pro-access-audit.md": [
            "No current call site uploads this payload",
            "does not call a Worker endpoint",
        ],
        DOCS / "product" / "autoledger-personal-pro-roadmap.md": [
            "当前版本不上传账本数据",
        ],
        ROOT / "README.en.md": ["Later Pro directions include cloud-assisted cleanup"],
        ROOT / "README.zh-Hant.md": ["後續會繼續推進雲端輔助整理"],
        ROOT / "README.ja.md": ["今後はクラウド補助整理"],
        ROOT / "README.md": [
            "https://apps.apple.com/us/app/autoledger-quick-ledger/id6761892533",
        ],
    }
    for path, stale_snippets in stale_checks.items():
        source = path.read_text(encoding="utf-8")
        for snippet in stale_snippets:
            if snippet in source:
                failures.append(f"{path.relative_to(ROOT)} still contains stale current-state copy: {snippet}")

    link_scopes = [
        ROOT / "AGENTS.md",
        ROOT / "PROJECT_STATUS.md",
        ROOT / "versions" / "v1.7.0-plan.md",
        ROOT / "versions" / "v1.7.0-i18n-release-matrix.md",
        ROOT / "versions" / "v1.8.0-plan.md",
        ROOT / "versions" / "v1.8.0-i18n-release-matrix.md",
        ROOT / "AutoLedgerCoreKit" / "README.md",
        ROOT / "ReceiptDebugTool" / "README.md",
    ]
    link_scopes += [ROOT / name for name in ["README.md", "README.zh-Hant.md", "README.en.md", "README.ja.md"]]
    link_scopes += docs_files
    for path in link_scopes:
        failures.extend(markdown_link_failures(path))

    if failures:
        print("Documentation truth-source smoke failed:")
        for failure in failures:
            print(f" - {failure}")
        return 1

    print("Documentation truth-source smoke passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
