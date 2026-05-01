"""Deterministic .mobileconfig builder. The LLM never writes XML."""
from __future__ import annotations

import plistlib
import subprocess
import tempfile
import uuid
from datetime import datetime, timezone
from pathlib import Path

from ..llm.schema import HardeningRecommendation, PayloadRecommendation
from .payloads import validate_payload_type, filter_fields

ORG = "Personal"
TOP_LEVEL_ID = "app.iphoneharden"

PAYLOAD_HUMAN_NAMES = {
    "com.apple.applicationaccess": "Restrictions",
    "com.apple.passcode": "Passcode Policy",
    "com.apple.dnsSettings.managed": "Encrypted DNS",
    "com.apple.vpn.managed": "VPN",
    "com.apple.wifi.managed": "Wi-Fi",
    "com.apple.relay.managed": "iCloud Private Relay",
    "com.apple.webcontent-filter": "Web Content Filter",
    "com.apple.profileRemovalPassword": "Profile Removal Password",
}


def build_profile(
    rec: HardeningRecommendation,
    udid: str,
    removal_password: str,
    display_name: str = "iPhone Hardening Profile",
    organization: str = ORG,
) -> bytes:
    """Build an unsigned .mobileconfig (XML plist) as bytes."""
    payload_content: list[dict] = []

    payload_content.append(
        {
            "PayloadType": "com.apple.profileRemovalPassword",
            "PayloadVersion": 1,
            "PayloadIdentifier": f"{TOP_LEVEL_ID}.removepw.{udid[:8]}",
            "PayloadUUID": str(uuid.uuid4()).upper(),
            "PayloadDisplayName": "Profile Removal Password",
            "RemovalPassword": removal_password,
        }
    )

    # Track per-type counters so multiple children of the same PayloadType
    # (e.g. several com.apple.applicationaccess payloads — baseline restrictions
    # + anonymous lockdown) get distinct PayloadIdentifier suffixes. Apple's
    # profile validator rejects duplicate identifiers within a profile.
    type_counters: dict[str, int] = {}
    for p in rec.payloads:
        if p.payload_type == "com.apple.profileRemovalPassword":
            continue  # we already inserted ours
        idx = type_counters.get(p.payload_type, 0)
        type_counters[p.payload_type] = idx + 1
        rendered = _render_payload(p, udid, index=idx)
        if rendered is not None:
            payload_content.append(rendered)

    timestamp = datetime.now(tz=timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")
    top = {
        "PayloadType": "Configuration",
        "PayloadVersion": 1,
        "PayloadIdentifier": f"{TOP_LEVEL_ID}.{udid[:8]}",
        "PayloadUUID": str(uuid.uuid4()).upper(),
        "PayloadDisplayName": display_name,
        "PayloadOrganization": organization,
        "PayloadDescription": (
            f"Generated {timestamp}. {len(payload_content)} payload(s). "
            f"Risk level: {rec.risk_level}."
        ),
        "PayloadRemovalDisallowed": False,
        "PayloadScope": "System",
        "ConsentText": {
            "default": (
                "By installing this profile you agree to apply privacy and "
                "security restrictions to this device. Removal requires the "
                "password generated and stored on your Mac."
            )
        },
        "PayloadContent": payload_content,
    }
    return plistlib.dumps(top, fmt=plistlib.FMT_XML)


def _render_payload(rec: PayloadRecommendation, udid: str, index: int = 0) -> dict | None:
    if not validate_payload_type(rec.payload_type):
        return None
    fields = filter_fields(rec.payload_type, rec.fields or {})
    short_type = rec.payload_type.split('.')[-1]
    suffix = f"{udid[:8]}.{index}" if index > 0 else udid[:8]
    payload = {
        "PayloadType": rec.payload_type,
        "PayloadVersion": 1,
        "PayloadIdentifier": f"{TOP_LEVEL_ID}.{short_type}.{suffix}",
        "PayloadUUID": str(uuid.uuid4()).upper(),
        "PayloadDisplayName": PAYLOAD_HUMAN_NAMES.get(rec.payload_type, rec.payload_type),
    }
    payload.update(fields)
    return payload


def sign_profile(unsigned: bytes, signer_cert: Path, signer_key: Path,
                 chain: Path | None = None) -> bytes:
    """CMS-sign with openssl smime. Returns DER-encoded signed profile."""
    with tempfile.TemporaryDirectory() as tmp:
        tmp_path = Path(tmp)
        in_path = tmp_path / "unsigned.mobileconfig"
        out_path = tmp_path / "signed.mobileconfig"
        in_path.write_bytes(unsigned)
        cmd = [
            "openssl", "smime", "-sign",
            "-signer", str(signer_cert),
            "-inkey", str(signer_key),
            "-nodetach", "-outform", "der",
            "-in", str(in_path), "-out", str(out_path),
        ]
        if chain is not None:
            cmd[3:3] = ["-certfile", str(chain)]
        subprocess.run(cmd, check=True)
        return out_path.read_bytes()
