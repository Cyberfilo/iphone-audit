from iphone_audit.audit.rules import AuditReport, Finding, Severity, Category
from iphone_audit.report.diff import DiffReport


def _f(fid: str, sev: Severity = Severity.HIGH) -> Finding:
    return Finding(id=fid, severity=sev, category=Category.POSTURE,
                   title=fid, description="")


def test_diff_resolved_unchanged_new():
    before = AuditReport(udid="x", device_model="x", ios_version="x",
                         findings=[_f("a"), _f("b")])
    after = AuditReport(udid="x", device_model="x", ios_version="x",
                        findings=[_f("b"), _f("c")])
    diff = DiffReport.compute(before, after)
    assert {f.id for f in diff.resolved} == {"a"}
    assert {f.id for f in diff.unchanged} == {"b"}
    assert {f.id for f in diff.new} == {"c"}


def test_diff_empty_after():
    before = AuditReport(udid="x", device_model="x", ios_version="x",
                         findings=[_f("a"), _f("b")])
    after = AuditReport(udid="x", device_model="x", ios_version="x", findings=[])
    diff = DiffReport.compute(before, after)
    assert {f.id for f in diff.resolved} == {"a", "b"}
    assert diff.new == []
    assert diff.unchanged == []
