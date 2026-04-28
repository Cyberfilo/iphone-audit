"""Configuration profile inventory via MobileConfigService."""
from __future__ import annotations

from dataclasses import dataclass, field, asdict


@dataclass
class InstalledProfile:
    payload_identifier: str
    payload_uuid: str
    display_name: str
    organization: str | None = None
    description: str | None = None
    is_signed: bool = False
    payloads: list[dict] = field(default_factory=list)
    has_mdm_payload: bool = False
    has_vpn_payload: bool = False
    has_dns_payload: bool = False
    has_root_ca: bool = False

    def to_dict(self) -> dict:
        return asdict(self)


def list_profiles(udid: str) -> list[InstalledProfile]:
    """Return installed configuration profiles. Empty list on error or none."""
    from pymobiledevice3.lockdown import create_using_usbmux
    from pymobiledevice3.services.mobile_config import MobileConfigService

    client = create_using_usbmux(serial=udid)
    svc = MobileConfigService(lockdown=client)
    raw = svc.get_profile_list() or {}

    out: list[InstalledProfile] = []
    ordered = raw.get("OrderedIdentifiers") or []
    manifest = raw.get("ProfileManifest") or {}
    metadata = raw.get("ProfileMetadata") or {}

    for ident in ordered:
        man = manifest.get(ident, {}) or {}
        meta = metadata.get(ident, {}) or {}
        prof = InstalledProfile(
            payload_identifier=ident,
            payload_uuid=meta.get("PayloadUUID", ""),
            display_name=meta.get("PayloadDisplayName", ident),
            organization=meta.get("PayloadOrganization"),
            description=meta.get("PayloadDescription"),
            is_signed=bool(man.get("IsActive", False)),
        )
        for child in (meta.get("PayloadContent") or []):
            ptype = child.get("PayloadType", "")
            prof.payloads.append({"type": ptype, "uuid": child.get("PayloadUUID")})
            if ptype == "com.apple.mdm":
                prof.has_mdm_payload = True
            elif ptype.startswith("com.apple.vpn"):
                prof.has_vpn_payload = True
            elif ptype == "com.apple.dnsSettings.managed":
                prof.has_dns_payload = True
            elif ptype in ("com.apple.security.root", "com.apple.security.pkcs1"):
                prof.has_root_ca = True
        out.append(prof)
    return out
