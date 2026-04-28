"""Device enumeration via usbmuxd."""
from __future__ import annotations

from dataclasses import dataclass, asdict


@dataclass
class DeviceInfo:
    udid: str
    connection_type: str
    is_usb: bool
    is_network: bool

    def to_dict(self) -> dict:
        return asdict(self)


def list_connected() -> list[DeviceInfo]:
    """Return all currently visible devices via usbmuxd."""
    from pymobiledevice3.usbmux import list_devices

    out: list[DeviceInfo] = []
    for d in list_devices():
        out.append(
            DeviceInfo(
                udid=d.serial,
                connection_type=d.connection_type,
                is_usb=getattr(d, "is_usb", d.connection_type == "USB"),
                is_network=getattr(d, "is_network", d.connection_type == "Network"),
            )
        )
    return out
