from iphone_audit.llm.advisor import rule_based_fallback
from iphone_audit.llm.schema import HardeningRecommendation


def test_fallback_produces_valid_schema(synthetic_report):
    rec = rule_based_fallback(synthetic_report)
    assert isinstance(rec, HardeningRecommendation)
    assert rec.risk_level in ("low", "medium", "high", "critical")
    assert rec.payloads, "expected at least one payload (restrictions baseline)"


def test_fallback_includes_passcode_payload_when_no_passcode(synthetic_report):
    rec = rule_based_fallback(synthetic_report)
    types = {p.payload_type for p in rec.payloads}
    assert "com.apple.passcode" in types
    assert "com.apple.applicationaccess" in types


def test_fallback_defers_compromise_findings(synthetic_report):
    rec = rule_based_fallback(synthetic_report)
    assert any(fid.startswith("stalkerware.") for fid in rec.deferred_findings)
    assert any("stalkerware" in a.lower() or "mspy" in a.lower() for a in rec.user_actions)


def test_fallback_max_severity_critical(synthetic_report):
    rec = rule_based_fallback(synthetic_report)
    assert rec.risk_level == "critical"


def test_fallback_empty_report():
    from iphone_audit.audit.rules import AuditReport
    rec = rule_based_fallback(AuditReport(udid="x", device_model="x", ios_version="x"))
    assert rec.risk_level == "low"
