"""Entitlement audit over user-installed apps.

Splits findings into two severities:
  HIGH — private/Apple-internal entitlements that legitimate App Store apps
         should never hold (jailbreak / spyware territory).
  LOW  — notable but legitimate entitlements (NetworkExtension, VPN APIs)
         that are normal for VPN/firewall apps but worth confirming.
"""
from __future__ import annotations

from ..extraction.apps import InstalledApp, PRIVATE_ENTITLEMENTS, NOTABLE_ENTITLEMENTS
from .rules import Finding, Severity, Category


def check(apps: list[InstalledApp]) -> list[Finding]:
    findings: list[Finding] = []
    for app in apps:
        private = [e for e in app.entitlements if e in PRIVATE_ENTITLEMENTS]
        notable = [e for e in app.entitlements if e in NOTABLE_ENTITLEMENTS]

        if private:
            findings.append(
                Finding(
                    id=f"entitlement.private.{app.bundle_id}",
                    severity=Severity.HIGH,
                    category=Category.PRIOR_COMPROMISE,
                    title=f"App holds private Apple entitlements: {app.display_name}",
                    description=(
                        f"{app.display_name} ({app.bundle_id}) holds private "
                        f"Apple-internal entitlements: {', '.join(private)}. "
                        "These are not available to App Store developers and "
                        "are a strong indicator of a sideloaded or tampered "
                        "binary. Investigate this app."
                    ),
                    evidence={
                        "bundle_id": app.bundle_id,
                        "private_entitlements": private,
                    },
                )
            )

        if notable:
            findings.append(
                Finding(
                    id=f"entitlement.notable.{app.bundle_id}",
                    severity=Severity.LOW,
                    category=Category.PRIVACY_LEAK,
                    title=f"App can route network traffic: {app.display_name}",
                    description=(
                        f"{app.display_name} holds NetworkExtension/VPN "
                        "entitlements ({}). Normal for VPN, firewall, and "
                        "content-blocker apps. Worth confirming you "
                        "installed it and trust the publisher."
                    ).format(", ".join(notable)),
                    evidence={
                        "bundle_id": app.bundle_id,
                        "entitlements": notable,
                    },
                )
            )
    return findings
