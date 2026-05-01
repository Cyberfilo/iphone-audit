"""MobileGestalt integrity check vs known-good per-build baseline.

Apple removed the diagnostics MobileGestalt endpoint on iOS 17.4+. All three
of our target devices are above that threshold, so this audit will most often
emit an INFO finding explaining the limitation rather than running the actual
comparison. We keep the comparison path because the user may seed baselines
from a pre-17.4 device, and because the function is the right place to plug
a future fallback (e.g., hashing the same fields via lockdown domain queries).
"""
from __future__ import annotations

import json
from pathlib import Path

from ..extraction.lockdown import LockdownSnapshot
from .rules import Finding, Severity, Category

BASELINE_DIR = Path(__file__).resolve().parent.parent / "data" / "mobilegestalt_baselines"

GESTALT_KEYS = [
    "BootChimeIsEnabled",
    "DeviceSupportsLandscape",
    "DynamicIslandCapability",
    "DeviceSupportsApplePencil",
    "ApplePencilCapability",
    "ShutterClickConfiguration",
    "StageManagerSupported",
    "MainScreenWidth",
    "MainScreenHeight",
]


def _baseline_path(model: str, build: str, baseline_dir: Path = BASELINE_DIR) -> Path:
    return baseline_dir / f"{model}_{build}.json"


def _is_ios_17_4_or_later(version: str) -> bool:
    """Best-effort version compare. iOS versions look like '18.6.2' or '26.3.1'."""
    if not version:
        return False
    try:
        parts = [int(p) for p in version.split(".") if p.isdigit()]
    except ValueError:
        return False
    if not parts:
        return False
    if parts[0] > 17:
        return True
    if parts[0] == 17:
        return len(parts) >= 2 and parts[1] >= 4
    return False


def query_gestalt(udid: str, keys: list[str] = GESTALT_KEYS) -> dict | None:
    """Query MobileGestalt. Returns None if endpoint is unavailable on this iOS."""
    from pymobiledevice3.lockdown import create_using_usbmux
    from pymobiledevice3.services.diagnostics import DiagnosticsService

    try:
        client = create_using_usbmux(serial=udid)
        svc = DiagnosticsService(lockdown=client)
        return svc.mobilegestalt(keys=list(keys))
    except Exception:
        return None


def check(udid: str, snap: LockdownSnapshot, baseline_dir: Path = BASELINE_DIR) -> list[Finding]:
    findings: list[Finding] = []
    model = snap.identity.get("ProductType", "")
    build = snap.identity.get("BuildVersion", "")
    version = snap.identity.get("ProductVersion", "")

    if not model or not build:
        return findings

    if _is_ios_17_4_or_later(version):
        findings.append(
            Finding(
                id="gestalt.unavailable_modern_ios",
                severity=Severity.INFO,
                category=Category.INFORMATIONAL,
                title="MobileGestalt query unavailable on iOS ≥ 17.4",
                description=(
                    "Apple removed the diagnostics MobileGestalt endpoint in iOS 17.4. "
                    "We cannot directly verify MobileGestalt feature flags via this "
                    "service on this device. SparseRestore-style tampering detection "
                    "via this path is therefore unavailable; other audit checks "
                    "remain in effect."
                ),
                evidence={"ios_version": version, "model": model},
            )
        )
        return findings

    baseline = _baseline_path(model, build, baseline_dir)
    if not baseline.exists():
        findings.append(
            Finding(
                id="gestalt.no_baseline",
                severity=Severity.INFO,
                category=Category.INFORMATIONAL,
                title=f"No MobileGestalt baseline for {model} build {build}",
                description=(
                    "We cannot verify MobileGestalt integrity without a known-good "
                    "baseline for this exact (model, build) tuple. Seed one with "
                    "`backend/scripts/seed_baseline.py --udid <UDID>` against a "
                    "freshly restored device."
                ),
                evidence={"model": model, "build": build, "expected_path": str(baseline)},
            )
        )
        return findings

    observed = query_gestalt(udid)
    if observed is None:
        findings.append(
            Finding(
                id="gestalt.query_failed",
                severity=Severity.LOW,
                category=Category.INFORMATIONAL,
                title="MobileGestalt query failed",
                description="Could not read MobileGestalt values; check device pairing and try again.",
                evidence={"model": model, "build": build},
            )
        )
        return findings

    expected = json.loads(baseline.read_text())
    diffs = {k: {"expected": expected.get(k), "observed": observed.get(k)}
             for k in GESTALT_KEYS
             if expected.get(k) != observed.get(k)}
    if diffs:
        findings.append(
            Finding(
                id="gestalt.mismatch",
                severity=Severity.HIGH,
                category=Category.PRIOR_COMPROMISE,
                title="MobileGestalt values differ from baseline",
                description=(
                    "One or more MobileGestalt feature flags differ from the "
                    "expected values for this iOS build. This is the signature "
                    "of tools like Nugget or MisakaX modifying device feature "
                    "flags via the SparseRestore exploit."
                ),
                evidence={"differences": diffs},
            )
        )
    return findings
