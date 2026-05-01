"""Pydantic schema for the LLM's structured output."""
from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field

ALLOWED_PAYLOAD_TYPES = (
    "com.apple.applicationaccess",
    "com.apple.passcode",
    "com.apple.dnsSettings.managed",
    "com.apple.vpn.managed",
    "com.apple.wifi.managed",
    "com.apple.relay.managed",
    "com.apple.webcontent-filter",
    "com.apple.profileRemovalPassword",
)


class PayloadRecommendation(BaseModel):
    payload_type: str = Field(
        description="Apple PayloadType identifier from the allowlist."
    )
    rationale: str = Field(
        description="One-paragraph explanation tied to specific finding IDs."
    )
    fields: dict = Field(
        default_factory=dict,
        description="Key-value pairs to set in this payload. Apple-documented keys only.",
    )
    addresses_finding_ids: list[str] = Field(
        default_factory=list,
        description="IDs of findings this payload helps address.",
    )


class HardeningRecommendation(BaseModel):
    summary: str = Field(description="Plain-English summary of overall posture.")
    risk_level: Literal["low", "medium", "high", "critical"]
    payloads: list[PayloadRecommendation] = Field(default_factory=list)
    user_actions: list[str] = Field(
        default_factory=list,
        description="Actions the user must do manually (Lockdown Mode, backup pw, remove rogue profile…).",
    )
    deferred_findings: list[str] = Field(
        default_factory=list,
        description="Finding IDs that cannot be addressed by a profile (informational).",
    )
