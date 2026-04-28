"""iSpow — iPhone audit and hardening backend."""
from __future__ import annotations
from pathlib import Path

__all__ = ["__version__"]


def _read_version() -> str:
    here = Path(__file__).resolve().parent
    for parent in [here, *here.parents]:
        candidate = parent / "VERSION"
        if candidate.is_file():
            return candidate.read_text().strip()
    return "0.000"


__version__ = _read_version()
