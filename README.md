# iSpow — iPhone Audit & Hardening

A personal macOS tool that audits an iPhone for indicators of prior compromise, hardens it via a configuration profile, and verifies the result with a before/after diff. Two parts:

- **Python backend** (`backend/`) — CLI + JSON-RPC daemon. Drives `pymobiledevice3` for everything device-side.
- **SwiftUI macOS app** (`frontend/`) — three-pane window (Devices · Wizard · Report) talking to the daemon over a Unix socket.

Tested on iPhone 12 Pro Max (iOS 18.6.2), iPhone 13 (iOS 26.3.1), iPhone 16 Pro (latest iOS).

## Status & scope

- **Type**: personal-use tool + portfolio piece
- **Stage**: v1.000 shipped (initial release). Active development on the audit-rules library and the hardening payload set.
- **Persona**: one user, one Mac, one or more iPhones-you-own
- **Not designed for**: enterprise MDM-style rollout, multi-tenant scenarios, or auditing devices that aren't yours
- **Open to scale**: no — this is intentionally a personal-discipline tool, not a service

---

## Requirements

- macOS 13+ (the Swift Package targets `.macOS(.v13)`).
- Python 3.11+ (`python3 --version`).
- Optional: full Xcode for the SwiftUI app — Command Line Tools alone is insufficient on macOS 26 due to a missing `SWBBuildService` framework in `swift package`. (You can still type-check with `swiftc -typecheck` — see "Build the app" below.)
- Optional: `OPENAI_API_KEY` for LLM-driven recommendations. Without one, the rule-based fallback runs automatically.

---

## Backend — install and run

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"
```

### CLI

```bash
# List devices
iphone-audit list

# Quick scan (lockdown + apps + profiles + posture)
iphone-audit quick-scan --udid <UDID> --output report.json --html report.html

# Generate a recommendation (rule-based; add OPENAI_API_KEY for LLM)
iphone-audit advise --findings report.json --output recommendation.json
iphone-audit advise --findings report.json --no-llm --output recommendation.json

# Build .mobileconfig + push to device + store removal pw in Keychain
iphone-audit harden --udid <UDID> --recommendation recommendation.json

# Re-run audit and diff against an earlier report
iphone-audit verify --udid <UDID> --before report.json --output diff.json

# Secret management
iphone-audit secret show --udid <UDID>
iphone-audit secret rotate --udid <UDID>
iphone-audit secret delete --udid <UDID>

# Mac-side pairing record audit
sudo iphone-audit pairing list
sudo iphone-audit pairing revoke --udid <UDID>
sudo iphone-audit pairing revoke-all

# Crash report capture
iphone-audit crashes --udid <UDID> --out ./crashes

# Self-signed signing cert (optional; profiles install fine unsigned)
iphone-audit init-signing-cert
iphone-audit harden --udid <UDID> --recommendation recommendation.json \
  --sign --cert ~/.config/iphone-audit/signing/signer.pem \
  --key  ~/.config/iphone-audit/signing/signer.key

# Run the JSON-RPC daemon (the Swift app does this automatically)
iphone-audit daemon --socket /tmp/iphone-audit.sock
```

### Tests

```bash
cd backend
pytest
```

Tests use synthetic inputs only — no device required.

---

## Frontend — build and run

The frontend ships as a Swift Package with an executable target.

### With full Xcode installed

```bash
cd frontend
swift run iSpow              # builds and launches the app
# or:
open Package.swift           # opens the package in Xcode
```

### Type-check without Xcode (no run)

If only Command Line Tools are installed, `swift package` is broken on macOS 26. You can still verify the sources compile:

```bash
cd frontend
/usr/bin/swiftc -typecheck \
  -target arm64-apple-macos13 \
  -sdk "$(xcrun --show-sdk-path --sdk macosx)" \
  Sources/iSpow/*.swift
```

To run the GUI you'll need Xcode.app from the App Store.

### How the app talks to the backend

On launch, `BackendBridge` spawns the Python daemon (uses `IPHONE_AUDIT_PYTHON` env var, else `/usr/bin/env python3 -m iphone_audit daemon`) and connects to `/tmp/iphone-audit.sock`. State transitions surface in the sidebar.

If your `python3` doesn't have the backend installed, point `IPHONE_AUDIT_PYTHON` at the venv's interpreter:

```bash
export IPHONE_AUDIT_PYTHON="$(pwd)/backend/.venv/bin/python"
```

---

## Wizard flow

1. **Audit** — quick-scan the connected iPhone.
2. **Advice** — generate a `HardeningRecommendation` (LLM or rule-based).
3. **Confirm** — review payloads + manual actions.
4. **Install** — push `.mobileconfig`, reveal removal password (also stored in Keychain).
5. **Verify** — re-run audit, diff against the baseline.
6. **Done** — see resolved/unchanged/new findings.

---

## Versioning

`VERSION` holds the current version in `x.yza` form:

| Bump | When |
|------|------|
| `x` | major logic change OR important feature |
| `y` | new feature |
| `z` | improvement (refactor/perf/quality) |
| `a` | bug fix or correction |

Every bump → entry in [`CHANGELOG.md`](./CHANGELOG.md).

---

## Project layout

```
iSpow/
├── README.md
├── CHANGELOG.md
├── VERSION             # 1.000
├── backend/
│   ├── pyproject.toml
│   ├── iphone_audit/
│   │   ├── extraction/   lockdown · profiles · apps · crashes · backup · devices
│   │   ├── audit/        rules · stalkerware · profiles · pairing · gestalt · posture · entitlements
│   │   ├── llm/          schema · advisor (+ rule-based fallback)
│   │   ├── hardening/    builder · payloads · secret · install
│   │   ├── report/       diff · render
│   │   ├── data/         stalkerware_bundles.json · mobilegestalt_baselines/
│   │   ├── cli.py        click subcommands
│   │   └── daemon.py     JSON-RPC over Unix socket
│   ├── scripts/seed_baseline.py
│   └── tests/            synthetic-input pytest suite
└── frontend/
    ├── Package.swift     SwiftPM executable target, macOS 13+
    └── Sources/iSpow/    SwiftUI views + UnixSocket JSON-RPC bridge
```

---

## Honest caveats

- **MobileGestalt integrity check is unavailable on iOS ≥ 17.4.** Apple removed the diagnostics endpoint. All three target devices are above that threshold, so the audit emits `gestalt.unavailable_modern_ios` (INFO) instead of running the comparison. Other audit checks remain in effect.
- **Profiles install with a "Verified"/"Unverified" warning** depending on signing. Self-signed for personal use is fine — adds no real security since you're both issuer and verifier.
- **Pairing record audit needs `sudo`** on modern macOS to read `/var/db/lockdown/`.
- **First run** of the harden flow stores the removal password in Keychain without an app ACL (`-T`). Reads will prompt the macOS Keychain UI the first time per session.

---

## License

GPL-3.0-or-later. See `LICENSE`.

This is a personal-use tool. It is provided as-is, with no warranty. Audit your own devices, not someone else's.
