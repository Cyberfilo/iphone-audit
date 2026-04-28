"""Crash report retrieval via CrashReportsManager (com.apple.crashreportcopymobile)."""
from __future__ import annotations

from pathlib import Path


def pull_crashes(udid: str, dest: Path, erase: bool = False) -> Path:
    """Pull all crash reports to `dest`. Returns the destination path.

    `erase=True` clears the device-side store after pulling.
    """
    from pymobiledevice3.lockdown import create_using_usbmux
    from pymobiledevice3.services.crash_reports import CrashReportsManager

    dest.mkdir(parents=True, exist_ok=True)
    client = create_using_usbmux(serial=udid)
    mgr = CrashReportsManager(lockdown=client)
    mgr.pull(out=str(dest), entry="/", erase=erase, match=None, progress_bar=False)
    return dest


def list_crashes(udid: str, depth: int = 2) -> list[str]:
    """Return crash report file paths visible on device (no copy)."""
    from pymobiledevice3.lockdown import create_using_usbmux
    from pymobiledevice3.services.crash_reports import CrashReportsManager

    client = create_using_usbmux(serial=udid)
    mgr = CrashReportsManager(lockdown=client)
    return list(mgr.ls(path="/", depth=depth) or [])
