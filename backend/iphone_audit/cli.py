"""click-driven CLI surface."""
from __future__ import annotations

import json
import sys
from pathlib import Path

import click

from . import __version__
from .audit.rules import run_quick_audit, AuditReport
from .audit import pairing as audit_pairing
from .extraction import devices as ext_devices
from .extraction import backup as ext_backup
from .hardening import builder as hb
from .hardening import install as hi
from .hardening import secret as hs
from .llm.advisor import get_advice, rule_based_fallback
from .llm.schema import HardeningRecommendation
from .report.diff import DiffReport
from .report import render


@click.group()
@click.version_option(__version__, prog_name="iphone-audit")
def cli() -> None:
    """iPhone audit and hardening tool."""


# ─── Devices ────────────────────────────────────────────────────────────────
@cli.command("list")
def list_devices() -> None:
    """List currently connected iPhones via usbmuxd."""
    devs = ext_devices.list_connected()
    if not devs:
        click.echo("No devices connected.")
        return
    for d in devs:
        click.echo(f"{d.udid}\t{d.connection_type}")


# ─── Audit modes ────────────────────────────────────────────────────────────
@cli.command("quick-scan")
@click.option("--udid", required=True)
@click.option("--output", "out_path", type=click.Path(path_type=Path), default=None,
              help="Write JSON report to this path; else stdout.")
@click.option("--html", "html_path", type=click.Path(path_type=Path), default=None,
              help="Also render HTML to this path.")
def quick_scan(udid: str, out_path: Path | None, html_path: Path | None) -> None:
    """Run a quick lockdownd-only audit (no backup)."""
    report = run_quick_audit(udid)
    payload = render.render_report_json(report)
    if out_path:
        out_path.write_text(payload)
        click.echo(f"Wrote {out_path}")
    else:
        click.echo(payload)
    if html_path:
        html_path.write_text(render.render_report_html(report))
        click.echo(f"Wrote {html_path}", err=True)


# ─── Advisor ────────────────────────────────────────────────────────────────
@cli.command("advise")
@click.option("--findings", "findings_path", type=click.Path(path_type=Path, exists=True), required=True)
@click.option("--no-llm", is_flag=True, default=False, help="Force rule-based fallback.")
@click.option("--output", "out_path", type=click.Path(path_type=Path), default=None)
def advise(findings_path: Path, no_llm: bool, out_path: Path | None) -> None:
    """Turn an audit-report JSON into a HardeningRecommendation."""
    raw = json.loads(findings_path.read_text())
    report = _hydrate_report(raw)
    rec = rule_based_fallback(report) if no_llm else get_advice(report)
    payload = rec.model_dump_json(indent=2)
    if out_path:
        out_path.write_text(payload)
        click.echo(f"Wrote {out_path}")
    else:
        click.echo(payload)


# ─── Build / install / verify ───────────────────────────────────────────────
@cli.command("harden")
@click.option("--udid", required=True)
@click.option("--recommendation", "rec_path", type=click.Path(path_type=Path, exists=True), required=True)
@click.option("--sign", is_flag=True, default=False, help="CMS-sign with self-signed cert.")
@click.option("--cert", type=click.Path(path_type=Path), default=None)
@click.option("--key", "key_path", type=click.Path(path_type=Path), default=None)
@click.option("--out", "out_path", type=click.Path(path_type=Path), default=None,
              help="Write the .mobileconfig here. Default: ./profile-<UDID>.mobileconfig")
@click.option("--install/--no-install", default=True, help="Push to device after build.")
@click.option("--enable-backup-encryption", is_flag=True, default=False,
              help="Also flip device-side backup encryption with a generated password.")
def harden(udid: str, rec_path: Path, sign: bool, cert: Path | None,
           key_path: Path | None, out_path: Path | None, install: bool,
           enable_backup_encryption: bool) -> None:
    """Build (and optionally install) a .mobileconfig from a recommendation."""
    rec = HardeningRecommendation.model_validate_json(rec_path.read_text())
    removal_password = hs.generate_secret()
    profile_bytes = hb.build_profile(rec, udid=udid, removal_password=removal_password)
    if sign:
        if not (cert and key_path):
            raise click.UsageError("--sign requires --cert and --key")
        profile_bytes = hb.sign_profile(profile_bytes, cert, key_path)
    target = out_path or Path(f"profile-{udid}.mobileconfig")
    target.write_bytes(profile_bytes)
    hs.store_in_keychain(udid, removal_password)
    click.echo(f"Wrote {target}")
    click.echo(f"Removal password stored in Keychain as iPhoneHarden-{udid}")
    if install:
        ok = hi.install_profile(udid, target)
        click.echo(f"Queued install: {ok}. Tap 'Install' on the device to apply.")
    if enable_backup_encryption:
        bp = hs.generate_secret()
        ext_backup.enable_encryption(udid, bp, Path(f"backup-{udid}"))
        hs.store_in_keychain(udid, bp, prefix="iPhoneHardenBackup")
        click.echo("Backup encryption enabled. Password stored as iPhoneHardenBackup-<UDID>.")


@cli.command("verify")
@click.option("--udid", required=True)
@click.option("--before", "before_path", type=click.Path(path_type=Path, exists=True), required=True,
              help="Path to the pre-hardening audit JSON.")
@click.option("--output", "out_path", type=click.Path(path_type=Path), default=None)
def verify(udid: str, before_path: Path, out_path: Path | None) -> None:
    """Re-run audit and emit before/after diff against an earlier report."""
    before = _hydrate_report(json.loads(before_path.read_text()))
    after = run_quick_audit(udid)
    diff = DiffReport.compute(before, after)
    payload = render.render_diff_json(diff)
    if out_path:
        out_path.write_text(payload)
        click.echo(f"Wrote {out_path}")
    else:
        click.echo(payload)


# ─── Secret management ─────────────────────────────────────────────────────
@cli.group("secret")
def secret_group() -> None:
    """Manage Keychain-stored removal passwords."""


@secret_group.command("show")
@click.option("--udid", required=True)
def secret_show(udid: str) -> None:
    val = hs.retrieve_from_keychain(udid)
    if val is None:
        click.echo("(no secret stored)")
        sys.exit(1)
    click.echo(val)


@secret_group.command("rotate")
@click.option("--udid", required=True)
def secret_rotate(udid: str) -> None:
    new_secret = hs.generate_secret()
    hs.store_in_keychain(udid, new_secret)
    click.echo(new_secret)


@secret_group.command("delete")
@click.option("--udid", required=True)
def secret_delete(udid: str) -> None:
    ok = hs.delete_from_keychain(udid)
    click.echo("deleted" if ok else "(nothing to delete)")


# ─── Pairing record management ─────────────────────────────────────────────
@cli.group("pairing")
def pairing_group() -> None:
    """Audit and revoke Mac-side pairing records."""


@pairing_group.command("list")
def pairing_list() -> None:
    records = audit_pairing.list_pairing_records()
    if not records:
        click.echo("No pairing records readable (try sudo).")
        return
    click.echo(json.dumps(records, indent=2))


@pairing_group.command("revoke")
@click.option("--udid", required=True)
def pairing_revoke(udid: str) -> None:
    ok = audit_pairing.revoke_pairing(udid)
    click.echo("revoked" if ok else "(not found or no permission)")


@pairing_group.command("revoke-all")
@click.confirmation_option(prompt="Delete ALL Mac-side pairing records?")
def pairing_revoke_all() -> None:
    n = audit_pairing.revoke_all()
    click.echo(f"deleted {n} record(s)")


# ─── Crash reports ─────────────────────────────────────────────────────────
@cli.command("crashes")
@click.option("--udid", required=True)
@click.option("--out", "out_path", type=click.Path(path_type=Path), required=True)
@click.option("--erase", is_flag=True, default=False)
def pull_crashes_cmd(udid: str, out_path: Path, erase: bool) -> None:
    """Pull crash reports off the device into <out>."""
    from .extraction.crashes import pull_crashes
    pull_crashes(udid, out_path, erase=erase)
    click.echo(f"Wrote crash reports to {out_path}")


# ─── Daemon ────────────────────────────────────────────────────────────────
@cli.command("daemon")
@click.option("--socket", "socket_path", default="/tmp/iphone-audit.sock", show_default=True)
def daemon_cmd(socket_path: str) -> None:
    """Run the JSON-RPC daemon for the Swift app."""
    import asyncio
    from .daemon import serve
    asyncio.run(serve(socket_path))


# ─── Self-signed cert init ─────────────────────────────────────────────────
@cli.command("init-signing-cert")
@click.option("--out-dir", type=click.Path(path_type=Path),
              default=lambda: Path.home() / ".config" / "iphone-audit" / "signing",
              show_default=True)
def init_signing_cert(out_dir: Path) -> None:
    """Generate a self-signed CA + signing cert for profile signing."""
    import subprocess
    out_dir.mkdir(parents=True, exist_ok=True)
    cert = out_dir / "signer.pem"
    key = out_dir / "signer.key"
    if cert.exists() and key.exists():
        click.echo(f"Already exist at {out_dir}")
        return
    subprocess.run([
        "openssl", "req", "-x509", "-newkey", "rsa:2048", "-sha256",
        "-days", "3650", "-nodes",
        "-keyout", str(key),
        "-out", str(cert),
        "-subj", "/CN=iPhoneHarden Self-Signed/O=Personal",
    ], check=True)
    click.echo(f"Wrote {cert} and {key}")


# ─── Helpers ───────────────────────────────────────────────────────────────
def _hydrate_report(raw: dict) -> AuditReport:
    """Rehydrate AuditReport from the JSON we render in render.py.

    Keeps Finding objects faithful so the advisor sees exact severity/category
    enums.
    """
    from .audit.rules import Finding, Severity, Category

    findings = []
    for f in raw.get("findings", []):
        findings.append(
            Finding(
                id=f["id"],
                severity=Severity(f["severity"]),
                category=Category(f["category"]),
                title=f.get("title", ""),
                description=f.get("description", ""),
                evidence=f.get("evidence", {}),
                suggested_payloads=list(f.get("suggested_payloads", [])),
            )
        )
    return AuditReport(
        udid=raw.get("udid", ""),
        device_model=raw.get("device_model", "unknown"),
        ios_version=raw.get("ios_version", "unknown"),
        findings=findings,
        raw_extraction=raw.get("raw_extraction", {}),
    )


if __name__ == "__main__":
    cli()
