"""Device security posture: passcode, encryption, supervision."""
from __future__ import annotations

from ..extraction.lockdown import LockdownSnapshot
from .rules import Finding, Severity, Category


def check(snap: LockdownSnapshot) -> list[Finding]:
    findings: list[Finding] = []
    ident = snap.identity

    pwd_protected = ident.get("PasswordProtected")
    is_alphanumeric = ident.get("PasscodeIsAlphanumeric")

    if pwd_protected is False:
        findings.append(
            Finding(
                id="posture.no_passcode",
                severity=Severity.CRITICAL,
                category=Category.POSTURE,
                title="Device has no passcode set",
                description=(
                    "Without a passcode, Data Protection is not active and "
                    "the device contents are vulnerable to physical extraction."
                ),
                suggested_payloads=["com.apple.passcode"],
            )
        )
    elif pwd_protected is None:
        # iOS 17+ restricted several lockdown identity keys including
        # PasswordProtected; pymobiledevice3 returns None instead of raising.
        # Treat "unknown" as informational rather than CRITICAL.
        findings.append(
            Finding(
                id="posture.passcode_unknown",
                severity=Severity.INFO,
                category=Category.INFORMATIONAL,
                title="Passcode state could not be read",
                description=(
                    "iOS 17+ restricts lockdown access to the PasswordProtected "
                    "key on consumer devices. We cannot determine passcode "
                    "presence via this path. Confirm in Settings → Face ID & "
                    "Passcode."
                ),
            )
        )
    elif is_alphanumeric is False:
        # Only flag weak passcode when we actually know it's numeric.
        findings.append(
            Finding(
                id="posture.weak_passcode",
                severity=Severity.MEDIUM,
                category=Category.POSTURE,
                title="Numeric-only passcode",
                description=(
                    "Numeric passcodes are vulnerable to brute-force by tools "
                    "like GrayKey. An alphanumeric passcode of 8+ characters "
                    "raises brute-force cost dramatically."
                ),
                suggested_payloads=["com.apple.passcode"],
            )
        )

    backup_state = snap.domains.get("com.apple.mobile.backup", {}) or {}
    will_encrypt = backup_state.get("WillEncrypt")
    if will_encrypt is False:
        findings.append(
            Finding(
                id="posture.unencrypted_backup",
                severity=Severity.HIGH,
                category=Category.PRIVACY_LEAK,
                title="Backup encryption is OFF",
                description=(
                    "Without backup encryption, any paired Mac can extract SMS, "
                    "photos, app data, Safari history. Backup encryption with a "
                    "strong password makes the bundle computationally inert "
                    "without the password."
                ),
                suggested_payloads=["com.apple.applicationaccess"],
            )
        )

    if ident.get("IsSupervised"):
        findings.append(
            Finding(
                id="posture.supervised",
                severity=Severity.INFO,
                category=Category.INFORMATIONAL,
                title="Device is supervised",
                description="Hardening payloads requiring supervised mode will work.",
            )
        )
    else:
        findings.append(
            Finding(
                id="posture.unsupervised",
                severity=Severity.INFO,
                category=Category.INFORMATIONAL,
                title="Device is not supervised",
                description=(
                    "Some powerful hardening payloads (always-on VPN, "
                    "allowPairingWithNonConfigurator, install-from-web blocking) "
                    "will install but silently no-op. To fully harden, consider "
                    "supervising via Apple Configurator 2 (this requires a wipe)."
                ),
            )
        )

    # Apple-ID detection — surfaces the "anonymous lockdown" recommendation.
    apple_id = detect_apple_id(snap)
    if apple_id is False:
        findings.append(
            Finding(
                id="posture.no_apple_id",
                severity=Severity.INFO,
                category=Category.INFORMATIONAL,
                title="No Apple ID signed in — extra hardening available",
                description=(
                    "No iCloud/Apple ID account was detected on this device. "
                    "Many Apple endpoints (Siri server logging, dictation, "
                    "Spotlight web suggestions, Game Center, telemetry, ad "
                    "personalization) still phone home regardless. The "
                    "'Anonymous lockdown' payload disables all of them in one "
                    "shot. Recommended: enable it on the Hardening Profile "
                    "screen before installing."
                ),
                suggested_payloads=["com.apple.applicationaccess"],
            )
        )
    elif apple_id is None:
        findings.append(
            Finding(
                id="posture.apple_id_unknown",
                severity=Severity.INFO,
                category=Category.INFORMATIONAL,
                title="Apple ID state could not be read",
                description=(
                    "iOS 17+ restricts the data_sync lockdown domain. We "
                    "cannot determine whether an Apple ID is signed in. The "
                    "'Anonymous lockdown' payload is available on the "
                    "Hardening Profile screen if you want maximum privacy."
                ),
            )
        )

    return findings


def detect_apple_id(snap: LockdownSnapshot) -> bool | None:
    """Best-effort detection of whether an Apple ID is signed in.

    Returns:
        True  — sync accounts present (Apple ID very likely signed in).
        False — sync domain readable but empty (no Apple ID).
        None  — domain not readable (typical on iOS 17+ consumer devices).

    We look at the `com.apple.mobile.data_sync` lockdown domain, which the
    sync subsystem populates with Accounts/Calendars/Contacts dicts when an
    Apple ID is signed in. iOS 17+ has tightened access on consumer devices
    so the dict may come back as an `_error` placeholder; that's our None.
    """
    sync = snap.domains.get("com.apple.mobile.data_sync")
    if sync is None:
        return None
    if isinstance(sync, dict) and "_error" in sync:
        return None
    if not sync:
        # Empty dict = no sync accounts wired up.
        return False
    return True
