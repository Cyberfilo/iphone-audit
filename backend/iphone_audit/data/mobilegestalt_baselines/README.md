# MobileGestalt Baselines

Per-device, per-build snapshots of MobileGestalt feature flags. Used by
`audit/gestalt.py` to detect SparseRestore-style tampering (Nugget, MisakaX).

## File naming

```
<ProductType>_<BuildVersion>.json
```

Examples (your three target devices):

- `iPhone13,3_22G91.json`  — iPhone 12 Pro Max @ iOS 18.6.2
- `iPhone14,5_25Gxxx.json` — iPhone 13 @ iOS 26.3.1
- `iPhone17,1_<build>.json` — iPhone 16 Pro @ latest

> `BuildVersion` is the four/five-character build number (e.g. `22G91`), not the
> human iOS version.

## File schema

Flat JSON object: each `audit/gestalt.py` `GESTALT_KEYS` entry → expected value.

```json
{
  "BootChimeIsEnabled": false,
  "DeviceSupportsLandscape": true,
  "DynamicIslandCapability": true,
  "DeviceSupportsApplePencil": false,
  "ApplePencilCapability": false,
  "ShutterClickConfiguration": "Full",
  "StageManagerSupported": true,
  "MainScreenWidth": 1284,
  "MainScreenHeight": 2778
}
```

## Seeding

> ⚠ Apple removed the diagnostics MobileGestalt endpoint on **iOS 17.4+**. All
> three target devices are above that. Seeding via this path will fail and the
> audit will surface `gestalt.unavailable_modern_ios` (INFO) instead of running
> the integrity check. The seed script remains useful for older devices and
> for future fallback paths.

From the repo root, with a presumed-clean device connected:

```bash
cd backend
python scripts/seed_baseline.py --udid <UDID>
```

It writes `<ProductType>_<BuildVersion>.json` here.
