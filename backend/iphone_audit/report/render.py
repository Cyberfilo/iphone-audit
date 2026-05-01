"""HTML/JSON rendering of audit and diff reports."""
from __future__ import annotations

import html
import json
from dataclasses import is_dataclass, asdict

from ..audit.rules import AuditReport, Finding, Severity
from .diff import DiffReport

_SEVERITY_COLOR = {
    Severity.INFO: "#9aa0a6",
    Severity.LOW: "#1a73e8",
    Severity.MEDIUM: "#f29900",
    Severity.HIGH: "#d93025",
    Severity.CRITICAL: "#9334e6",
}


def render_report_json(report: AuditReport, indent: int = 2) -> str:
    return json.dumps(report.to_dict(), default=_json_default, indent=indent)


def render_diff_json(diff: DiffReport, indent: int = 2) -> str:
    return json.dumps(diff.to_dict(), default=_json_default, indent=indent)


def render_report_html(report: AuditReport) -> str:
    findings_html = "\n".join(_finding_html(f) for f in report.findings) or "<p>No findings.</p>"
    return _BASE_HTML.format(
        title=html.escape(f"Audit — {report.device_model} ({report.ios_version})"),
        body=f"""
        <h1>Audit Report</h1>
        <p><strong>Device:</strong> {html.escape(report.device_model)} —
           <strong>iOS:</strong> {html.escape(report.ios_version)} —
           <strong>UDID:</strong> {html.escape(report.udid)}</p>
        <p><strong>Findings:</strong> {len(report.findings)} —
           <strong>Max severity:</strong> {report.max_severity().value}</p>
        <h2>Findings</h2>
        {findings_html}
        """,
    )


def render_diff_html(diff: DiffReport) -> str:
    sections = []
    for label, items, color in (
        ("Resolved", diff.resolved, "#188038"),
        ("Unchanged", diff.unchanged, "#9aa0a6"),
        ("New", diff.new, "#d93025"),
    ):
        section_body = "\n".join(_finding_html(f) for f in items) or "<p><em>none</em></p>"
        sections.append(
            f"<h2 style='color:{color}'>{label} ({len(items)})</h2>{section_body}"
        )
    return _BASE_HTML.format(
        title="Audit Diff",
        body="<h1>Before / After Audit Diff</h1>" + "\n".join(sections),
    )


def _finding_html(f: Finding) -> str:
    color = _SEVERITY_COLOR[f.severity]
    return f"""
    <div style="border-left:4px solid {color}; padding:8px 12px; margin:8px 0;
                background:#fafbfc; border-radius:4px;">
        <div style="font-size:0.8em; color:{color}; text-transform:uppercase;
                    letter-spacing:.06em; margin-bottom:4px;">
            {f.severity.value} · {f.category.value}
        </div>
        <div style="font-weight:600;">{html.escape(f.title)}</div>
        <div style="margin-top:4px;">{html.escape(f.description)}</div>
        <div style="font-size:0.75em; color:#5f6368; margin-top:6px;">{html.escape(f.id)}</div>
    </div>
    """


_BASE_HTML = """<!doctype html>
<html><head>
<meta charset="utf-8">
<title>{title}</title>
<style>
body {{ font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", system-ui, sans-serif;
       max-width: 880px; margin: 32px auto; padding: 0 16px; color:#202124; }}
h1 {{ font-size: 1.6em; margin-bottom: 0.2em; }}
h2 {{ font-size: 1.2em; margin-top: 1.6em; }}
em {{ color:#5f6368; }}
</style>
</head><body>
{body}
</body></html>"""


def _json_default(obj):
    if hasattr(obj, "to_dict"):
        return obj.to_dict()
    if is_dataclass(obj):
        return asdict(obj)
    if hasattr(obj, "value"):
        return obj.value
    return str(obj)
