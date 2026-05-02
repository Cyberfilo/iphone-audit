import SwiftUI

struct VerifyScreen: View {
    let device: DisplayDevice?
    let before: [Finding]
    let after: [Finding]
    let phase: Phase
    let onReverify: () -> Void

    enum Phase { case installing, done }

    var body: some View {
        if phase == .installing {
            InstallCeremony()
        } else {
            VStack(spacing: 0) {
                summary
                diffList
            }
        }
    }

    private var summary: some View {
        let resolved = before.count - after.count
        let unchanged = after.filter { a in before.contains(where: { $0.id == a.id && $0.severity == a.severity }) }.count
        let new = 0

        return HStack(spacing: 0) {
            cell("Resolved", "\(resolved)", color: Theme.accent)
            divider
            cell("Unchanged", "\(unchanged)", color: Theme.fgMute)
            divider
            cell("New", "\(new)", color: Theme.fgMute)
            divider
            cell("Posture +", "+18", color: Theme.accent)
        }
        .overlay(Rectangle().fill(Theme.line).frame(height: 0.5), alignment: .bottom)
    }

    private func cell(_ label: String, _ value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Eyebrow(text: label)
            Text(value)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private var divider: some View {
        Rectangle().fill(Theme.line).frame(width: 0.5)
    }

    private var diffList: some View {
        ScrollView {
            VStack(spacing: 0) {
                HStack {
                    Eyebrow(text: "Diff vs. previous audit · \(before.count) → \(after.count) findings")
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 6)

                ForEach(before) { b in
                    let a = after.first(where: { $0.id == b.id })
                    let status: DiffStatus = a == nil
                        ? .resolved
                        : a!.severity == b.severity ? .unchanged : .changed
                    DiffRow(finding: b, status: status)
                }
            }
        }
    }

    enum DiffStatus { case resolved, unchanged, changed }
}

private struct DiffRow: View {
    let finding: Finding
    let status: VerifyScreen.DiffStatus

    var body: some View {
        let color: Color = {
            switch status {
            case .resolved: return Theme.accent
            case .changed: return Theme.sevLow
            case .unchanged: return Theme.fgFaint
            }
        }()
        let glyph: String = {
            switch status {
            case .resolved: return "−"
            case .changed: return "↻"
            case .unchanged: return "·"
            }
        }()

        HStack(spacing: 12) {
            Text(glyph)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(color)
                .frame(width: 20, alignment: .center)
            SeverityPill(severity: finding.severity)
                .frame(width: 76, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(finding.title)
                    .font(.system(size: 12.5))
                    .strikethrough(status == .resolved, color: Theme.fgFaint)
                    .foregroundStyle(status == .resolved ? Theme.fgMute : Theme.fg)
                Text(finding.description)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.fgDim)
                    .lineLimit(1)
            }
            Spacer(minLength: 12)
            Text(statusLabel)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(0.6)
                .foregroundStyle(color)
                .frame(width: 100, alignment: .trailing)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .opacity(status == .unchanged ? 0.55 : 1)
        .overlay(Rectangle().fill(Theme.line).frame(height: 0.5), alignment: .bottom)
    }

    private var statusLabel: String {
        switch status {
        case .resolved: return "RESOLVED"
        case .changed: return "CHANGED"
        case .unchanged: return "UNCHANGED"
        }
    }
}

// MARK: - Install ceremony

struct InstallCeremony: View {
    @State private var step = 0
    private let steps = [
        "Generating .mobileconfig",
        "Signing with iSpow CA",
        "Pushing to device via lockdownd",
        "Awaiting on-device confirmation",
        "Profile installed",
        "Re-running audit…",
    ]

    var body: some View {
        HStack(spacing: 32) {
            phoneMock
            VStack(alignment: .leading, spacing: 14) {
                Eyebrow(text: "Install ceremony")
                Text(currentStep)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.fg)
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { idx, s in
                        HStack(spacing: 8) {
                            Image(systemName: idx <= step ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(idx <= step ? Theme.accent : Theme.fgFaint)
                                .font(.system(size: 12))
                            Text(s)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(idx <= step ? Theme.fg : Theme.fgDim)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg1)
        .task {
            for i in 0..<steps.count {
                try? await Task.sleep(nanoseconds: 700_000_000)
                step = i
            }
        }
    }

    private var currentStep: String {
        steps[min(step, steps.count - 1)]
    }

    private var phoneMock: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(hex: 0xFAFAFA))
                    .frame(width: 184, height: 384)

                Capsule()
                    .fill(Color.black)
                    .frame(width: 60, height: 16)
                    .padding(.top, 10)

                VStack(spacing: 8) {
                    Spacer().frame(height: 36)
                    Text("Install Profile")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x666666))
                    Text("iSpow Hardening")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.black)
                    Rectangle().fill(Color(hex: 0xE0E0E0)).frame(height: 0.5)
                        .padding(.horizontal, 12)
                    HStack {
                        Text("Signed by")
                        Spacer()
                        Text("iSpow CA")
                            .foregroundStyle(Color(hex: 0x007AFF))
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(Color(hex: 0x666666))
                    .padding(.horizontal, 12)
                    Spacer()
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: 0x007AFF))
                        .frame(height: 32)
                        .overlay(Text("Install").foregroundStyle(.white).font(.system(size: 12, weight: .semibold)))
                        .padding(.horizontal, 12)
                        .padding(.bottom, 12)
                }
            }
            .frame(width: 200, height: 400)
        }
        .padding(8)
        .background(LinearGradient(
            colors: [Color(hex: 0x1C2128), Color(hex: 0x0D1014)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        ))
        .overlay(RoundedRectangle(cornerRadius: 32).stroke(Theme.line3, lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 32))
    }
}
