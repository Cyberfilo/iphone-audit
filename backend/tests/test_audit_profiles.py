from iphone_audit.audit import profiles as audit_profiles
from iphone_audit.extraction.profiles import InstalledProfile


def _profile(**kwargs):
    base = dict(
        payload_identifier="com.example.profile",
        payload_uuid="UUID",
        display_name="Example",
        organization="Example",
    )
    base.update(kwargs)
    return InstalledProfile(**base)


def test_root_ca_is_high():
    findings = audit_profiles.check([_profile(has_root_ca=True)])
    assert any(f.id.startswith("profile.root_ca") for f in findings)
    assert findings[0].severity.value == "high"


def test_mdm_is_high():
    findings = audit_profiles.check([_profile(has_mdm_payload=True)])
    assert any(f.id.startswith("profile.mdm") for f in findings)


def test_vpn_is_medium():
    findings = audit_profiles.check([_profile(has_vpn_payload=True)])
    f = next(f for f in findings if f.id.startswith("profile.vpn"))
    assert f.severity.value == "medium"


def test_clean_profile_no_findings():
    assert audit_profiles.check([_profile()]) == []
