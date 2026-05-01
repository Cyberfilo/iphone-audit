"""Stalkerware bundle-ID match against the curated DB."""
from __future__ import annotations

import json
from pathlib import Path

from ..extraction.apps import InstalledApp
from .rules import Finding, Severity, Category

DATA_FILE = Path(__file__).resolve().parent.parent / "data" / "stalkerware_bundles.json"


def _load_bundles(path: Path = DATA_FILE) -> dict:
    return json.loads(path.read_text())


def check(installed_apps: list[InstalledApp], path: Path = DATA_FILE) -> list[Finding]:
    try:
        db = _load_bundles(path)
    except FileNotFoundError:
        return [
            Finding(
                id="stalkerware.db_missing",
                severity=Severity.LOW,
                category=Category.INFORMATIONAL,
                title="Stalkerware bundle DB missing",
                description=f"Could not read {path}. Stalkerware match disabled.",
            )
        ]

    by_id = {entry["bundle_id"]: entry for entry in db.get("entries", [])}
    findings: list[Finding] = []
    for app in installed_apps:
        entry = by_id.get(app.bundle_id)
        if entry is None:
            continue
        findings.append(
            Finding(
                id=f"stalkerware.{app.bundle_id}",
                severity=Severity.CRITICAL,
                category=Category.PRIOR_COMPROMISE,
                title=f"Known stalkerware detected: {entry['name']}",
                description=(
                    f"The bundle ID {app.bundle_id} matches a known commercial "
                    f"stalkerware product ({entry['name']}). This app is designed "
                    "to monitor the device covertly."
                ),
                evidence={
                    "bundle_id": app.bundle_id,
                    "product": entry["name"],
                    "vendor": entry.get("vendor"),
                    "references": entry.get("references", []),
                    "display_name": app.display_name,
                },
            )
        )
    return findings
