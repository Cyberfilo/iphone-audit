import plistlib

from iphone_audit.hardening.builder import build_profile
from iphone_audit.llm.advisor import rule_based_fallback
from iphone_audit.hardening.payloads import filter_fields


def test_build_profile_well_formed(synthetic_report):
    rec = rule_based_fallback(synthetic_report)
    profile_bytes = build_profile(rec, udid="0000-WEAK", removal_password="hunter2")
    parsed = plistlib.loads(profile_bytes)

    assert parsed["PayloadType"] == "Configuration"
    assert parsed["PayloadVersion"] == 1
    assert parsed["PayloadIdentifier"].startswith("app.iphoneharden.")
    assert parsed["PayloadScope"] == "System"
    assert parsed["PayloadRemovalDisallowed"] is False
    assert parsed["PayloadContent"], "expected payload content"


def test_removal_password_payload_first(synthetic_report):
    rec = rule_based_fallback(synthetic_report)
    profile_bytes = build_profile(rec, udid="0000-WEAK", removal_password="abc123")
    parsed = plistlib.loads(profile_bytes)
    first = parsed["PayloadContent"][0]
    assert first["PayloadType"] == "com.apple.profileRemovalPassword"
    assert first["RemovalPassword"] == "abc123"


def test_payload_field_filtering_drops_unknowns():
    fields = {
        "allowAirDrop": False,
        "totallyMadeUpKey": "x",
    }
    out = filter_fields("com.apple.applicationaccess", fields)
    assert "allowAirDrop" in out
    assert "totallyMadeUpKey" not in out


def test_payload_identifiers_unique_with_repeated_payload_types():
    """Regression: iOS rejects profiles where two payloads share PayloadIdentifier.
    With the anonymous-lockdown feature we now emit multiple
    `com.apple.applicationaccess` children — they must all have distinct ids."""
    from iphone_audit.llm.schema import HardeningRecommendation, PayloadRecommendation
    rec = HardeningRecommendation(
        summary="multiple",
        risk_level="medium",
        payloads=[
            PayloadRecommendation(payload_type="com.apple.applicationaccess",
                                  rationale="r1", fields={"allowAirDrop": False}),
            PayloadRecommendation(payload_type="com.apple.applicationaccess",
                                  rationale="r2", fields={"forceLimitAdTracking": True}),
            PayloadRecommendation(payload_type="com.apple.applicationaccess",
                                  rationale="r3", fields={"allowGameCenter": False}),
        ],
    )
    profile_bytes = build_profile(rec, udid="00008101-000A2D14", removal_password="x")
    parsed = plistlib.loads(profile_bytes)
    ids = [p["PayloadIdentifier"] for p in parsed["PayloadContent"]]
    assert len(ids) == len(set(ids)), f"duplicate PayloadIdentifier(s) in {ids}"
    # Uniqueness applied to PayloadUUID too (separate Apple invariant).
    uuids = [p["PayloadUUID"] for p in parsed["PayloadContent"]]
    assert len(uuids) == len(set(uuids))
