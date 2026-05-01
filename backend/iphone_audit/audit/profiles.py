"""Configuration profile audit — root CA, MDM, VPN flags."""
from __future__ import annotations

from ..extraction.profiles import InstalledProfile
from .rules import Finding, Severity, Category


def check(profs: list[InstalledProfile]) -> list[Finding]:
    findings: list[Finding] = []
    for p in profs:
        if p.has_root_ca:
            findings.append(
                Finding(
                    id=f"profile.root_ca.{p.payload_identifier}",
                    severity=Severity.HIGH,
                    category=Category.PRIOR_COMPROMISE,
                    title=f"Custom root CA installed: {p.display_name}",
                    description=(
                        "This profile installs a certificate authority. Any HTTPS "
                        "site can be intercepted by the certificate's owner. "
                        "Verify you trust the source; remove if not legitimate."
                    ),
                    evidence={
                        "identifier": p.payload_identifier,
                        "organization": p.organization,
                    },
                )
            )
        if p.has_mdm_payload:
            findings.append(
                Finding(
                    id=f"profile.mdm.{p.payload_identifier}",
                    severity=Severity.HIGH,
                    category=Category.PRIOR_COMPROMISE,
                    title=f"MDM enrollment present: {p.display_name}",
                    description=(
                        "An MDM server can install/remove apps, read device state, "
                        "and push policies. Verify the enrollment is legitimate."
                    ),
                    evidence={
                        "identifier": p.payload_identifier,
                        "organization": p.organization,
                    },
                )
            )
        if p.has_vpn_payload:
            findings.append(
                Finding(
                    id=f"profile.vpn.{p.payload_identifier}",
                    severity=Severity.MEDIUM,
                    category=Category.NETWORK,
                    title=f"VPN configuration present: {p.display_name}",
                    description=(
                        "A VPN profile can route all traffic through a remote "
                        "server. Verify the endpoint is one you control."
                    ),
                    evidence={"identifier": p.payload_identifier},
                )
            )
    return findings
