from iphone_audit.audit import entitlements
from iphone_audit.extraction.apps import InstalledApp


def _app(**kw):
    base = dict(
        bundle_id="com.example.x", display_name="X",
        version="1.0", short_version="1.0",
        minimum_os_version="14.0", seller_name=None,
        is_user_installed=True,
    )
    base.update(kw)
    return InstalledApp(**base)


def test_private_entitlement_is_high():
    app = _app(entitlements=["com.apple.private.networkextension"])
    findings = entitlements.check([app])
    assert len(findings) == 1
    assert findings[0].severity.value == "high"
    assert findings[0].id.startswith("entitlement.private.")


def test_notable_entitlement_is_low():
    app = _app(entitlements=["com.apple.developer.networking.networkextension"])
    findings = entitlements.check([app])
    assert len(findings) == 1
    assert findings[0].severity.value == "low"
    assert findings[0].id.startswith("entitlement.notable.")


def test_routine_entitlements_no_finding():
    """Common entitlements that should NOT fire (the v1.000 false-positive set)."""
    app = _app(entitlements=[
        "com.apple.security.application-groups",
        "com.apple.developer.icloud-services",
        "com.apple.developer.healthkit",
        "com.apple.developer.contacts",
        "com.apple.developer.usernotifications.filtering",
    ])
    assert entitlements.check([app]) == []


def test_no_entitlements_no_finding():
    assert entitlements.check([_app()]) == []
