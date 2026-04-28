"""Encrypted backup orchestration via Mobilebackup2Service.

Most flows here only flip device-side encryption — actually running a backup is
a slow optional operation exposed through the CLI separately.
"""
from __future__ import annotations

from pathlib import Path


def get_will_encrypt(udid: str) -> bool | None:
    """True if device-side backup encryption is enabled. None if unknown."""
    from pymobiledevice3.lockdown import create_using_usbmux
    from pymobiledevice3.services.mobilebackup2 import Mobilebackup2Service

    try:
        client = create_using_usbmux(serial=udid)
        svc = Mobilebackup2Service(lockdown=client)
        return bool(svc.will_encrypt) if hasattr(svc, "will_encrypt") else None
    except Exception:
        return None


def enable_encryption(udid: str, new_password: str, backup_dir: Path) -> None:
    """Enable device-side backup encryption with `new_password`.

    Requires the directory to be a valid backup target (Mobilebackup2 protocol
    initiates a session even for a password change).
    """
    from pymobiledevice3.lockdown import create_using_usbmux
    from pymobiledevice3.services.mobilebackup2 import Mobilebackup2Service

    backup_dir.mkdir(parents=True, exist_ok=True)
    client = create_using_usbmux(serial=udid)
    svc = Mobilebackup2Service(lockdown=client)
    svc.change_password(backup_directory=str(backup_dir), old="", new=new_password)


def disable_encryption(udid: str, current_password: str, backup_dir: Path) -> None:
    """Disable device-side backup encryption (requires current password)."""
    from pymobiledevice3.lockdown import create_using_usbmux
    from pymobiledevice3.services.mobilebackup2 import Mobilebackup2Service

    backup_dir.mkdir(parents=True, exist_ok=True)
    client = create_using_usbmux(serial=udid)
    svc = Mobilebackup2Service(lockdown=client)
    svc.change_password(backup_directory=str(backup_dir), old=current_password, new="")


def run_backup(udid: str, backup_dir: Path, full: bool = True) -> Path:
    """Run a full or differential backup to `backup_dir`. Slow."""
    from pymobiledevice3.lockdown import create_using_usbmux
    from pymobiledevice3.services.mobilebackup2 import Mobilebackup2Service

    backup_dir.mkdir(parents=True, exist_ok=True)
    client = create_using_usbmux(serial=udid)
    svc = Mobilebackup2Service(lockdown=client)
    svc.backup(full=full, backup_directory=str(backup_dir))
    return backup_dir
