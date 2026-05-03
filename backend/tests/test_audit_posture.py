from iphone_audit.audit import posture
from iphone_audit.extraction.lockdown import LockdownSnapshot


def test_passcode_unknown_when_key_missing():
    """iOS 17+ restricts PasswordProtected — when missing we must NOT fire CRIT."""
    snap = LockdownSnapshot(
        udid="x",
        identity={
            "ProductType": "iPhone16,1",
            "ProductVersion": "18.4.1",
            "BuildVersion": "22A123",
            # NB: no PasswordProtected, no PasscodeIsAlphanumeric
        },
        domains={"com.apple.mobile.backup": {"WillEncrypt": True}},
    )
    findings = posture.check(snap)
    ids = [f.id for f in findings]
    assert "posture.no_passcode" not in ids
    assert "posture.weak_passcode" not in ids
    assert "posture.passcode_unknown" in ids
    unknown = next(f for f in findings if f.id == "posture.passcode_unknown")
    assert unknown.severity.value == "info"


def test_no_passcode_emits_critical(weak_snap):
    findings = posture.check(weak_snap)
    ids = [f.id for f in findings]
    assert "posture.no_passcode" in ids
    no_pass = next(f for f in findings if f.id == "posture.no_passcode")
    assert no_pass.severity.value == "critical"


def test_unencrypted_backup_high(weak_snap):
    findings = posture.check(weak_snap)
    ids = [f.id for f in findings]
    assert "posture.unencrypted_backup" in ids
    un = next(f for f in findings if f.id == "posture.unencrypted_backup")
    assert un.severity.value == "high"


def test_clean_snap_no_critical(empty_snap):
    findings = posture.check(empty_snap)
    crits = [f for f in findings if f.severity.value == "critical"]
    assert crits == []


def test_supervision_status_emitted(weak_snap, empty_snap):
    weak_ids = {f.id for f in posture.check(weak_snap)}
    empty_ids = {f.id for f in posture.check(empty_snap)}
    assert "posture.unsupervised" in weak_ids
    assert "posture.unsupervised" in empty_ids


def test_no_apple_id_detection_emits_recommendation():
    snap = LockdownSnapshot(
        udid="x",
        identity={"ProductType": "iPhone16,1", "ProductVersion": "18.4.1"},
        domains={
            "com.apple.mobile.backup": {"WillEncrypt": True},
            "com.apple.mobile.data_sync": {},  # empty → no Apple ID
        },
    )
    findings = posture.check(snap)
    ids = {f.id for f in findings}
    assert "posture.no_apple_id" in ids
    assert "posture.apple_id_unknown" not in ids


def test_apple_id_unknown_when_domain_unreadable():
    snap = LockdownSnapshot(
        udid="x",
        identity={"ProductType": "iPhone16,1", "ProductVersion": "18.4.1"},
        domains={
            "com.apple.mobile.backup": {"WillEncrypt": True},
            "com.apple.mobile.data_sync": {"_error": "denied"},
        },
    )
    ids = {f.id for f in posture.check(snap)}
    assert "posture.apple_id_unknown" in ids
    assert "posture.no_apple_id" not in ids


def test_apple_id_present_no_finding():
    snap = LockdownSnapshot(
        udid="x",
        identity={"ProductType": "iPhone16,1", "ProductVersion": "18.4.1"},
        domains={
            "com.apple.mobile.backup": {"WillEncrypt": True},
            "com.apple.mobile.data_sync": {"Accounts": ["icloud"]},
        },
    )
    ids = {f.id for f in posture.check(snap)}
    assert "posture.no_apple_id" not in ids
    assert "posture.apple_id_unknown" not in ids


def test_anonymous_lockdown_payload_in_advisor_when_no_apple_id():
    """When `posture.no_apple_id` is present, the rule-based fallback should
    add a second com.apple.applicationaccess payload with the privacy lockdown
    fields."""
    from iphone_audit.audit.rules import AuditReport, Finding, Severity, Category
    from iphone_audit.llm.advisor import rule_based_fallback, ANONYMOUS_LOCKDOWN_FIELDS

    report = AuditReport(
        udid="x", device_model="iPhone16,1", ios_version="18.4.1",
        findings=[
            Finding(id="posture.no_apple_id", severity=Severity.INFO,
                    category=Category.INFORMATIONAL,
                    title="t", description="d"),
        ],
    )
    rec = rule_based_fallback(report)
    types = [p.payload_type for p in rec.payloads]
    # baseline restrictions + anonymous lockdown
    assert types.count("com.apple.applicationaccess") >= 2
    anon = next(p for p in rec.payloads
                if "posture.no_apple_id" in p.addresses_finding_ids)
    for k, v in ANONYMOUS_LOCKDOWN_FIELDS.items():
        assert anon.fields.get(k) == v
