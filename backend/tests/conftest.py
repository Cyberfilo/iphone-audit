"""Shared fixtures for synthetic-input tests (no real device)."""
from __future__ import annotations

import pytest

from iphone_audit.audit.rules import AuditReport, Finding, Severity, Category
from iphone_audit.extraction.lockdown import LockdownSnapshot
from iphone_audit.extraction.profiles import InstalledProfile
from iphone_audit.extraction.apps import InstalledApp


@pytest.fixture
def empty_snap():
    return LockdownSnapshot(
        udid="0000-FAKE",
        identity={
            "ProductType": "iPhone13,3",
            "ProductVersion": "18.6.2",
            "BuildVersion": "22G91",
            "PasswordProtected": True,
            "PasscodeIsAlphanumeric": True,
            "IsSupervised": False,
        },
        domains={"com.apple.mobile.backup": {"WillEncrypt": True}},
    )


@pytest.fixture
def weak_snap():
    return LockdownSnapshot(
        udid="0000-WEAK",
        identity={
            "ProductType": "iPhone13,3",
            "ProductVersion": "18.6.2",
            "BuildVersion": "22G91",
            "PasswordProtected": False,
            "PasscodeIsAlphanumeric": False,
            "IsSupervised": False,
        },
        domains={"com.apple.mobile.backup": {"WillEncrypt": False}},
    )


@pytest.fixture
def stalkerware_app():
    return InstalledApp(
        bundle_id="com.mspy.icloudbackup",
        display_name="System Update",
        version="1.0",
        short_version="1.0",
        minimum_os_version="14.0",
        seller_name="Acme",
        is_user_installed=True,
    )


@pytest.fixture
def benign_app():
    return InstalledApp(
        bundle_id="com.example.benign",
        display_name="Benign",
        version="1.0",
        short_version="1.0",
        minimum_os_version="14.0",
        seller_name="Example Inc.",
        is_user_installed=True,
    )


@pytest.fixture
def synthetic_report(weak_snap, stalkerware_app):
    findings = [
        Finding(
            id="posture.no_passcode",
            severity=Severity.CRITICAL,
            category=Category.POSTURE,
            title="No passcode",
            description="",
            suggested_payloads=["com.apple.passcode"],
        ),
        Finding(
            id="posture.unencrypted_backup",
            severity=Severity.HIGH,
            category=Category.PRIVACY_LEAK,
            title="Backup encryption off",
            description="",
            suggested_payloads=["com.apple.applicationaccess"],
        ),
        Finding(
            id=f"stalkerware.{stalkerware_app.bundle_id}",
            severity=Severity.CRITICAL,
            category=Category.PRIOR_COMPROMISE,
            title="mSpy detected",
            description="",
            evidence={"bundle_id": stalkerware_app.bundle_id, "product": "mSpy"},
        ),
    ]
    return AuditReport(
        udid="0000-WEAK",
        device_model="iPhone13,3",
        ios_version="18.6.2",
        findings=findings,
    )
