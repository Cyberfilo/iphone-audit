"""Installed application inventory + entitlement extraction."""
from __future__ import annotations

from dataclasses import dataclass, field, asdict

# Truly suspicious entitlements — these are private (Apple-internal) flags
# that legitimate App Store apps should NEVER hold. The earlier broader list
# included routine entitlements like `application-groups`, `icloud-services`,
# `contacts`, `healthkit` which every messenger / fitness / iCloud-enabled
# app holds — too noisy to be useful.
#
# Two separate lists:
#   PRIVATE — almost certainly suspicious (jailbreak / spyware territory).
#   NOTABLE — worth surfacing for the user's awareness, NOT a red flag alone.

PRIVATE_ENTITLEMENTS = [
    "com.apple.private.networkextension",
    "com.apple.private.security.no-container",
    "com.apple.private.MobileGestalt.allowedKeys",
    "com.apple.private.tcc.allow",
    "com.apple.private.security.system-application",
    "platform-application",
]

NOTABLE_ENTITLEMENTS = [
    "com.apple.developer.networking.networkextension",
    "com.apple.developer.networking.vpn.api",
]

# Backwards-compat for any old import sites.
RISKY_ENTITLEMENTS = PRIVATE_ENTITLEMENTS + NOTABLE_ENTITLEMENTS


@dataclass
class InstalledApp:
    bundle_id: str
    display_name: str
    version: str
    short_version: str
    minimum_os_version: str
    seller_name: str | None
    is_user_installed: bool
    entitlements: list[str] = field(default_factory=list)
    risky_entitlements: list[str] = field(default_factory=list)

    def to_dict(self) -> dict:
        return asdict(self)


def list_apps(udid: str, application_type: str = "User") -> list[InstalledApp]:
    """Return installed apps with metadata + entitlements.

    application_type: "User" (sideloaded/App Store), "System", "Internal", or "Any".
    """
    from pymobiledevice3.lockdown import create_using_usbmux
    from pymobiledevice3.services.installation_proxy import InstallationProxyService

    client = create_using_usbmux(serial=udid)
    svc = InstallationProxyService(lockdown=client)
    raw = svc.get_apps(application_type=application_type, calculate_sizes=False) or {}

    out: list[InstalledApp] = []
    for bundle_id, info in raw.items():
        if not isinstance(info, dict):
            continue
        ents = list((info.get("Entitlements") or {}).keys())
        risky = [e for e in ents if e in RISKY_ENTITLEMENTS]
        out.append(
            InstalledApp(
                bundle_id=bundle_id,
                display_name=info.get("CFBundleDisplayName") or info.get("CFBundleName") or bundle_id,
                version=info.get("CFBundleVersion", ""),
                short_version=info.get("CFBundleShortVersionString", ""),
                minimum_os_version=info.get("MinimumOSVersion", ""),
                seller_name=info.get("SellerName"),
                is_user_installed=info.get("ApplicationType") == "User",
                entitlements=ents,
                risky_entitlements=risky,
            )
        )
    return out
