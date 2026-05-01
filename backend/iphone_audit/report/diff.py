"""Before/after audit diff."""
from __future__ import annotations

from dataclasses import dataclass, field

from ..audit.rules import AuditReport, Finding


@dataclass
class DiffReport:
    before: AuditReport
    after: AuditReport
    resolved: list[Finding] = field(default_factory=list)
    unchanged: list[Finding] = field(default_factory=list)
    new: list[Finding] = field(default_factory=list)

    @classmethod
    def compute(cls, before: AuditReport, after: AuditReport) -> "DiffReport":
        before_ids = {f.id: f for f in before.findings}
        after_ids = {f.id: f for f in after.findings}

        resolved = [f for fid, f in before_ids.items() if fid not in after_ids]
        unchanged = [f for fid, f in after_ids.items() if fid in before_ids]
        new = [f for fid, f in after_ids.items() if fid not in before_ids]

        return cls(
            before=before,
            after=after,
            resolved=resolved,
            unchanged=unchanged,
            new=new,
        )

    def to_dict(self) -> dict:
        return {
            "before": self.before.to_dict(),
            "after": self.after.to_dict(),
            "resolved": [f.to_dict() for f in self.resolved],
            "unchanged": [f.to_dict() for f in self.unchanged],
            "new": [f.to_dict() for f in self.new],
        }
