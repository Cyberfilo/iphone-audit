"""Install .mobileconfig to a connected device."""
from __future__ import annotations

import subprocess
from pathlib import Path


def install_profile(udid: str, profile_path: Path) -> bool:
    """Install via pymobiledevice3 MobileConfigService.

    On consumer (non-supervised) devices the user must tap-through in Settings;
    this call queues the profile for installation. Returns True on queue success.
    """
    from pymobiledevice3.lockdown import create_using_usbmux
    from pymobiledevice3.services.mobile_config import MobileConfigService

    client = create_using_usbmux(serial=udid)
    svc = MobileConfigService(lockdown=client)
    svc.install_profile(profile_path.read_bytes())
    return True


def install_via_cfgutil(udid: str, profile_path: Path) -> bool:
    """Alternative path: Apple Configurator 2's `cfgutil`. Returns False if absent."""
    cfgutil = Path("/Applications/Apple Configurator 2.app/Contents/MacOS/cfgutil")
    if not cfgutil.exists():
        return False
    subprocess.run(
        [str(cfgutil), "--ecid-or-udid", udid, "install-profile", str(profile_path)],
        check=True,
    )
    return True


def remove_profile(udid: str, payload_identifier: str) -> bool:
    """Remove an installed profile by identifier."""
    from pymobiledevice3.lockdown import create_using_usbmux
    from pymobiledevice3.services.mobile_config import MobileConfigService

    client = create_using_usbmux(serial=udid)
    svc = MobileConfigService(lockdown=client)
    svc.remove_profile(payload_identifier)
    return True
