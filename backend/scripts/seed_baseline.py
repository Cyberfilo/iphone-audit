#!/usr/bin/env python3
"""Seed a MobileGestalt baseline JSON for a connected device.

Usage:
    python scripts/seed_baseline.py --udid <UDID> [--out-dir DIR]

Writes <ProductType>_<BuildVersion>.json into the baselines folder.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

# Allow running this script without installing the package.
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

from iphone_audit.audit.gestalt import GESTALT_KEYS, query_gestalt, BASELINE_DIR
from iphone_audit.extraction import lockdown


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--udid", required=True)
    parser.add_argument("--out-dir", type=Path, default=BASELINE_DIR)
    args = parser.parse_args()

    snap = lockdown.snapshot(args.udid)
    if snap.error:
        print(f"lockdown error: {snap.error}", file=sys.stderr)
        return 1
    model = snap.identity.get("ProductType")
    build = snap.identity.get("BuildVersion")
    if not (model and build):
        print("could not read ProductType/BuildVersion", file=sys.stderr)
        return 1

    values = query_gestalt(args.udid)
    if values is None:
        print(
            "MobileGestalt query failed — likely iOS ≥ 17.4 (Apple removed the "
            "endpoint). Cannot seed baseline via this path.",
            file=sys.stderr,
        )
        return 2

    args.out_dir.mkdir(parents=True, exist_ok=True)
    target = args.out_dir / f"{model}_{build}.json"
    target.write_text(json.dumps({k: values.get(k) for k in GESTALT_KEYS}, indent=2))
    print(f"wrote {target}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
