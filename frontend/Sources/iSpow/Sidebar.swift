import SwiftUI

enum Route: String, Hashable, CaseIterable {
    case audit, pairings, harden, verify, history, settings
}

struct SidebarView: View {
    @Binding var selectedDevice: DisplayDevice?
    @Binding var route: Route
    let devices: [DisplayDevice]

    var body: some View {
        VStack(spacing: 0) {
            titleBar
            brand
            sectionHeader("Devices · \(devices.count)", action: nil)

            if devices.isEmpty {
                emptyDeviceHint
            } else {
                VStack(spacing: 1) {
                    ForEach(devices) { d in
                        DeviceRow(device: d, selected: d.id == selectedDevice?.id) {
                            selectedDevice = d
                            route = .audit
                        }
                    }
                }
            }

            sectionHeader("Device", action: nil)
            navItems(deviceItems)

            sectionHeader("App", action: nil)
            navItems(appItems)

            Spacer()

            footerBadge
        }
        .frame(width: 232)
        .background(Theme.bg1)
        .overlay(
            Rectangle()
                .fill(Theme.line)
                .frame(width: 0.5),
            alignment: .trailing
        )
    }

    private var titleBar: some View {
        HStack(spacing: 12) {
            TrafficLights()
            Spacer()
        }
        .padding(.horizontal, 14)
        .frame(height: 42)
    }

    private var brand: some View {
        HStack(spacing: 8) {
            LogoView(size: 18)
            VStack(alignment: .leading, spacing: 0) {
                Text("iSpow")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Theme.fg)
                Text("v2.000 · build 1")
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(Theme.fgDim)
                    .tracking(0.5)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
    }

    private func sectionHeader(_ text: String, action: (() -> Void)?) -> some View {
        HStack {
            Text(text.uppercased())
                .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(Theme.fgDim)
            Spacer()
            if let action {
                Button(action: action) {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Theme.fgDim)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }

    private func navItems(_ items: [NavItemSpec]) -> some View {
        VStack(spacing: 1) {
            ForEach(items, id: \.route) { it in
                NavItem(item: it, active: route == it.route) {
                    route = it.route
                }
            }
        }
    }

    private var emptyDeviceHint: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "cable.connector")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.fgDim)
                Text("No devices")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.fgMute)
            }
            Text("Plug in an iPhone via USB, then tap “Trust This Computer” on the device.")
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.fgDim)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.02))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Theme.line, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal, 6)
    }

    private var footerBadge: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Theme.accent)
                .frame(width: 6, height: 6)
                .shadow(color: Theme.accent.opacity(0.6), radius: 4)
            Text("LLM mode · gpt-5")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Theme.fgDim)
            Spacer()
            Text("connected")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Theme.fgFaint)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .overlay(
            Rectangle().fill(Theme.line).frame(height: 0.5),
            alignment: .top
        )
    }

    private struct NavItemSpec {
        let route: Route
        let label: String
        let icon: String
    }

    private var deviceItems: [NavItemSpec] {
        [
            .init(route: .audit, label: "Audit", icon: "viewfinder"),
            .init(route: .pairings, label: "Pairings", icon: "link"),
            .init(route: .harden, label: "Hardening Profile", icon: "shippingbox"),
            .init(route: .verify, label: "Verify", icon: "checkmark.seal"),
        ]
    }

    private var appItems: [NavItemSpec] {
        [
            .init(route: .history, label: "History", icon: "clock"),
            .init(route: .settings, label: "Settings", icon: "gearshape"),
        ]
    }

    private struct NavItem: View {
        let item: NavItemSpec
        let active: Bool
        let onClick: () -> Void
        @State private var hover = false

        var body: some View {
            Button(action: onClick) {
                HStack(spacing: 9) {
                    Image(systemName: item.icon)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(active ? Theme.accent : Theme.fgDim)
                        .frame(width: 13)
                    Text(item.label)
                        .font(.system(size: 12.5, weight: active ? .medium : .regular))
                        .foregroundStyle(active ? Theme.fg : Theme.fgMute)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(active ? Color.white.opacity(0.06)
                            : hover ? Color.white.opacity(0.03) : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(.horizontal, 6)
            }
            .buttonStyle(.plain)
            .onHover { hover = $0 }
        }
    }
}

struct DeviceRow: View {
    let device: DisplayDevice
    let selected: Bool
    let onClick: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: onClick) {
            HStack(spacing: 10) {
                phoneGlyph
                VStack(alignment: .leading, spacing: 1) {
                    Text(device.name)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(Theme.fg)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    HStack(spacing: 6) {
                        Text(device.ios)
                        Text("·").foregroundStyle(Theme.fgFaint)
                        Text("\(device.findings) finding\(device.findings == 1 ? "" : "s")")
                    }
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(Theme.fgDim)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(selected ? Color.white.opacity(0.07)
                        : hover ? Color.white.opacity(0.03) : .clear)
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(selected ? Theme.line2 : .clear, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .padding(.horizontal, 6)
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }

    private var phoneGlyph: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(Theme.bg3)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Theme.line3, lineWidth: 0.5)
                )
                .frame(width: 22, height: 32)

            // notch
            Capsule()
                .fill(Theme.bg1)
                .frame(width: 8, height: 2)
                .offset(y: -13)

            // status dot
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
                .shadow(color: device.online ? statusColor.opacity(0.6) : .clear, radius: 3)
        }
        .frame(width: 22, height: 32)
    }

    private var statusColor: Color {
        guard device.online else { return Theme.fgFaint }
        switch device.posture {
        case .ok: return Theme.accent
        case .warn: return Theme.sevMed
        case .offline: return Theme.fgFaint
        }
    }
}
