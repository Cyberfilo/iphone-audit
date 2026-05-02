import Foundation

// MARK: - UI-only types not produced by the backend yet
// (Pairings, Payloads, History live here. The backend exposes pairing_list
// already; payloads come out of HardeningRecommendation; history is local-only
// for now. We keep typed mocks so the design renders even with no device.)

struct Pairing: Identifiable, Hashable {
    let id: String
    let host: String
    let model: String
    let user: String
    let osVersion: String
    let firstSeen: String
    let lastSeen: String
    let daysSilent: Int
    let escrow: Bool
    let trusted: Bool
    let ip: String
    let risk: Risk

    enum Risk: String { case low, medium, high }
}

struct PayloadOption: Identifiable, Hashable {
    let id: String
    let title: String
    let blurb: String
    var enabled: Bool
    let impact: Impact
    let ref: String
    let addresses: [String]
    let locked: Bool

    enum Impact: String { case none, low, user, critical }
}

struct HistoryItem: Identifiable, Hashable {
    let id: String
    let when: String
    let device: String
    let type: EventType
    let summary: String

    enum EventType: String {
        case audit, install, verify, pairingRevoked = "pairing-revoked"
    }
}

// MARK: - Display device (sidebar enriched)

struct DisplayDevice: Identifiable, Hashable {
    let id: String
    let name: String
    let model: String
    let storage: String
    let color: String
    let ios: String
    let udid: String
    let serial: String
    let imei: String
    let battery: Int
    let lastAudit: String
    let posture: Posture
    let findings: Int
    let paired: Int
    let online: Bool

    enum Posture: String { case ok, warn, offline }
}

// MARK: - Mock data shipped with the app (matches data.jsx)

enum Mock {
    static let devices: [DisplayDevice] = [
        DisplayDevice(
            id: "iphone-16-pro",
            name: "Mireia's iPhone 16 Pro",
            model: "iPhone 16 Pro",
            storage: "256 GB",
            color: "Natural Titanium",
            ios: "iOS 18.4.1",
            udid: "00008140-001A4D8C0E80801C",
            serial: "F2LXC9P0Q1Y3",
            imei: "35 982384 729841 2",
            battery: 84,
            lastAudit: "2 minutes ago",
            posture: .ok,
            findings: 2,
            paired: 4,
            online: true
        ),
        DisplayDevice(
            id: "iphone-12-promax",
            name: "iPhone 12 Pro Max (kitchen)",
            model: "iPhone 12 Pro Max",
            storage: "512 GB",
            color: "Pacific Blue",
            ios: "iOS 17.6.1",
            udid: "00008101-000A2D1422B8003A",
            serial: "DNPCM9YJ0DPN",
            imei: "35 198327 482910 6",
            battery: 41,
            lastAudit: "yesterday, 22:41",
            posture: .warn,
            findings: 5,
            paired: 7,
            online: true
        ),
        DisplayDevice(
            id: "iphone-se",
            name: "Travel SE",
            model: "iPhone SE (3rd gen)",
            storage: "128 GB",
            color: "Midnight",
            ios: "iOS 18.3.2",
            udid: "00008110-001E5C7C0CB8401E",
            serial: "G6TZK1XPLN9C",
            imei: "35 882915 003948 1",
            battery: 0,
            lastAudit: "3 days ago",
            posture: .offline,
            findings: 0,
            paired: 2,
            online: false
        ),
    ]

    static let findings: [Finding] = [
        f("f-passcode", .info, "Posture",
          "Passcode is set and alphanumeric",
          "10 chars · auto-erase after 10 attempts · lock after 5 minutes",
          "Device passcode policy meets recommended baseline. Auto-erase is enabled. Consider tightening lock-after to 2 minutes."),
        f("f-backup-enc", .info, "Posture",
          "Encrypted backups enforced",
          "WillEncrypt = true. Finder will refuse unencrypted backups.",
          "An encrypted-backup policy is in effect. Any local Finder/iTunes backup created from a paired Mac will be encrypted at rest using the user's backup password."),
        f("f-pairings", .medium, "Pairings",
          "4 paired Macs hold escrow keys",
          "Two haven't checked in for >180 days. Silent backup possible while phone is unlocked.",
          "Four host computers have an active pairing record with this device, of which all four hold an escrow keybag. An escrow keybag allows the host to perform silent encrypted backups whenever the device is unlocked and connected, without further user prompt."),
        f("f-lockscreen-cc", .low, "Restrictions",
          "Control Center accessible from lock screen",
          "An attacker with brief physical access can toggle Wi-Fi / Airplane mode without unlocking.",
          "Control Center is currently reachable on the locked device. This allows toggling radios, flashlight and media controls without authentication. Recommended: disable in Settings → Face ID & Passcode, or enforce via Restrictions payload."),
        f("f-airdrop", .low, "Restrictions",
          "AirDrop set to 'Everyone for 10 Minutes'",
          "Currently discoverable. Will auto-revert to Contacts Only.",
          "AirDrop discovery is temporarily set to Everyone. iOS will revert this to Contacts Only automatically. The hardening profile can pin this to Contacts Only or Off."),
        f("f-profiles", .info, "Profiles",
          "No unknown configuration profiles installed",
          "0 MDM · 0 root CAs · 0 VPN · 0 unsigned",
          "Scanned /Library/ConfigurationProfiles. No third-party MDM, no custom root certificates, no VPN payloads, no unsigned profiles. Device is not supervised."),
        f("f-stalkerware", .info, "Apps",
          "No known stalkerware bundle-IDs detected",
          "Cross-checked 1,284 known IDs · last list update: 2026-04-29",
          "App inventory checked against the public stalkerware bundle-ID list (mSpy, FlexiSPY, Cocospy, Hoverwatch, XNSPY, …). No matches."),
        f("f-entitlements", .low, "Apps",
          "1 app has always-on location + background fetch",
          "RouteRunner (com.routerunner.ios) — installed 14 days ago",
          "RouteRunner declares com.apple.developer.location.always entitlement and is registered for background fetch. This combination is consistent with fitness/navigation apps but worth confirming."),
        f("f-mg", .info, "Integrity",
          "MobileGestalt integrity check unavailable",
          "iOS ≥ 17.4 — Apple removed the endpoint. Informational only.",
          "The SparseRestore tampering heuristic relies on MobileGestalt cache integrity, which is no longer accessible on iOS 17.4+. This finding is emitted as informational; absence of evidence is not evidence of absence."),
        f("f-lockdown", .info, "Posture",
          "Lockdown Mode is OFF",
          "Recommended for high-risk users (journalists, activists, executives).",
          "Lockdown Mode disables several attack surfaces (JIT, complex web fonts, FaceTime invites from unknown numbers, wired accessory connections while locked). Not enabled on this device — appropriate for most users, but available if your threat model warrants it."),
    ]

    static let pairings: [Pairing] = [
        Pairing(id: "p-1", host: "studio-mbp.local", model: "MacBook Pro 16″ (M3 Max)",
                user: "mireia", osVersion: "macOS 14.6.1",
                firstSeen: "2024-09-12", lastSeen: "2 hours ago",
                daysSilent: 0, escrow: true, trusted: true, ip: "10.0.1.42", risk: .low),
        Pairing(id: "p-2", host: "kitchen-imac.local", model: "iMac 24″ (M1)",
                user: "household", osVersion: "macOS 13.7",
                firstSeen: "2023-02-04", lastSeen: "yesterday, 19:08",
                daysSilent: 0, escrow: true, trusted: true, ip: "10.0.1.18", risk: .low),
        Pairing(id: "p-3", host: "old-air-2019", model: "MacBook Air 13″ (2019)",
                user: "—", osVersion: "macOS 12.7.4",
                firstSeen: "2021-08-30", lastSeen: "214 days ago",
                daysSilent: 214, escrow: true, trusted: false, ip: "—", risk: .medium),
        Pairing(id: "p-4", host: "DESKTOP-3KQ19R", model: "Unknown host (Windows iTunes)",
                user: "—", osVersion: "Windows · iTunes 12.12",
                firstSeen: "2022-06-11", lastSeen: "501 days ago",
                daysSilent: 501, escrow: true, trusted: false, ip: "—", risk: .medium),
    ]

    static let payloads: [PayloadOption] = [
        PayloadOption(id: "pl-passcode", title: "Tighten passcode policy",
                      blurb: "Force ≥8 alphanumeric, lock after 2 min, auto-erase after 10 attempts.",
                      enabled: true, impact: .user,
                      ref: "com.apple.mobiledevice.passwordpolicy",
                      addresses: ["f-passcode"], locked: false),
        PayloadOption(id: "pl-restrict-lockscreen", title: "Lock down the lock screen",
                      blurb: "Disable Control Center, notifications, Today view and Wallet from the lock screen.",
                      enabled: true, impact: .low,
                      ref: "com.apple.applicationaccess",
                      addresses: ["f-lockscreen-cc"], locked: false),
        PayloadOption(id: "pl-airdrop", title: "AirDrop → Contacts Only",
                      blurb: "Pin AirDrop to Contacts Only and disable on lock screen.",
                      enabled: true, impact: .low,
                      ref: "com.apple.applicationaccess",
                      addresses: ["f-airdrop"], locked: false),
        PayloadOption(id: "pl-backup-enc", title: "Force encrypted backups",
                      blurb: "Refuse unencrypted local backups (already on — kept for drift detection).",
                      enabled: true, impact: .none,
                      ref: "com.apple.backup",
                      addresses: ["f-backup-enc"], locked: false),
        PayloadOption(id: "pl-ads", title: "Disable ad tracking & diagnostic submission",
                      blurb: "Turn off personalized ads, app tracking, and diagnostic data sharing with Apple.",
                      enabled: true, impact: .none,
                      ref: "com.apple.applicationaccess",
                      addresses: [], locked: false),
        PayloadOption(id: "pl-keychain", title: "Block iCloud Keychain sync",
                      blurb: "Prevent automatic sync of saved passwords through iCloud.",
                      enabled: false, impact: .user,
                      ref: "com.apple.applicationaccess",
                      addresses: [], locked: false),
        PayloadOption(id: "pl-enterprise", title: "Disallow enterprise app trust",
                      blurb: "Block manual trust of enterprise/non-App Store developers.",
                      enabled: true, impact: .low,
                      ref: "com.apple.applicationaccess",
                      addresses: [], locked: false),
        PayloadOption(id: "pl-anonymous", title: "Anonymous lockdown — silence Apple endpoints",
                      blurb: "Disable every Apple endpoint that still phones home without an Apple ID: Siri/dictation server logging, Spotlight web suggestions, ad personalization, all iCloud sync surfaces, Game Center, Find My, Safari autofill telemetry. Auto-enabled when no Apple ID is detected.",
                      enabled: false, impact: .user,
                      ref: "com.apple.applicationaccess",
                      addresses: ["posture.no_apple_id"], locked: false),
        PayloadOption(id: "pl-removal", title: "Removal password",
                      blurb: "192-bit secret. Required to remove the profile via Settings → General → VPN & Device Management.",
                      enabled: true, impact: .critical,
                      ref: "PayloadRemovalDisallowed + RemovalPassword",
                      addresses: [], locked: true),
    ]

    static let history: [HistoryItem] = [
        HistoryItem(id: "h-1", when: "May 3, 09:14", device: "iPhone 16 Pro",
                    type: .audit, summary: "Quick scan · 10 findings (0 high · 1 medium)"),
        HistoryItem(id: "h-2", when: "May 1, 18:02", device: "iPhone 12 Pro Max",
                    type: .verify, summary: "Profile applied. Resolved 4 of 5 findings."),
        HistoryItem(id: "h-3", when: "May 1, 17:58", device: "iPhone 12 Pro Max",
                    type: .install, summary: "iSpow Hardening v2026.04 installed (sig: 9f3a…c1)"),
        HistoryItem(id: "h-4", when: "May 1, 17:51", device: "iPhone 12 Pro Max",
                    type: .audit, summary: "Deep scan · 19 findings (1 high · 3 medium)"),
        HistoryItem(id: "h-5", when: "Apr 30, 11:20", device: "iPhone 16 Pro",
                    type: .pairingRevoked, summary: "Removed pairing: old-air-2019 (escrow purged)"),
        HistoryItem(id: "h-6", when: "Apr 28, 08:45", device: "Travel SE",
                    type: .audit, summary: "Quick scan · 7 findings (0 high · 0 medium)"),
    ]

    static let sampleXML = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>PayloadDisplayName</key>
      <string>iSpow Hardening — Mireia's iPhone 16 Pro</string>
      <key>PayloadIdentifier</key>
      <string>com.ispow.harden.001A4D8C0E80801C</string>
      <key>PayloadType</key>
      <string>Configuration</string>
      <key>PayloadUUID</key>
      <string>3F2A91C7-4E0B-4B2C-9E11-7C9D2A5E8B14</string>
      <key>PayloadVersion</key>
      <integer>1</integer>
      <key>PayloadRemovalDisallowed</key>
      <false/>
      <key>RemovalPassword</key>
      <string>***-redacted-stored-in-keychain***</string>
      <key>PayloadContent</key>
      <array>
        <dict>
          <key>PayloadType</key>
          <string>com.apple.applicationaccess</string>
          <key>allowLockScreenControlCenter</key>
          <false/>
          <key>allowLockScreenNotificationsView</key>
          <false/>
          <key>allowEnterpriseAppTrust</key>
          <false/>
          <key>allowAdTracking</key>
          <false/>
          <key>forceAirDropUnmanaged</key>
          <true/>
        </dict>
        <dict>
          <key>PayloadType</key>
          <string>com.apple.mobiledevice.passwordpolicy</string>
          <key>requireAlphanumeric</key>
          <true/>
          <key>minLength</key>
          <integer>8</integer>
          <key>maxFailedAttempts</key>
          <integer>10</integer>
          <key>maxInactivity</key>
          <integer>2</integer>
        </dict>
      </array>
    </dict>
    </plist>
    """

    private static func f(_ id: String, _ sev: Severity, _ cat: String,
                          _ title: String, _ short: String, _ detail: String) -> Finding {
        Finding(
            id: id, severity: sev, category: categoryFor(cat),
            title: title, description: detail, evidence: nil,
            suggestedPayloads: []
        )
    }

    private static func categoryFor(_ raw: String) -> FindingCategory {
        switch raw.lowercased() {
        case "posture": return .posture
        case "profiles", "pairings", "integrity": return .priorCompromise
        case "restrictions": return .privacyLeak
        case "apps": return .privacyLeak
        default: return .informational
        }
    }
}

// Friendly raw-category accessor (the design groups by free-form category strings,
// but our backend Finding stores a strict enum; for the UI we re-derive a pretty
// label from the prefix of the finding's id — falling back to the category enum.)
extension Finding {
    var prettyCategory: String {
        if id.hasPrefix("f-passcode") || id.hasPrefix("f-backup")
            || id.hasPrefix("f-lockdown") || id.hasPrefix("posture") {
            return "Posture"
        }
        if id.hasPrefix("f-pairings") || id.hasPrefix("pairing") {
            return "Pairings"
        }
        if id.hasPrefix("f-lockscreen") || id.hasPrefix("f-airdrop") {
            return "Restrictions"
        }
        if id.hasPrefix("f-profiles") || id.hasPrefix("profile.") {
            return "Profiles"
        }
        if id.hasPrefix("f-stalkerware") || id.hasPrefix("stalkerware")
            || id.hasPrefix("f-entitlements") || id.hasPrefix("entitlement") {
            return "Apps"
        }
        if id.hasPrefix("f-mg") || id.hasPrefix("gestalt") {
            return "Integrity"
        }
        switch category {
        case .priorCompromise: return "Profiles"
        case .posture: return "Posture"
        case .privacyLeak: return "Restrictions"
        case .network: return "Network"
        case .physical: return "Physical"
        case .informational: return "Info"
        }
    }
}
