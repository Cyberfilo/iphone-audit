from iphone_audit.audit import stalkerware


def test_known_bundle_match(stalkerware_app):
    findings = stalkerware.check([stalkerware_app])
    assert len(findings) == 1
    assert findings[0].severity.value == "critical"
    assert findings[0].evidence["product"] == "mSpy"


def test_benign_app_no_match(benign_app):
    assert stalkerware.check([benign_app]) == []


def test_mixed_apps(stalkerware_app, benign_app):
    findings = stalkerware.check([stalkerware_app, benign_app])
    assert len(findings) == 1
    assert "stalkerware.com.mspy.icloudbackup" in [f.id for f in findings]
