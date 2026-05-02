import SwiftUI

struct HardenScreen: View {
    let device: DisplayDevice?
    @Binding var payloads: [PayloadOption]
    let showXml: Bool
    let onInstall: () -> Void

    var body: some View {
        HSplitView {
            mainColumn
            sidebar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var mainColumn: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                appleNotice
                if showXml {
                    xmlPreview
                } else {
                    payloadList
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Theme.bg1)
    }

    private var appleNotice: some View {
        Panel(padding: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Theme.sevLow)
                VStack(alignment: .leading, spacing: 4) {
                    Text("How iOS will display this")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Theme.fg)
                    Text("Settings will show an \"Unverified\" warning before install — this is expected for self-signed profiles. Tap Install, then enter the device passcode. The removal password generated below is required to take the profile off via Settings.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.fgMute)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var payloadList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: "Payloads · \(payloads.filter(\.enabled).count) of \(payloads.count) enabled")
            VStack(spacing: 1) {
                ForEach($payloads) { $p in
                    PayloadRow(payload: $p)
                }
            }
            .background(Theme.bg2)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 0.5))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private var xmlPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Eyebrow(text: "Raw .mobileconfig (signed)")
                Spacer()
                Btn(title: "Copy", variant: .subtle, icon: "doc.on.doc") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(Mock.sampleXML, forType: .string)
                }
            }
            ScrollView {
                Text(Mock.sampleXML)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Theme.fgMute)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .textSelection(.enabled)
            }
            .background(Color(hex: 0x08090C))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line2, lineWidth: 0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .frame(maxHeight: 480)
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow(text: "Profile target")
            if let d = device {
                Panel(padding: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(d.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.fg)
                        VStack(alignment: .leading, spacing: 3) {
                            metaRow("Model", d.model)
                            metaRow("UDID", d.udid)
                            metaRow("iOS", d.ios)
                        }
                    }
                }
            }
            Eyebrow(text: "Profile metadata")
            Panel(padding: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    metaRow("Identifier", "com.ispow.harden")
                    metaRow("Version", "1")
                    metaRow("Signed by", "iSpow Self-Signed CA")
                    metaRow("Removal", "Password required")
                }
            }
            Spacer()
        }
        .padding(20)
        .frame(width: 320)
        .background(Theme.bg1)
        .overlay(
            Rectangle().fill(Theme.line).frame(width: 0.5),
            alignment: .leading
        )
    }

    private func metaRow(_ k: String, _ v: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(k)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(Theme.fgDim)
                .frame(width: 80, alignment: .leading)
            Text(v)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(Theme.fg)
                .textSelection(.enabled)
        }
    }
}

// MARK: - Payload row with toggle

struct PayloadRow: View {
    @Binding var payload: PayloadOption

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            toggleControl

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(payload.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.fg)
                    if payload.locked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.fgDim)
                    }
                    impactPill
                }
                Text(payload.blurb)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.fgMute)
                    .fixedSize(horizontal: false, vertical: true)
                Text(payload.ref)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Theme.fgFaint)
            }
            Spacer(minLength: 12)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(payload.enabled ? Color.white.opacity(0.015) : .clear)
        .overlay(
            Rectangle().fill(Theme.line).frame(height: 0.5),
            alignment: .bottom
        )
    }

    private var toggleControl: some View {
        Button {
            if !payload.locked { payload.enabled.toggle() }
        } label: {
            ZStack(alignment: payload.enabled ? .trailing : .leading) {
                Capsule()
                    .fill(payload.enabled ? Theme.accent : Theme.bg4)
                    .frame(width: 32, height: 18)
                Circle()
                    .fill(.white)
                    .frame(width: 14, height: 14)
                    .padding(2)
                    .shadow(color: .black.opacity(0.4), radius: 1)
            }
            .opacity(payload.locked ? 0.6 : 1)
        }
        .buttonStyle(.plain)
        .padding(.top, 2)
    }

    private var impactPill: some View {
        let (text, color): (String, Color) = {
            switch payload.impact {
            case .none: return ("NO IMPACT", Theme.fgFaint)
            case .low: return ("LOW IMPACT", Theme.sevInfo)
            case .user: return ("USER IMPACT", Theme.sevLow)
            case .critical: return ("REQUIRED", Theme.accent)
            }
        }()
        return Text(text)
            .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
            .tracking(1.0)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(color.opacity(0.12))
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(color.opacity(0.3), lineWidth: 0.5))
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}
