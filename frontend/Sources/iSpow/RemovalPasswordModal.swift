import SwiftUI

struct RemovalPasswordModal: View {
    @Binding var isPresented: Bool
    let device: DisplayDevice?
    let password: String
    var archivePath: String? = nil
    var onProceed: () -> Void

    @State private var revealed = true
    @State private var copied = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .background(VibrancyView(material: .hudWindow, blending: .withinWindow))
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }

            modal
                .frame(width: 520)
        }
    }

    private var modal: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            body_
            actions
        }
        .background(Theme.bg2)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line3, lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.6), radius: 30, y: 10)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .foregroundStyle(Theme.accent)
                    .font(.system(size: 16))
                Text("Save your removal password")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.fg)
            }
            Text("We'll only show this once. Without it, the profile cannot be removed via Settings — only by a full DFU restore.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.fgMute)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Theme.accent.opacity(0.10), Theme.bg2],
                startPoint: .top, endPoint: .bottom
            )
        )
        .overlay(Rectangle().fill(Theme.line).frame(height: 0.5), alignment: .bottom)
    }

    private var body_: some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow(text: "Removal password · 192-bit")

            Text(password)
                .font(.system(size: 14, design: .monospaced))
                .tracking(0.4)
                .foregroundStyle(Theme.fg)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(hex: 0x08090C))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line2, lineWidth: 0.5))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .blur(radius: revealed ? 0 : 6)
                .modifier(ConditionalSelection(enabled: revealed))

            HStack(spacing: 8) {
                Btn(title: copied ? "Copied to clipboard" : "Copy password",
                    variant: .ghost, icon: "doc.on.doc") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(password, forType: .string)
                    copied = true
                    Task {
                        try? await Task.sleep(nanoseconds: 1_400_000_000)
                        copied = false
                    }
                }
                Btn(title: revealed ? "Hide" : "Reveal",
                    variant: .ghost, icon: "eye") {
                    revealed.toggle()
                }
            }

            keychainBadge
            if let archivePath, !archivePath.isEmpty {
                profileSavedRow(path: archivePath)
            }
            secondStorageWarning
        }
        .padding(24)
    }

    private func profileSavedRow(path: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "doc.fill")
                .foregroundStyle(Theme.accent)
                .font(.system(size: 12))
            VStack(alignment: .leading, spacing: 2) {
                Text(".mobileconfig saved to disk")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Theme.fg)
                Text(path)
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(Theme.fgDim)
                    .textSelection(.enabled)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 8)
            Btn(title: "Reveal", variant: .ghost, icon: "folder") {
                let url = URL(fileURLWithPath: path)
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.accent.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.accentLine, lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var keychainBadge: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Theme.accent)
                .font(.system(size: 12))
            VStack(alignment: .leading, spacing: 2) {
                Text("Saved to your login Keychain")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Theme.fg)
                Text("kind: generic password · account: iPhoneHarden-\(device?.udid.suffix(12) ?? "")")
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(Theme.fgDim)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.accent.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.accentLine, lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var secondStorageWarning: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Theme.sevLow)
                .font(.system(size: 11))
            Text("Also paste this into 1Password / Bitwarden — Keychain is convenient but not eternal. A drive loss without backup means a forced DFU restore.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.fgMute)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.sevLow.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.sevLow.opacity(0.3), lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var actions: some View {
        HStack(spacing: 8) {
            Spacer()
            Btn(title: "Cancel", variant: .ghost) { isPresented = false }
            Btn(title: "I saved it · Install on iPhone",
                variant: .primary, icon: "arrow.down.circle") {
                isPresented = false
                onProceed()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Theme.bg1)
        .overlay(Rectangle().fill(Theme.line).frame(height: 0.5), alignment: .top)
    }
}

private struct ConditionalSelection: ViewModifier {
    let enabled: Bool
    func body(content: Content) -> some View {
        if enabled {
            content.textSelection(.enabled)
        } else {
            content.textSelection(.disabled)
        }
    }
}
