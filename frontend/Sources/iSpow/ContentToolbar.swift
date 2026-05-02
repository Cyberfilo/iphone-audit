import SwiftUI

struct ContentToolbar: View {
    @EnvironmentObject var backend: BackendBridge
    @Binding var route: Route
    let device: DisplayDevice?
    var scanning: Bool
    var onScan: () -> Void
    var onInstall: () -> Void
    var onReverify: () -> Void
    var onToggleXml: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.fg)
                Text(subtitle)
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundStyle(Theme.fgDim)
            }
            Spacer()

            actions
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .frame(height: 60)
        .background(Theme.bg1)
        .overlay(
            Rectangle().fill(Theme.line).frame(height: 0.5),
            alignment: .bottom
        )
    }

    private var title: String {
        switch route {
        case .audit: return "Audit"
        case .pairings: return "Paired Macs"
        case .harden: return "Hardening Profile"
        case .verify: return "Verify"
        case .history: return "History"
        case .settings: return "Settings"
        }
    }

    private var subtitle: String {
        switch route {
        case .audit:
            if let d = device { return "\(d.model) · \(d.ios)" } else { return "" }
        case .pairings:
            if let d = device { return "\(d.paired) hosts have ever paired with this device" } else { return "" }
        case .harden:
            if let d = device { return "Profile target: \(d.model)" } else { return "" }
        case .verify:
            return "Re-run audit and diff against last result"
        case .history:
            return "All audits, installs and verifications across devices"
        case .settings:
            return "iSpow preferences"
        }
    }

    @ViewBuilder
    private var actions: some View {
        switch route {
        case .audit:
            if let d = device {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                    Text("last scan \(d.lastAudit)")
                        .font(.system(size: 10.5, design: .monospaced))
                }
                .foregroundStyle(Theme.fgDim)
                Btn(title: scanning ? "Scanning…" : "Re-scan",
                    variant: .ghost, icon: "arrow.clockwise",
                    disabled: scanning, action: onScan)
                Btn(title: "Harden device",
                    variant: .primary, icon: "shield.lefthalf.filled") {
                    route = .harden
                }
            }
        case .harden:
            Btn(title: "View raw", variant: .ghost, icon: "eye", action: onToggleXml)
            Btn(title: "Build & Install", variant: .primary, icon: "arrow.down.circle", action: onInstall)
        case .verify:
            Btn(title: "Re-run audit", variant: .primary, icon: "arrow.clockwise", action: onReverify)
        default:
            EmptyView()
        }
    }
}
