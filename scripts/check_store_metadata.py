#!/usr/bin/env python3
"""Check deliver's plain-text metadata against APPSTORE-METADATA.md."""

import re
import sys
from pathlib import Path


def metadata_values(document):
    def section(heading):
        match = re.search(
            rf"^## {re.escape(heading)}\n\n(.*?)(?=^## |\Z)",
            document,
            re.MULTILINE | re.DOTALL,
        )
        if not match:
            raise ValueError(f"Missing metadata section: {heading}")
        return match.group(1).strip()

    def field(label):
        match = re.search(rf"^\| \*\*{re.escape(label)}\*\* \| (.*?) \|$", document, re.MULTILINE)
        if not match:
            raise ValueError(f"Missing identity field: {label}")
        return match.group(1)

    def fenced(heading):
        match = re.fullmatch(r"```text\n(.*?)\n```", section(heading), re.DOTALL)
        if not match:
            raise ValueError(f"Expected one text block in: {heading}")
        return match.group(1)

    values = {
        "name": field("Name"),
        "subtitle": field("Subtitle"),
        "description": section("Description"),
        "keywords": fenced("Keywords"),
        "promotional_text": fenced("Promotional Text"),
        "support_url": section("Support URL"),
        "privacy_url": section("Privacy Policy URL"),
        "release_notes": "Initial release.",
        "copyright": section("Copyright"),
    }
    if re.search(r"^## Marketing URL$", document, re.MULTILINE):
        values["marketing_url"] = section("Marketing URL")
    return values


def check_metadata(root):
    document = (root / "APPSTORE-METADATA.md").read_text(encoding="utf-8")
    values = metadata_values(document)
    directory = root / "fastlane/metadata"
    errors = []
    for name in values.keys() - {"copyright"}:
        path = directory / "en-US" / f"{name}.txt"
        if not path.is_file():
            errors.append(f"Missing deliver metadata: {path.relative_to(root)}")
    for path in sorted(directory.rglob("*.txt")):
        if path.stem not in values:
            errors.append(f"No canonical value for: {path.relative_to(root)}")
        elif path.read_text(encoding="utf-8") != values[path.stem]:
            errors.append(f"Metadata differs: {path.relative_to(root)}")
    limits = {"name": 30, "subtitle": 30, "promotional_text": 170, "keywords": 100, "description": 4000}
    for name, limit in limits.items():
        if len(values[name]) > limit:
            errors.append(f"{name}: {len(values[name])} characters exceeds {limit}")
    return errors


if __name__ == "__main__":
    try:
        errors = check_metadata(Path(__file__).resolve().parents[1])
    except (OSError, ValueError) as error:
        errors = [str(error)]
    if errors:
        print("\n".join(errors), file=sys.stderr)
        sys.exit(1)
    print("Store metadata matches APPSTORE-METADATA.md; field limits pass.")
