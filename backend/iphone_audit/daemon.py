"""JSON-RPC server over Unix socket. Spawned by the Swift app at launch.

Wire format (newline-delimited):
    request:  {"jsonrpc":"2.0","id":<int>,"method":<str>,"params":<obj>}
    response: {"jsonrpc":"2.0","id":<int>,"result":<obj>}
              {"jsonrpc":"2.0","id":<int>,"error":{"code":<int>,"message":<str>}}

Methods implemented:
    list_devices, quick_audit, get_advice, build_profile, install_profile,
    verify, secret_show, secret_rotate, secret_delete,
    pairing_list, pairing_revoke, pairing_revoke_all, ping
"""
from __future__ import annotations

import asyncio
import json
import os
from pathlib import Path
from typing import Any

from .audit.rules import run_quick_audit
from .audit import pairing as audit_pairing
from .extraction import devices as ext_devices
from .hardening import builder as hb
from .hardening import install as hi
from .hardening import secret as hs
from .llm.advisor import get_advice as llm_get_advice, rule_based_fallback
from .llm.schema import HardeningRecommendation
from .report.diff import DiffReport
from .cli import _hydrate_report  # reuse hydration helper


DEFAULT_SOCKET_PATH = "/tmp/iphone-audit.sock"


def _default_profile_path(udid: str) -> Path:
    """Canonical .mobileconfig location, stable per device.

    The daemon is spawned by the .app and inherits its (likely root-`/`) CWD,
    so we must NOT use a relative path. Use the conventional macOS app data
    location instead.
    """
    base = Path.home() / "Library" / "Application Support" / "iSpow" / "profiles"
    return base / f"profile-{udid}.mobileconfig"


def _archive_profile_path(udid: str) -> Path:
    """User-visible archive location, timestamped so each build is kept.

    Lives under `~/Documents/iSpow-profiles/` for easy discovery in Finder.
    """
    from datetime import datetime
    base = Path.home() / "Documents" / "iSpow-profiles"
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    return base / f"profile-{udid}-{stamp}.mobileconfig"


def _write_profile_with_archive(udid: str, profile_bytes: bytes,
                                explicit_out: str | None) -> tuple[Path, Path]:
    """Write the profile to both the canonical and archive locations.

    Returns (canonical_path, archive_path). If `explicit_out` is given it
    overrides the canonical location; the archive copy is still written.
    """
    canonical = Path(explicit_out or _default_profile_path(udid)).resolve()
    canonical.parent.mkdir(parents=True, exist_ok=True)
    canonical.write_bytes(profile_bytes)

    archive = _archive_profile_path(udid).resolve()
    archive.parent.mkdir(parents=True, exist_ok=True)
    archive.write_bytes(profile_bytes)

    return canonical, archive


async def handle_request(method: str, params: dict) -> Any:
    if method == "ping":
        return {"pong": True}

    if method == "list_devices":
        return {"devices": [d.to_dict() for d in ext_devices.list_connected()]}

    if method == "quick_audit":
        report = await asyncio.to_thread(run_quick_audit, params["udid"])
        return {"report": report.to_dict()}

    if method == "get_advice":
        report = _hydrate_report(params["report"])
        use_llm = params.get("use_llm", True)
        rec = (
            await asyncio.to_thread(llm_get_advice, report)
            if use_llm
            else await asyncio.to_thread(rule_based_fallback, report)
        )
        return {"recommendation": rec.model_dump()}

    if method == "build_profile":
        rec = HardeningRecommendation.model_validate(params["recommendation"])
        udid = params["udid"]
        removal_password = hs.generate_secret()
        profile_bytes = hb.build_profile(rec, udid=udid, removal_password=removal_password)
        canonical, archive = _write_profile_with_archive(
            udid, profile_bytes, params.get("out")
        )
        hs.store_in_keychain(udid, removal_password)
        return {
            "profile_path": str(canonical),
            "archive_path": str(archive),
            "removal_password": removal_password,
            "size_bytes": len(profile_bytes),
        }

    if method == "build_and_install":
        # Convenience: build + push in one round-trip so the iPhone
        # immediately surfaces the install prompt in Settings.
        rec = HardeningRecommendation.model_validate(params["recommendation"])
        udid = params["udid"]
        removal_password = hs.generate_secret()
        profile_bytes = hb.build_profile(rec, udid=udid, removal_password=removal_password)
        canonical, archive = _write_profile_with_archive(
            udid, profile_bytes, params.get("out")
        )
        hs.store_in_keychain(udid, removal_password)
        installed = await asyncio.to_thread(hi.install_profile, udid, canonical)
        return {
            "profile_path": str(canonical),
            "archive_path": str(archive),
            "removal_password": removal_password,
            "size_bytes": len(profile_bytes),
            "queued": installed,
        }

    if method == "install_profile":
        ok = await asyncio.to_thread(hi.install_profile, params["udid"], Path(params["profile_path"]))
        return {"queued": ok}

    if method == "verify":
        before = _hydrate_report(params["before"])
        after = await asyncio.to_thread(run_quick_audit, params["udid"])
        diff = DiffReport.compute(before, after)
        return {"diff": diff.to_dict()}

    if method == "secret_show":
        return {"secret": hs.retrieve_from_keychain(params["udid"])}

    if method == "secret_rotate":
        s = hs.generate_secret()
        hs.store_in_keychain(params["udid"], s)
        return {"secret": s}

    if method == "secret_delete":
        return {"deleted": hs.delete_from_keychain(params["udid"])}

    if method == "pairing_list":
        return {"records": audit_pairing.list_pairing_records()}

    if method == "pairing_revoke":
        return {"revoked": audit_pairing.revoke_pairing(params["udid"])}

    if method == "pairing_revoke_all":
        return {"deleted": audit_pairing.revoke_all()}

    raise ValueError(f"unknown_method: {method}")


async def _handle_client(reader: asyncio.StreamReader, writer: asyncio.StreamWriter) -> None:
    while not reader.at_eof():
        line = await reader.readline()
        if not line:
            break
        request_id = None
        try:
            req = json.loads(line)
            request_id = req.get("id")
            method = req["method"]
            params = req.get("params") or {}
            result = await handle_request(method, params)
            response = {"jsonrpc": "2.0", "id": request_id, "result": result}
        except Exception as exc:
            response = {
                "jsonrpc": "2.0",
                "id": request_id,
                "error": {"code": -32000, "message": str(exc)},
            }
        writer.write((json.dumps(response, default=str) + "\n").encode("utf-8"))
        try:
            await writer.drain()
        except (ConnectionResetError, BrokenPipeError):
            break
    writer.close()
    try:
        await writer.wait_closed()
    except Exception:
        pass


async def serve(socket_path: str = DEFAULT_SOCKET_PATH) -> None:
    if os.path.exists(socket_path):
        os.unlink(socket_path)
    server = await asyncio.start_unix_server(_handle_client, path=socket_path)
    os.chmod(socket_path, 0o600)
    async with server:
        await server.serve_forever()


if __name__ == "__main__":
    asyncio.run(serve())
