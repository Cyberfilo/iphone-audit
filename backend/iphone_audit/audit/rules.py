"""Audit orchestration. Findings carry severity, category, evidence, and
optional suggested payload types that the LLM/rule-based advisor can use.
"""
from __future__ import annotations

import json
from dataclasses import dataclass, field, asdict
from enum import Enum

from ..extraction import lockdown as ext_lockdown
from ..extraction import profiles as ext_profiles
from ..extraction import apps as ext_apps
from ..extraction.lockdown import LockdownSnapshot
from ..extraction.profiles import InstalledProfile
from ..extraction.apps import InstalledApp


class Severity(str, Enum):
    INFO = "info"
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"


class Category(str, Enum):
    PRIOR_COMPROMISE = "prior_compromise"
    POSTURE = "posture"
    PRIVACY_LEAK = "privacy_leak"
    NETWORK = "network"
    PHYSICAL = "physical"
    INFORMATIONAL = "informational"


_SEVERITY_ORDER = {
    Severity.INFO: 0,
    Severity.LOW: 1,
    Severity.MEDIUM: 2,
    Severity.HIGH: 3,
    Severity.CRITICAL: 4,
}


def severity_rank(s: Severity) -> int:
    return _SEVERITY_ORDER[s]


@dataclass
class Finding:
    id: str
    severity: Severity
    category: Category
    title: str
    description: str
    evidence: dict = field(default_factory=dict)
    suggested_payloads: list[str] = field(default_factory=list)

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "severity": self.severity.value,
            "category": self.category.value,
            "title": self.title,
            "description": self.description,
            "evidence": self.evidence,
            "suggested_payloads": list(self.suggested_payloads),
        }


@dataclass
class AuditReport:
    udid: str
    device_model: str
    ios_version: str
    findings: list[Finding] = field(default_factory=list)
    raw_extraction: dict = field(default_factory=dict)

    def max_severity(self) -> Severity:
        if not self.findings:
            return Severity.INFO
        return max(self.findings, key=lambda f: severity_rank(f.severity)).severity

    def to_dict(self) -> dict:
        return {
            "udid": self.udid,
            "device_model": self.device_model,
            "ios_version": self.ios_version,
            "findings": [f.to_dict() for f in self.findings],
            "raw_extraction": self.raw_extraction,
        }

    def to_json(self, indent: int = 2) -> str:
        return json.dumps(self.to_dict(), default=str, indent=indent)


def run_quick_audit(udid: str) -> AuditReport:
    """Quick scan: lockdown identity + profiles + apps; no backup."""
    from . import stalkerware, pairing, gestalt, posture, profiles as audit_profiles, entitlements

    snap = ext_lockdown.snapshot(udid)
    if snap.error:
        return AuditReport(
            udid=udid,
            device_model="unknown",
            ios_version="unknown",
            findings=[
                Finding(
                    id="extraction.lockdown_failed",
                    severity=Severity.HIGH,
                    category=Category.INFORMATIONAL,
                    title="Could not contact device",
                    description=f"Lockdown extraction failed: {snap.error}",
                    evidence={"udid": udid, "error": snap.error},
                )
            ],
            raw_extraction={"lockdown": snap.to_dict()},
        )

    try:
        profs = ext_profiles.list_profiles(udid)
    except Exception as exc:
        profs = []
        profile_error = str(exc)
    else:
        profile_error = None

    try:
        app_list = ext_apps.list_apps(udid)
    except Exception as exc:
        app_list = []
        app_error = str(exc)
    else:
        app_error = None

    report = AuditReport(
        udid=udid,
        device_model=snap.identity.get("ProductType", "unknown"),
        ios_version=snap.identity.get("ProductVersion", "unknown"),
    )
    report.raw_extraction = {
        "lockdown": snap.to_dict(),
        "profiles": [p.to_dict() for p in profs],
        "profiles_error": profile_error,
        "apps": [a.to_dict() for a in app_list],
        "apps_error": app_error,
    }

    if profile_error:
        report.findings.append(
            Finding(
                id="extraction.profiles_failed",
                severity=Severity.LOW,
                category=Category.INFORMATIONAL,
                title="Could not enumerate configuration profiles",
                description=profile_error,
                evidence={"error": profile_error},
            )
        )
    if app_error:
        report.findings.append(
            Finding(
                id="extraction.apps_failed",
                severity=Severity.LOW,
                category=Category.INFORMATIONAL,
                title="Could not enumerate installed apps",
                description=app_error,
                evidence={"error": app_error},
            )
        )

    report.findings.extend(stalkerware.check(app_list))
    report.findings.extend(audit_profiles.check(profs))
    report.findings.extend(entitlements.check(app_list))
    report.findings.extend(pairing.check_mac_side(udid))
    report.findings.extend(posture.check(snap))
    report.findings.extend(gestalt.check(udid, snap))

    return report
