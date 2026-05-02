import SwiftUI

struct PairingsScreen: View {
    let device: DisplayDevice?
    @State var pairings: [Pairing] = Mock.pairings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                kpiStrip
                explainer
                hostsList
            }
            .padding(24)
        }
    }

    private var kpiStrip: some View {
        let totalEscrow = pairings.filter(\.escrow).count
        let stale = pairings.filter { $0.daysSilent > 90 }.count
        let untrusted = pairings.filter { !$0.trusted }.count

        return HStack(spacing: 16) {
            kpi("Hosts paired", "\(pairings.count)", color: Theme.fg)
            kpi("Escrow keybags", "\(totalEscrow)", color: Theme.sevMed)
            kpi("Silent > 90d", "\(stale)", color: Theme.sevLow)
            kpi("Untrusted", "\(untrusted)", color: Theme.sevHigh)
        }
    }

    private func kpi(_ label: String, _ value: String, color: Color) -> some View {
        Panel(padding: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Eyebrow(text: label)
                Text(value)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(color)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var explainer: some View {
        Panel(padding: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "key.fill")
                    .foregroundStyle(Theme.accent)
                    .font(.system(size: 16))
                VStack(alignment: .leading, spacing: 4) {
                    Text("What's an escrow keybag?")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.fg)
                    Text("Each Mac that has paired with this iPhone holds an escrow keybag — a credential that lets it perform silent encrypted backups any time the device is unlocked and connected. Revoking a pairing here purges the host's keybag and forces a fresh Trust handshake on next connection.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.fgMute)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var hostsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(text: "Paired hosts")
            VStack(spacing: 1) {
                ForEach(pairings) { p in
                    PairingRow(pairing: p) {
                        pairings.removeAll { $0.id == p.id }
                    }
                }
            }
            .background(Theme.bg2)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 0.5))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

struct PairingRow: View {
    let pairing: Pairing
    let onRevoke: () -> Void

    @State private var expanded = false

    var body: some View {
        VStack(spacing: 0) {
            Button { expanded.toggle() } label: {
                HStack(spacing: 14) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.fgDim)
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                        .frame(width: 14)

                    Image(systemName: "laptopcomputer")
                        .font(.system(size: 14))
                        .foregroundStyle(pairing.trusted ? Theme.accent : Theme.sevMed)
                        .frame(width: 18)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(pairing.host)
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundStyle(Theme.fg)
                        Text(pairing.model)
                            .font(.system(size: 11.5))
                            .foregroundStyle(Theme.fgDim)
                    }
                    Spacer(minLength: 12)
                    riskBadge
                    Text(pairing.lastSeen)
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(Theme.fgDim)
                        .frame(width: 120, alignment: .trailing)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            if expanded {
                expandedDetail
            }

            Rectangle().fill(Theme.line).frame(height: 0.5)
        }
    }

    private var riskBadge: some View {
        let color: Color = pairing.risk == .low ? Theme.accent
                         : pairing.risk == .medium ? Theme.sevMed : Theme.sevHigh
        return Text(pairing.risk.rawValue.uppercased())
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .tracking(1.0)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(color.opacity(0.14))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(color.opacity(0.35), lineWidth: 0.5))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    @ViewBuilder
    private var expandedDetail: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 32) {
                kvCol("User", pairing.user)
                kvCol("OS", pairing.osVersion)
                kvCol("First seen", pairing.firstSeen)
                kvCol("IP", pairing.ip)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Capabilities while paired")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .tracking(0.5)
                    .foregroundStyle(Theme.fgDim)
                capabilityRow("Initiate encrypted backups", granted: true)
                capabilityRow("Read installed apps + entitlements", granted: true)
                capabilityRow("Push configuration profiles", granted: true)
                capabilityRow("Read crash reports", granted: true)
                capabilityRow("Hold escrow keybag (silent backup)", granted: pairing.escrow)
            }

            HStack {
                Spacer()
                Btn(title: "Revoke pairing", variant: .danger, icon: "trash", action: onRevoke)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 18)
        .padding(.leading, 32)
    }

    private func kvCol(_ k: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(k.uppercased())
                .font(.system(size: 9.5, design: .monospaced))
                .tracking(0.6)
                .foregroundStyle(Theme.fgFaint)
            Text(v)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Theme.fg)
        }
    }

    private func capabilityRow(_ text: String, granted: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: granted ? "checkmark.circle.fill" : "minus.circle")
                .font(.system(size: 11))
                .foregroundStyle(granted ? Theme.sevMed : Theme.fgFaint)
            Text(text)
                .font(.system(size: 11.5))
                .foregroundStyle(granted ? Theme.fgMute : Theme.fgFaint)
        }
    }
}
