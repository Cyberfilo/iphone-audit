"""Payload allowlist and field validators."""
from __future__ import annotations

from ..llm.schema import ALLOWED_PAYLOAD_TYPES

# Per-payload-type allowed field keys. Conservative — anything not in this map
# is silently dropped by the builder. Extend deliberately as new keys are vetted.
ALLOWED_FIELDS: dict[str, set[str]] = {
    "com.apple.applicationaccess": {
        # Lockscreen / proximity
        "allowAirDrop",
        "allowAssistantWhileLocked",
        "allowLockScreenControlCenter",
        "allowLockScreenNotificationsView",
        "allowLockScreenTodayView",
        "allowPasscodeModification",
        "allowProximitySetupToNewDevice",
        "allowAutoUnlock",
        # Telemetry & tracking
        "allowDiagnosticSubmission",
        "allowDiagnosticSubmissionModification",
        "forceLimitAdTracking",
        "allowApplePersonalizedAdvertising",
        # Siri / dictation (these talk to Apple servers)
        "allowSiriServerLogging",
        "allowAssistantUserGeneratedContent",
        "allowDictation",
        # Spotlight / Safari telemetry
        "allowSpotlightInternetResults",
        "safariForceFraudWarning",
        "safariAllowAutoFill",
        # Backup / iCloud sync surfaces
        "forceEncryptedBackup",
        "allowCloudBackup",
        "allowCloudDocumentSync",
        "allowCloudPhotoLibrary",
        "allowCloudKeychainSync",
        "allowMyPhotoStream",
        "allowSharedStream",
        # Apple-ID-gated services (defence in depth even if no Apple ID)
        "allowGameCenter",
        "allowFindMyDevice",
        "allowFindMyFriends",
        # Enterprise trust
        "allowEnterpriseAppTrust",
        # Hardware-pairing posture
        "allowUSBRestrictedMode",
        "allowPairingWithNonConfigurator",
        # Apple Intelligence (A17+)
        "allowAIWritingTools",
        "allowAIGenmoji",
    },
    "com.apple.passcode": {
        "forcePIN",
        "requireAlphanumeric",
        "minLength",
        "minComplexChars",
        "maxFailedAttempts",
        "maxInactivity",
        "maxGracePeriod",
        "pinHistory",
        "maxPINAgeInDays",
    },
    "com.apple.dnsSettings.managed": {"DNSSettings"},
    "com.apple.vpn.managed": {
        "UserDefinedName",
        "VPNType",
        "VPNSubType",
        "VendorConfig",
        "VPN",
        "OnDemandEnabled",
        "OnDemandRules",
    },
    "com.apple.wifi.managed": {
        "SSID_STR",
        "EncryptionType",
        "AutoJoin",
        "MACAddressRandomization",
        "Password",
        "HIDDEN_NETWORK",
    },
    "com.apple.relay.managed": {"Enabled"},
    "com.apple.webcontent-filter": {"FilterType", "AutoFilterEnabled", "PermittedURLs", "BlacklistedURLs"},
    "com.apple.profileRemovalPassword": {"RemovalPassword"},
}


def validate_payload_type(payload_type: str) -> bool:
    return payload_type in ALLOWED_PAYLOAD_TYPES


def filter_fields(payload_type: str, fields: dict) -> dict:
    """Drop any keys not in the allowlist for this payload type."""
    allowed = ALLOWED_FIELDS.get(payload_type, set())
    return {k: v for k, v in (fields or {}).items() if k in allowed}
