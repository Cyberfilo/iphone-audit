import SwiftUI

// MARK: - History

struct HistoryScreen: View {
    let items: [HistoryItem]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 1) {
                ForEach(items) { item in
                    HistoryRow(item: item)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

struct HistoryRow: View {
    let item: HistoryItem

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            iconBadge
            VStack(alignment: .leading, spacing: 2) {
                Text(item.summary)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.fg)
                HStack(spacing: 8) {
                    Text(item.device)
                    Text("·").foregroundStyle(Theme.fgFaint)
                    Text(item.when)
                }
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(Theme.fgDim)
            }
            Spacer()
            Text(item.type.rawValue.uppercased())
                .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                .tracking(1.0)
                .foregroundStyle(typeColor.opacity(0.85))
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(typeColor.opacity(0.10))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(typeColor.opacity(0.3), lineWidth: 0.5))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .overlay(Rectangle().fill(Theme.line).frame(height: 0.5), alignment: .bottom)
    }

    private var iconBadge: some View {
        ZStack {
            Circle()
                .fill(typeColor.opacity(0.12))
            Image(systemName: typeIcon)
                .font(.system(size: 12))
                .foregroundStyle(typeColor)
        }
        .frame(width: 28, height: 28)
        .overlay(Circle().stroke(typeColor.opacity(0.3), lineWidth: 0.5))
    }

    private var typeIcon: String {
        switch item.type {
        case .audit: return "viewfinder"
        case .install: return "shippingbox"
        case .verify: return "checkmark.seal"
        case .pairingRevoked: return "trash"
        }
    }

    private var typeColor: Color {
        switch item.type {
        case .audit: return Theme.accent
        case .install: return Theme.fgMute
        case .verify: return Theme.accent
        case .pairingRevoked: return Theme.sevMed
        }
    }
}

// MARK: - Settings

struct SettingsScreen: View {
    @AppStorage("ispow.useLLM") private var useLLM: Bool = false
    @AppStorage("ispow.openaiModel") private var model: String = "gpt-5"
    @AppStorage("ispow.signProfiles") private var signProfiles: Bool = false
    @AppStorage("ispow.checkUpdates") private var checkUpdates: Bool = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                section("Backend") {
                    keyVal("Daemon socket", "/tmp/iphone-audit.sock")
                    keyVal("Backend version", "1.000")
                    keyVal("pymobiledevice3", "4.27.x (sync)")
                }
                section("Advisor") {
                    Toggle(isOn: $useLLM) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Use LLM advisor")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Theme.fg)
                            Text("Requires OPENAI_API_KEY in your environment.")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.fgMute)
                        }
                    }
                    .toggleStyle(.switch)
                    .tint(Theme.accent)

                    HStack(spacing: 10) {
                        Text("Model")
                            .font(.system(size: 12.5, design: .monospaced))
                            .foregroundStyle(Theme.fgDim)
                        TextField("gpt-5", text: $model)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 240)
                    }
                }
                section("Profile signing") {
                    Toggle(isOn: $signProfiles) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sign profiles with self-signed CA")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Theme.fg)
                            Text("Adds a green \"Verified\" badge in iOS Settings — no security difference for personal use.")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.fgMute)
                        }
                    }
                    .toggleStyle(.switch)
                    .tint(Theme.accent)
                }
                section("Updates") {
                    Toggle(isOn: $checkUpdates) {
                        Text("Check for updates on launch")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.fg)
                    }
                    .toggleStyle(.switch)
                    .tint(Theme.accent)
                    HStack {
                        Btn(title: "Check for updates", variant: .ghost, icon: "arrow.down.circle") {}
                        Btn(title: "Replace signing key", variant: .ghost, icon: "key") {}
                        Spacer()
                    }
                }
            }
            .padding(24)
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder _ content: @escaping () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: title)
            Panel(padding: 16) {
                VStack(alignment: .leading, spacing: 14) {
                    content()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func keyVal(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Theme.fgDim)
            Spacer()
            Text(v)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Theme.fg)
        }
    }
}
