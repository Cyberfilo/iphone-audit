"""Lockdownd extraction — identity, per-domain values, posture inputs."""
from __future__ import annotations

from dataclasses import dataclass, field, asdict
from typing import Any

LOCKDOWN_DOMAINS = [
    "com.apple.disk_usage",
    "com.apple.mobile.battery",
    "com.apple.mobile.chaperone",
    "com.apple.international",
    "com.apple.mobile.data_sync",
    "com.apple.mobile.tethered_sync",
    "com.apple.mobile.backup",
    "com.apple.mobile.restriction",
    "com.apple.mobile.user_preferences",
    "com.apple.mobile.software_behavior",
    "com.apple.mobile.wireless_lockdown",
    "com.apple.fairplay",
]

IDENTITY_KEYS = [
    "UniqueDeviceID", "SerialNumber", "ProductType", "ProductVersion",
    "BuildVersion", "BasebandVersion", "HardwareModel", "DeviceClass",
    "DeviceColor", "RegionInfo", "ChipID", "BoardId",
    "InternationalMobileEquipmentIdentity", "MeidEquipmentIdentifier",
    "IntegratedCircuitCardIdentity", "EUICCChipID", "UniqueChipID",
    "WiFiAddress", "BluetoothAddress", "EthernetAddress",
    "ActivationState", "PasswordProtected", "PasscodeIsAlphanumeric",
    "IsSupervised", "CPUArchitecture",
]


@dataclass
class LockdownSnapshot:
    udid: str
    identity: dict[str, Any] = field(default_factory=dict)
    domains: dict[str, dict] = field(default_factory=dict)
    error: str | None = None

    def to_dict(self) -> dict:
        return asdict(self)


def snapshot(udid: str) -> LockdownSnapshot:
    """Take a full lockdownd identity + domain snapshot.

    Sync — pymobiledevice3 4.x is synchronous.
    """
    from pymobiledevice3.lockdown import create_using_usbmux
    from pymobiledevice3.exceptions import NoDeviceConnectedError

    snap = LockdownSnapshot(udid=udid)
    try:
        client = create_using_usbmux(serial=udid)
    except NoDeviceConnectedError:
        snap.error = "no_device"
        return snap
    except Exception as exc:
        snap.error = f"connect_failed: {exc}"
        return snap

    for key in IDENTITY_KEYS:
        try:
            value = client.get_value(key=key)
            if value is not None:
                snap.identity[key] = value
        except Exception:
            continue

    for domain in LOCKDOWN_DOMAINS:
        try:
            value = client.get_value(domain=domain)
            snap.domains[domain] = value if isinstance(value, dict) else {"_raw": value}
        except Exception as exc:
            snap.domains[domain] = {"_error": str(exc)}

    return snap
