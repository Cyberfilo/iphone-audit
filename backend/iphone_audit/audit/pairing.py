"""Mac-side pairing record audit (/var/db/lockdown/<UDID>.plist)."""
from __future__ import annotations

import os
import plistlib
from datetime import datetime
from pathlib import Path

from .rules import Finding, Severity, Category

LOCKDOWN_DIR = Path("/var/db/lockdown")


def list_pairing_records(lockdown_dir: Path = LOCKDOWN_DIR) -> list[dict]:
    """Read pairing records visible to the current process. Requires sudo for
    full visibility on modern macOS.
    """
    out: list[dict] = []
    if not lockdown_dir.exists():
        return out
    try:
        candidates = list(lockdown_dir.glob("*.plist"))
    except PermissionError:
        return out

    for path in candidates:
        try:
            with open(path, "rb") as fh:
                record = plistlib.load(fh)
            stat = path.stat()
            out.append(
                {
                    "udid": path.stem,
                    "path": str(path),
                    "host_id": record.get("HostID"),
                    "system_buid": record.get("SystemBUID"),
                    "wifi_mac": record.get("WiFiMACAddress"),
                    "has_escrow_bag": "EscrowBag" in record,
                    "modified": datetime.fromtimestamp(stat.st_mtime).isoformat(),
                }
            )
        except (OSError, PermissionError):
            continue
    return out


def revoke_pairing(udid: str, lockdown_dir: Path = LOCKDOWN_DIR) -> bool:
    """Delete the pairing record for `udid`. Returns True on success.

    Requires elevated privileges on modern macOS.
    """
    target = lockdown_dir / f"{udid}.plist"
    if not target.exists():
        return False
    try:
        target.unlink()
        return True
    except PermissionError:
        return False


def revoke_all(lockdown_dir: Path = LOCKDOWN_DIR) -> int:
    """Delete every pairing record. Returns count deleted."""
    deleted = 0
    for path in lockdown_dir.glob("*.plist"):
        try:
            path.unlink()
            deleted += 1
        except (OSError, PermissionError):
            continue
    return deleted


def check_mac_side(current_udid: str, lockdown_dir: Path = LOCKDOWN_DIR) -> list[Finding]:
    records = list_pairing_records(lockdown_dir)
    findings: list[Finding] = []
    if not records:
        if not os.access(lockdown_dir, os.R_OK):
            findings.append(
                Finding(
                    id="pairing.no_access",
                    severity=Severity.INFO,
                    category=Category.INFORMATIONAL,
                    title="Cannot read /var/db/lockdown",
                    description="Run with elevated privileges to audit pairing records.",
                )
            )
        return findings

    others = [r for r in records if r["udid"] != current_udid]
    if others:
        findings.append(
            Finding(
                id="pairing.other_devices",
                severity=Severity.LOW,
                category=Category.INFORMATIONAL,
                title=f"This Mac has paired with {len(others)} other iPhone(s)",
                description=(
                    "Each pairing record contains an escrow bag that allows this "
                    "Mac to perform encrypted backups silently while the device "
                    "is unlocked. Consider revoking unused pairings."
                ),
                evidence={"records": others},
            )
        )
    current = next((r for r in records if r["udid"] == current_udid), None)
    if current and current["has_escrow_bag"]:
        findings.append(
            Finding(
                id="pairing.escrow_present",
                severity=Severity.INFO,
                category=Category.INFORMATIONAL,
                title="Escrow bag present for this device",
                description=(
                    "This Mac can perform encrypted backups without re-prompting "
                    "for the device passcode while the device is unlocked. "
                    "Normal for a trusted Mac. Revoke if this Mac is compromised."
                ),
                evidence={"path": current["path"]},
            )
        )
    return findings
