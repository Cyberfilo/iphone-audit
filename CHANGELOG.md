# Changelog — iSpow

All notable changes to this project will be documented here.

Versioning format: `x.yza` (per user spec)
- `x` — major logic change OR important feature
- `y` — new feature
- `z` — improvement (refactor, perf, quality)
- `a` — bug fix or correction

---

## 2.301 — 2026-05-03

**Fixed** — iOS rejected the `.mobileconfig` with
`"i payload non hanno valori PayloadIdentifier univoci
('app.iphoneharden.applicationaccess.<UDID>' viene usato più volte)"`.

Root cause: the V2.200 anonymous-lockdown feature emits a second
`com.apple.applicationaccess` child alongside the baseline restrictions.
`builder._render_payload` set every payload's `PayloadIdentifier` to
`{TOP_LEVEL_ID}.{short_type}.{udid[:8]}` — fine for one payload per type,
but Apple's profile validator rejects duplicates within a single profile.

Fix: `build_profile` now keeps a per-PayloadType counter and passes it
into `_render_payload(rec, udid, index)`. The first child of each type
keeps the original suffix (`<udid8>`); subsequent children get
`<udid8>.<index>`. PayloadUUIDs were already unique (uuid4 each).

**Tests** — new `test_payload_identifiers_unique_with_repeated_payload_types`
builds a profile with three `com.apple.applicationaccess` children and
asserts all `PayloadIdentifier` and `PayloadUUID` values are distinct.
**37/37 passing.**

---

## 2.300 — 2026-05-03

**Added** — every built `.mobileconfig` is also archived to a user-visible
folder, with a "Reveal in Finder" button right inside the removal-password
modal.

**Backend**
- `daemon._archive_profile_path(udid)` — returns
  `~/Documents/iSpow-profiles/profile-<udid>-<YYYYMMDD-HHMMSS>.mobileconfig`.
- `daemon._write_profile_with_archive(...)` writes the bytes to **both**:
  * canonical: `~/Library/Application Support/iSpow/profiles/profile-<udid>.mobileconfig`
    (stable per device, used by `MobileConfigService.install_profile`)
  * archive:   `~/Documents/iSpow-profiles/profile-<udid>-<timestamp>.mobileconfig`
    (timestamped, never overwrites — full build history)
- `build_profile` and `build_and_install` RPCs now return both paths in
  `profile_path` (canonical) and `archive_path` (visible).

**Frontend**
- `BuildProfileResult.archivePath` (optional) added to the model.
- `RemovalPasswordModal` shows a third info row beneath the Keychain badge
  with the archive path + a "Reveal" button that opens the file in Finder
  via `NSWorkspace.activateFileViewerSelecting`.
- ContentView passes `backend.lastBuildResult?.archivePath` into the modal.

**Behavior**
1. Build & Install pushes the profile to the iPhone.
2. Modal pops up showing:
   - Removal password (revealable, copyable, saved to Keychain)
   - **NEW**: Path to the archived `.mobileconfig` + Reveal-in-Finder button
   - Second-storage warning to also paste into 1Password/Bitwarden
3. Each subsequent build adds a new timestamped file to
   `~/Documents/iSpow-profiles/`, so you can audit history or share a
   specific build.

**Tests** — 36/36 still passing; the daemon's profile-write helper is
exercised end-to-end via the `build_profile` and `build_and_install`
methods and verified to produce both files.

---

## 2.200 — 2026-05-03

**Added** — "Anonymous lockdown" payload. When no Apple ID is signed in,
silence every Apple endpoint that would still phone home unauthenticated.

**Backend — Apple ID detection**
- New `posture.detect_apple_id(snap)` reads `com.apple.mobile.data_sync` and
  returns `True` (sync accounts present), `False` (domain readable but
  empty → no Apple ID), or `None` (domain not readable — typical on iOS 17+
  consumer devices).
- New findings:
  * `posture.no_apple_id` (INFO) — surfaced when domain is empty. Includes
    the rationale + recommends enabling the Anonymous lockdown payload.
  * `posture.apple_id_unknown` (INFO) — surfaced when domain is restricted.
    Tells the user the payload is still available for them to enable
    manually.

**Backend — payload set**
- `hardening/payloads.py` `ALLOWED_FIELDS` extended with the privacy keys
  the new payload uses: `allowApplePersonalizedAdvertising`,
  `allowAssistantUserGeneratedContent`, `allowDictation`,
  `allowSpotlightInternetResults`, `allowCloudBackup`,
  `allowCloudDocumentSync`, `allowCloudPhotoLibrary`, `allowMyPhotoStream`,
  `allowSharedStream`, `allowGameCenter`, `allowFindMyDevice`,
  `allowFindMyFriends`, `safariAllowAutoFill`.
- `llm/advisor.py` exports `ANONYMOUS_LOCKDOWN_FIELDS` (the canonical 19-key
  dict). Rule-based fallback now appends a second `com.apple.applicationaccess`
  payload with this set when `posture.no_apple_id` is in the report.
- Rule-based fallback also appends 8 manual user-actions covering the things
  iOS won't let a `.mobileconfig` flip (Improve Siri & Dictation, Significant
  Locations, iCloud Private Relay, DNS resolver swap, Apple analytics
  endpoint blocklist).

**Frontend**
- New `pl-anonymous` toggle in the Hardening Profile screen, default OFF.
  Long-form explanation in the row blurb.
- `BackendBridge.payloadToBackendDict` maps it to a 19-key
  `com.apple.applicationaccess` payload (matches the backend's set).
- `ContentView.applyFindingDrivenDefaults` flips the toggle to ON when the
  audit returns `posture.no_apple_id` so the user sees a sensible default
  on the Harden screen without having to toggle it manually.

**Concrete privacy flags applied** (all set to `false` unless noted):

```
allowDiagnosticSubmission          allowSiriServerLogging
allowDiagnosticSubmissionModification   allowAssistantUserGeneratedContent
forceLimitAdTracking (=true)       allowDictation
allowApplePersonalizedAdvertising  allowSpotlightInternetResults
allowCloudBackup                   safariAllowAutoFill
allowCloudDocumentSync             allowCloudPhotoLibrary
allowMyPhotoStream                 allowSharedStream
allowCloudKeychainSync             allowGameCenter
allowFindMyDevice                  allowFindMyFriends
```

**Tests** — 4 new tests pin Apple ID detection (empty/unknown/present
domains) + the advisor recommendation. **36/36 passing**.

---

## 2.100 — 2026-05-03

**Added** — clicking "Build & Install" actually pushes the `.mobileconfig`
to the connected iPhone in one round-trip (was previously a mock-only flow
that never called the backend).

**Backend**
- New JSON-RPC method `build_and_install` — combines `build_profile` +
  `install_profile` so the daemon writes the .mobileconfig and pushes it
  via `MobileConfigService.install_profile` in one shot. Both legacy methods
  remain for CLI use.
- Default profile output path is now
  `~/Library/Application Support/iSpow/profiles/profile-<udid>.mobileconfig`
  (parent directory created on demand). Previously the daemon wrote
  `profile-<udid>.mobileconfig` to its CWD — when launched by the .app that
  inherits `/`, which is unwritable.
- `install_profile` and `build_and_install` now run the blocking
  `MobileConfigService.install_profile(...)` call via `asyncio.to_thread`
  so the daemon doesn't block the JSON-RPC event loop while pushing.

**Frontend**
- `BackendBridge.buildAndInstall(udid:payloads:)` — converts the user's
  toggled `PayloadOption`s into the backend `HardeningRecommendation` JSON
  and calls the new RPC. Eight payload IDs are mapped to their Apple
  PayloadType + field set:

  | id | type | fields |
  |---|---|---|
  | `pl-passcode` | `com.apple.passcode` | `forcePIN`, `requireAlphanumeric`, `minLength=8`, `minComplexChars=1`, `maxFailedAttempts=10`, `maxInactivity=2`, `pinHistory=5` |
  | `pl-restrict-lockscreen` | `com.apple.applicationaccess` | `allowLockScreenControlCenter=false`, `allowLockScreenNotificationsView=false`, `allowLockScreenTodayView=false` |
  | `pl-airdrop` | `com.apple.applicationaccess` | `allowAirDrop=false` |
  | `pl-backup-enc` | `com.apple.applicationaccess` | `forceEncryptedBackup=true` |
  | `pl-ads` | `com.apple.applicationaccess` | `forceLimitAdTracking=true`, `allowDiagnosticSubmission=false`, `allowDiagnosticSubmissionModification=false`, `allowSiriServerLogging=false` |
  | `pl-keychain` | `com.apple.applicationaccess` | `allowCloudKeychainSync=false` |
  | `pl-enterprise` | `com.apple.applicationaccess` | `allowEnterpriseAppTrust=false` |
  | `pl-removal` | (locked, dropped — backend always inserts its own RemovalPassword child) | n/a |

- `ContentView.buildAndInstall()` — wired to both the `ContentToolbar`
  "Build & Install" action and the `HardenScreen` button. When the selected
  device matches a real backend device, calls the bridge; otherwise stays
  in mock mode (modal shows the canned password) so the demo still walks
  end-to-end without an iPhone connected.
- The removal-password modal is now driven by `lastPassword` (the value
  the daemon actually generated and stored in Keychain) rather than a
  hardcoded string.
- New `installError` state surfaces backend failures inline (e.g. device
  unplugged mid-push, daemon down).

**Behavior**
1. User toggles payloads on Harden screen, clicks Build & Install.
2. Daemon writes the .mobileconfig to `~/Library/Application Support/iSpow/profiles/`.
3. `MobileConfigService.install_profile` queues it on the iPhone — system
   "Install Profile" sheet appears in iOS Settings → General → VPN & Device
   Management.
4. App reveals the generated removal password in the modal (also stored in
   Keychain as `iPhoneHarden-<UDID>`).
5. User taps "I saved it" → wizard advances to Verify.

**Verified** — built `iSpow.app`, 32/32 backend tests pass, daemon RPC
contract intact.

---

## 2.002 — 2026-05-03

**Fixed** — backend audit false positives on real iOS 17+ devices.

- `posture.no_passcode` fired CRITICAL on devices that had a passcode set.
  Root cause: iOS 17+ restricts the `PasswordProtected` lockdown identity
  key on consumer devices; pymobiledevice3 returns `None` instead of `True`,
  and `posture.py` treated missing the same as `False`. Now distinguishes
  three cases: explicitly `False` → CRITICAL, explicitly `True/None` →
  silent, missing → INFO `posture.passcode_unknown` ("could not be read").
- `entitlement.<bundle>` fired MEDIUM on dozens of routine apps. Root cause:
  `RISKY_ENTITLEMENTS` lumped truly private Apple-internal entitlements
  (`com.apple.private.networkextension`) with bog-standard ones held by
  every messenger / fitness / iCloud app (`com.apple.security.application-
  groups`, `com.apple.developer.icloud-services`, `com.apple.developer.
  healthkit`, `com.apple.developer.contacts`, `com.apple.developer.
  usernotifications.filtering`).
  Split into two lists with different severity:
    * `PRIVATE_ENTITLEMENTS` → HIGH, category `prior_compromise`. Apple-
      internal flags that App Store apps should never hold (sideload /
      spyware indicator).
    * `NOTABLE_ENTITLEMENTS` → LOW, category `privacy_leak`. Network-
      Extension and VPN APIs — normal for VPN/firewall apps but worth
      confirming the publisher.
  Routine entitlements no longer fire any finding.

**Tests**
- New: `test_passcode_unknown_when_key_missing` — guards the iOS 17+ regression.
- New: `test_private_entitlement_is_high`, `test_notable_entitlement_is_low`,
  `test_routine_entitlements_no_finding` — pin the split severity model.
- Updated: replaced the old `test_risky_entitlement_emits_finding`.
- All 32 tests green.

**Frontend (carried over from troubleshooting)**
- Added `Logger.swift` writing to `/tmp/ispow.log` plus `NSLog` (Console.app).
  Reset on each launch. Tail with: `tail -f /tmp/ispow.log`.
- `BackendBridge.readLoop` was running on the `@MainActor`-isolated bridge
  even when dispatched via `Task.detached`, so the blocking `read(2)` call
  was stalling the main thread (caught in two `.hang` reports under
  `/Library/Logs/DiagnosticReports/`). Replaced with a `DispatchQueue.global
  (qos: .userInitiated).async` loop that posts results back to `@MainActor`
  via `Task { @MainActor in … }`. Watchdog hangs no longer reproduce.

---

## 2.001 — 2026-05-03

**Fixed**
- App froze with the spinning wait cursor when the user clicked a different
  device in the sidebar. Root cause: `WindowGroup.windowResizability(.contentSize)`
  forced the window to recompute its size against the new content tree on every
  state change — with the redesign's deeply nested screens (HSplitView in
  `HardenScreen`, GeometryReader in the histogram, etc.), the resize storm
  pushed the main thread past the watchdog. Switched to `.contentMinSize`,
  which honors a minimum but doesn't auto-resize on content changes.
- Sidebar shipped with three mock iPhones visible by default; they should only
  appear once a real device is connected. `displayDevices` now returns
  `backend.devices` only — no fallback to `Mock.devices`.
- Selecting a different device kept stale `liveFindings` from the previous
  one. `ContentView` now resets `liveFindings`, `verified`, `installPhase`,
  `scanning`, `showXml` whenever `selectedDevice?.id` changes.
- `runScan` would fall through to a 3.4-second mock-sleep when no real device
  was selected, leaving the UI in a fake `scanning = true` state with no
  device. It now early-returns when no real device matches.

**Added**
- `NoDeviceState` view in the content area when no device is selected —
  empty-state icon + plain-English instruction + backend-state indicator +
  Refresh button.
- `Sidebar.emptyDeviceHint` row when zero devices are connected — replaces
  the device list with a "Plug in an iPhone via USB…" hint card.

---

## 2.000 — 2026-05-03

**Added** — full visual redesign implementing the Claude Design hi-fi prototype
(`ios-app-vuoln/project/iSpow.html`). Major UX shift from the V1 three-pane
NavigationSplitView to a custom dark "forensics console" layout.

**Design system**
- `Theme.swift` — design tokens mirroring `theme.jsx`: layered near-black
  surfaces (`bg0`–`bg4`), three line weights, four-tier text hierarchy,
  cyan-green accent (oklch-derived), full severity scale.
- Primitives: `SeverityPill`, `SeverityDot`, `Eyebrow`, `Panel`, `Btn` (5
  variants), `LogoView` (shield + concentric pulse), custom `TrafficLights`,
  `VibrancyView` (NSVisualEffectView wrapper).

**Window chrome**
- `iPhoneHardenApp` switched to `.windowStyle(.hiddenTitleBar)` — the app
  draws its own traffic-light cluster in the sidebar header.
- Min window size raised to 1180×760 to match the 1360×880 design.

**Sidebar (`Sidebar.swift`)**
- Brand area with logo + version badge.
- Devices list with iPhone glyph, online/posture status dot.
- Two-section nav: Device (Audit / Pairings / Hardening Profile / Verify) and
  App (History / Settings).
- LLM connection badge in the footer.

**ContentToolbar (`ContentToolbar.swift`)**
- Per-route title + subtitle + actions; route-specific buttons surface
  `Re-scan`, `Harden device`, `View raw`, `Build & Install`, `Re-run audit`.

**Screens**
- `AuditScreen` — `DeviceHero` with phone-card mock, identity grid,
  posture-score panel + severity histogram. Filter bar (search + severity
  segmented + category pills). Expandable `FindingRow`s with metadata + Copy
  JSON. Animated `ScanningOverlay` with step log.
- `PairingsScreen` — KPI strip, escrow-keybag explainer, expandable host rows
  with capability checklist + revoke.
- `HardenScreen` — payload toggle list with impact pills + locked removal-
  password row, raw-XML toggle, profile-metadata sidebar.
- `VerifyScreen` — install ceremony with on-device "Install Profile" mock +
  before/after diff with status pills (Resolved / Unchanged / New).
- `HistoryScreen` — colored event-type badges per row.
- `SettingsScreen` — Backend / Advisor / Profile signing / Updates sections.

**Modal**
- `RemovalPasswordModal` — 192-bit secret reveal with blur, copy-to-clipboard
  with "Copied" confirmation, Keychain-saved badge, second-storage warning,
  Install-on-iPhone CTA.

**Data**
- `MockData.swift` — `DisplayDevice`, `Pairing`, `PayloadOption`,
  `HistoryItem` types + curated mocks so the shell renders even without a
  connected device. Real backend `Device`s merge into the sidebar list when
  available.

**Backend wiring** — preserved end-to-end. Audit re-scan calls
`backend.quickAudit(udid:)` and updates `liveFindings`; absent a real device,
the UI runs the mock animation. JSON-RPC daemon lifecycle and Unix-socket
transport unchanged from V1.

**Removed** — `WizardView`, `DeviceListView` (sidebar), `ReportView` (right
pane), `RecommendationView`, `DiffSummary`, `SeverityBadge`, `FindingsList`
(old). Their responsibilities are absorbed by the route-based screens above.

**Verified** — `swiftc -typecheck` clean (warnings only on actor-hop awaits).
`scripts/build_app.sh` produces `iSpow.app` (~860 KB) that launches, spawns
the Python daemon, and renders the redesigned UI.

---

## 1.100 — 2026-05-03

**Added** — clickable `.app` distribution, no Xcode required.

- `scripts/build_app.sh` — one-shot build script. Compiles `Sources/iSpow/*.swift`
  directly with `swiftc` (bypassing the broken-on-CLT `swift package`), assembles
  a proper `.app` bundle layout (`Contents/MacOS`, `Contents/Resources`, `Info.plist`,
  `PkgInfo`), and ad-hoc codesigns so Gatekeeper allows it to launch.
- `BackendBridge.resolveBackendInvocation()` now auto-locates the backend in priority
  order: bundled PyInstaller binary → sibling `backend/.venv/bin/python` (the layout
  this repo ships) → `IPHONE_AUDIT_PYTHON` env override → `python3` from `PATH`.
  Walks up to 4 directory levels from the running `.app` to find the venv.

**How to build**

```bash
./scripts/build_app.sh
open iSpow.app
```

Verified: the produced `iSpow.app` launches, finds the venv automatically, spawns
`-m iphone_audit daemon`, and connects over the Unix socket — all from a double-click.

---

## 1.000 — 2026-05-03

Initial build from MVP spec (`.claude/02-mvp.md`) and technical overview (`.claude/01-technical-overview.md`).

**Added**
- Project skeleton: `backend/` (Python), `frontend/` (Swift Package), `scripts/`, `.claude/`.
- `VERSION`, `CHANGELOG.md`, `CLAUDE.md`, `README.md`.
- Python backend `iphone_audit` package with:
  - `extraction/` — lockdown, profiles, apps, crashes, backup (sync, pmd3 4.27.x).
  - `audit/` — rules orchestrator + stalkerware, profiles, pairing, gestalt, posture, entitlements checks.
  - `llm/` — Pydantic `HardeningRecommendation` schema + OpenAI advisor with rule-based fallback.
  - `hardening/` — deterministic `.mobileconfig` builder, payload allowlist, secret generation, install via pmd3 (with cfgutil fallback).
  - `report/` — before/after diff + JSON/HTML render.
  - `cli.py` — click-based CLI surface (list, quick-scan, advise, harden, verify, secret, pairing, init-signing-cert).
  - `daemon.py` — JSON-RPC server over Unix socket for the Swift app.
  - `data/stalkerware_bundles.json` — curated stalkerware bundle-ID DB.
  - `data/mobilegestalt_baselines/` — empty + seeding script + per-device README.
- Backend pytest suite covering audit logic, builder, diff, secret, stalkerware match.
- SwiftUI frontend as Swift Package executable target:
  - `iPhoneHardenApp` / `ContentView` three-pane.
  - `BackendBridge` Unix-socket JSON-RPC client (real implementation, no `fatalError`).
  - `WizardView` six-step flow (audit → advice → confirm → install → verify → done).
  - `DeviceListView`, `ReportView`, `FindingsList`, `RecommendationView`, `DiffSummary`, `SeverityBadge`.
- `.claude/state/` planning artifacts: `plan.md`, `decisions.md`, `todo.md`, `abbreviations.md`.

**Decisions of note** (full list in `.claude/state/decisions.md`)
- pymobiledevice3 pinned `>=4.27,<5` (sync API; 5.x+ async would require global rewrite).
- LLM default model `gpt-5` (env-overridable via `OPENAI_MODEL`); MVP's `gpt-5.5` is fictional.
- Frontend ships as Swift Package, not `.xcodeproj` (binary; not hand-writable).
- MobileGestalt audit gracefully degrades to INFO on iOS ≥ 17.4 (Apple removed the endpoint — affects all three target devices).
- Profile signing optional (self-signed adds no security for personal use).
- PyInstaller bundling deferred (backend invoked directly via `python -m iphone_audit`).
- Keychain ACL deferred to signed-app phase.

**Verified locally**
- Backend bytecode-compiles (`python -m compileall iphone_audit` exit 0).
- All 29 pytest tests green (synthetic-input fixtures, no device required).
- CLI imports and `--help` works on every subcommand.
- Daemon round-trip over Unix socket: `ping` and `list_devices` return well-formed JSON-RPC responses.
- Swift sources type-check via `swiftc -typecheck` against the macOS SDK (full `swift run` requires Xcode.app — see README).

**Out of scope for this version** (tracked in `.claude/state/todo.md` backlog)
- Sysdiagnose Triage mode (Mode C) — collection only, no YARA layer.
- Mac-as-gateway pf rules.
- WireGuard VPS provisioning.
- Supervised-mode setup wizard.
- iLEAPP HTML inline rendering.
- pmd3 9.x async upgrade.
