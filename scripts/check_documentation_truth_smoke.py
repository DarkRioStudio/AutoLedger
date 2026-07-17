#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import re
import sys
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / "docs"


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
        DOCS / "README.md",
        ROOT / "versions" / "v1.7.0-plan.md",
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
    roadmap = (DOCS / "ROADMAP.md").read_text(encoding="utf-8")
    docs_index = (DOCS / "README.md").read_text(encoding="utf-8")

    for snippet in [
        "文档状态：Canonical",
        "docs/ROADMAP.md",
        "versions/v1.7.0-plan.md",
        "## Release Gates",
        "## Source Of Truth Map",
    ]:
        require(project_status, snippet, "PROJECT_STATUS.md", failures)

    for snippet in [
        "文档状态：Canonical",
        "../PROJECT_STATUS.md",
        "## Roadmap Horizon",
        "### Now - Ship v1.7.0 / ASC 1.6.0",
        "### Not Planned",
        "## Source Of Truth Boundaries",
    ]:
        require(roadmap, snippet, "docs/ROADMAP.md", failures)

    docs_files = sorted(DOCS.glob("*.md"))
    allowed_statuses = {"Canonical", "Active", "Reference", "Draft", "Historical", "Superseded"}
    for path in docs_files:
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
                    rf"\|\s*\[{re.escape(path.name)}\]\({re.escape(path.name)}\)\s*\|\s*{re.escape(status)}\s*\|"
                )
                if index_row.search(docs_index) is None:
                    failures.append(
                        f"docs/README.md lifecycle status does not match {path.name}: {status}"
                    )
        if path.name != "README.md" and f"({path.name})" not in docs_index:
            failures.append(f"docs/README.md does not index {path.name}")

    for readme_name in ["README.md", "README.zh-Hant.md", "README.en.md", "README.ja.md"]:
        readme = (ROOT / readme_name).read_text(encoding="utf-8")
        require(readme, "(PROJECT_STATUS.md)", readme_name, failures)
        require(readme, "(docs/ROADMAP.md)", readme_name, failures)

    stale_checks = {
        DOCS / "pro-access-audit.md": [
            "No current call site uploads this payload",
            "does not call a Worker endpoint",
        ],
        DOCS / "autoledger-personal-pro-roadmap.md": [
            "当前版本不上传账本数据",
        ],
        ROOT / "README.en.md": ["Later Pro directions include cloud-assisted cleanup"],
        ROOT / "README.zh-Hant.md": ["後續會繼續推進雲端輔助整理"],
        ROOT / "README.ja.md": ["今後はクラウド補助整理"],
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
