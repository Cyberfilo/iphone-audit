"""Removal-password generation + macOS Keychain bridge."""
from __future__ import annotations

import base64
import secrets
import subprocess


def _service(udid: str, prefix: str = "iPhoneHarden") -> str:
    return f"{prefix}-{udid}"


def generate_secret(byte_length: int = 24) -> str:
    """`openssl rand -base64 24` equivalent. 24 bytes → 32 chars, 192 bits."""
    return base64.b64encode(secrets.token_bytes(byte_length)).decode("ascii")


def store_in_keychain(udid: str, secret: str, app_path: str | None = None,
                      prefix: str = "iPhoneHarden") -> None:
    """Add (or update) a generic password keyed by `iPhoneHarden-<UDID>`.

    `app_path` (optional): whitelist a signed app for non-prompted reads.
    """
    cmd = [
        "security", "add-generic-password",
        "-a", _whoami(),
        "-s", _service(udid, prefix),
        "-w", secret,
        "-U",
    ]
    if app_path:
        cmd += ["-T", app_path]
    subprocess.run(cmd, check=True)


def retrieve_from_keychain(udid: str, prefix: str = "iPhoneHarden") -> str | None:
    """Return the stored secret, or None if not present."""
    try:
        out = subprocess.check_output(
            ["security", "find-generic-password", "-s", _service(udid, prefix), "-w"],
            stderr=subprocess.DEVNULL,
        )
    except subprocess.CalledProcessError:
        return None
    return out.decode().strip() or None


def delete_from_keychain(udid: str, prefix: str = "iPhoneHarden") -> bool:
    """Delete the secret. Returns True if something was deleted."""
    result = subprocess.run(
        ["security", "delete-generic-password", "-s", _service(udid, prefix)],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return result.returncode == 0


def _whoami() -> str:
    return subprocess.check_output(["whoami"]).decode().strip()
