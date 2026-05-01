"""GPT-driven audit→recommendation bridge with rule-based fallback.

The LLM never writes XML — it returns a strictly-typed JSON object that the
deterministic builder in `hardening/builder.py` turns into a `.mobileconfig`.

When `OPENAI_API_KEY` is not set (or any OpenAI call fails), we fall back to
a rule-based recommendation derived directly from the findings' `suggested_payloads`.
"""
from __future__ import annotations

import json
import os

from ..audit.rules import AuditReport, Severity, severity_rank
from .schema import HardeningRecommendation, PayloadRecommendation, ALLOWED_PAYLOAD_TYPES

DEFAULT_MODEL = os.environ.get("OPENAI_MODEL", "gpt-5")

# "Anonymous lockdown" payload — applied when no Apple ID is detected, to
# silence every Apple endpoint that would otherwise leak metadata unauthen-
# ticated. Each key is a documented Restrictions/applicationaccess flag.
ANONYMOUS_LOCKDOWN_FIELDS: dict[str, bool] = {
    # Telemetry & tracking
    "allowDiagnosticSubmission": False,
    "allowDiagnosticSubmissionModification": False,
    "forceLimitAdTracking": True,
    "allowApplePersonalizedAdvertising": False,
    # Siri / dictation phone-home
    "allowSiriServerLogging": False,
    "allowAssistantUserGeneratedContent": False,
    "allowDictation": False,
    # Spotlight / Safari (web suggestions hit Apple)
    "allowSpotlightInternetResults": False,
    "safariAllowAutoFill": False,
    # iCloud sync surfaces (Apple-ID-gated, but defence in depth)
    "allowCloudBackup": False,
    "allowCloudDocumentSync": False,
    "allowCloudPhotoLibrary": False,
    "allowCloudKeychainSync": False,
    "allowMyPhotoStream": False,
    "allowSharedStream": False,
    # Apple-ID-gated services
    "allowGameCenter": False,
    "allowFindMyDevice": False,
    "allowFindMyFriends": False,
}

SYSTEM_PROMPT = f"""You are an iOS security advisor. You receive a JSON audit
report listing findings about an iPhone (prior-compromise indicators, posture
weaknesses, privacy leaks, network risks). Your job is to recommend a set of
configuration profile payloads to harden the device.

Constraints:
- Only recommend payload types from this allowlist:
  {", ".join(ALLOWED_PAYLOAD_TYPES)}
- Each payload's `fields` must contain only valid Apple-documented keys.
- Tie every recommendation to specific finding IDs from the input.
- For findings about prior compromise (stalkerware, MDM, root CA, MobileGestalt
  tampering), DO NOT try to remediate via profile — surface in user_actions
  instead ("Remove the unauthorized profile manually", "Factory restore the
  device", etc.).
- Recommend a profile that makes sense for the SPECIFIC findings, not a
  generic one-size-fits-all.

Return a JSON object matching the HardeningRecommendation schema exactly.
"""


def get_advice(report: AuditReport, model: str | None = None) -> HardeningRecommendation:
    """Call the LLM if a key is available; otherwise fall back to rules."""
    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        return rule_based_fallback(report)
    try:
        return _call_openai(report, model or DEFAULT_MODEL, api_key)
    except Exception:
        return rule_based_fallback(report)


def _call_openai(report: AuditReport, model: str, api_key: str) -> HardeningRecommendation:
    from openai import OpenAI

    client = OpenAI(api_key=api_key)

    payload = {
        "device_model": report.device_model,
        "ios_version": report.ios_version,
        "findings": [f.to_dict() for f in report.findings],
    }

    response = client.chat.completions.create(
        model=model,
        response_format={
            "type": "json_schema",
            "json_schema": {
                "name": "HardeningRecommendation",
                "schema": HardeningRecommendation.model_json_schema(),
                "strict": True,
            },
        },
        messages=[
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": json.dumps(payload, default=str)},
        ],
    )

    raw = response.choices[0].message.content or "{}"
    return HardeningRecommendation.model_validate_json(raw)


def rule_based_fallback(report: AuditReport) -> HardeningRecommendation:
    """Deterministic fallback when no API key is present or OpenAI fails."""
    payloads: list[PayloadRecommendation] = []
    user_actions: list[str] = []
    deferred: list[str] = []

    has_no_passcode = any(f.id == "posture.no_passcode" for f in report.findings)
    has_weak_passcode = any(f.id == "posture.weak_passcode" for f in report.findings)
    has_unencrypted_backup = any(f.id == "posture.unencrypted_backup" for f in report.findings)
    no_apple_id = any(f.id == "posture.no_apple_id" for f in report.findings)

    if has_no_passcode or has_weak_passcode:
        payloads.append(
            PayloadRecommendation(
                payload_type="com.apple.passcode",
                rationale=(
                    "Enforce alphanumeric passcode of at least 8 characters with "
                    "auto-erase after 10 failed attempts."
                ),
                fields={
                    "forcePIN": True,
                    "requireAlphanumeric": True,
                    "minLength": 8,
                    "minComplexChars": 2,
                    "maxFailedAttempts": 10,
                    "maxInactivity": 2,
                    "maxGracePeriod": 0,
                    "pinHistory": 5,
                },
                addresses_finding_ids=[
                    f.id for f in report.findings
                    if f.id in ("posture.no_passcode", "posture.weak_passcode")
                ],
            )
        )

    payloads.append(
        PayloadRecommendation(
            payload_type="com.apple.applicationaccess",
            rationale="Bulk privacy and lockscreen restrictions.",
            fields={
                "allowAirDrop": False,
                "allowAssistantWhileLocked": False,
                "allowLockScreenControlCenter": False,
                "allowLockScreenNotificationsView": False,
                "allowLockScreenTodayView": False,
                "allowPasscodeModification": False,
                "forceLimitAdTracking": True,
                "allowDiagnosticSubmission": False,
                "allowDiagnosticSubmissionModification": False,
                "allowSiriServerLogging": False,
                "allowCloudKeychainSync": False,
                "forceEncryptedBackup": True,
                "allowEnterpriseAppTrust": False,
                "allowProximitySetupToNewDevice": False,
                "allowAutoUnlock": False,
                "safariForceFraudWarning": True,
            },
            addresses_finding_ids=[
                f.id for f in report.findings
                if f.category.value in ("posture", "privacy_leak")
            ],
        )
    )

    if no_apple_id:
        payloads.append(
            PayloadRecommendation(
                payload_type="com.apple.applicationaccess",
                rationale=(
                    "No Apple ID detected. Disable every Apple endpoint that "
                    "would still phone home unauthenticated: Siri/dictation "
                    "server logging, Spotlight web suggestions, ad "
                    "personalization, iCloud sync surfaces, Game Center, "
                    "Find My, Safari autofill telemetry. Goal: device emits "
                    "no metadata to Apple beyond what Activation strictly "
                    "requires."
                ),
                fields=ANONYMOUS_LOCKDOWN_FIELDS,
                addresses_finding_ids=["posture.no_apple_id"],
            )
        )

    if has_unencrypted_backup:
        user_actions.append(
            "Set a strong backup encryption password in Finder while the iPhone "
            "is connected (Encrypt local backup checkbox), or use "
            "`iphone-audit harden --enable-backup-encryption` to flip the "
            "device-side flag and store the password in Keychain."
        )

    user_actions.append("Enable Lockdown Mode: Settings → Privacy & Security → Lockdown Mode")
    user_actions.append(
        "Enable Stolen Device Protection: Settings → Face ID & Passcode → Stolen Device Protection"
    )

    if no_apple_id:
        user_actions.extend([
            "Disable Improve Siri & Dictation: Settings → Privacy & Security → Analytics & Improvements",
            "Disable Share Across Devices: Settings → Privacy & Security → Analytics & Improvements",
            "Disable iCloud Private Relay if you don't use it: Settings → Apple ID → iCloud → Private Relay",
            "Set DNS to a non-Apple resolver (Quad9, NextDNS, AdGuard) at the network level",
            "Disable Siri entirely if not used: Settings → Siri & Search",
            "Disable Spotlight Suggestions: Settings → Siri & Search → toggle off Suggestions in Look Up / Search",
            "Disable Significant Locations: Settings → Privacy & Security → Location Services → System Services",
            "Block Apple's analytics endpoints at your DNS resolver: gsa.apple.com, gs-loc.apple.com, identity.apple.com (do not block ocsp.apple.com — required for code-signing)",
        ])

    for f in report.findings:
        if f.category.value != "prior_compromise":
            continue
        deferred.append(f.id)
        if f.id.startswith("stalkerware"):
            product = f.evidence.get("product") or f.evidence.get("bundle_id")
            user_actions.append(
                f"CRITICAL: Remove the suspected stalkerware app: {product}. "
                "Verify the device has no other compromise indicators after removal."
            )
        elif f.id.startswith("profile.mdm"):
            user_actions.append(
                f"Verify MDM enrollment ({f.title}). Remove via Settings → "
                "General → VPN & Device Management if not legitimate."
            )
        elif f.id.startswith("profile.root_ca"):
            user_actions.append(
                f"Remove untrusted CA ({f.title}) via Settings → General → "
                "VPN & Device Management."
            )
        elif f.id == "gestalt.mismatch":
            user_actions.append(
                "MobileGestalt tampering detected. Consider a clean restore via "
                "Finder or Apple Configurator 2."
            )

    if report.findings:
        max_sev = max(report.findings, key=lambda f: severity_rank(f.severity)).severity
    else:
        max_sev = Severity.INFO

    risk_level = {
        "info": "low",
        "low": "low",
        "medium": "medium",
        "high": "high",
        "critical": "critical",
    }[max_sev.value]

    summary = (
        f"Found {len(report.findings)} finding(s) on "
        f"{report.device_model} (iOS {report.ios_version}). "
        f"Generated rule-based recommendation; max severity: {max_sev.value}."
    )

    return HardeningRecommendation(
        summary=summary,
        risk_level=risk_level,
        payloads=payloads,
        user_actions=user_actions,
        deferred_findings=deferred,
    )
