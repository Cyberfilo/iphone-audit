import SwiftUI

struct AuditScreen: View {
    let device: DisplayDevice?
    let findings: [Finding]
    let scanning: Bool
    let onGoto: (Route) -> Void

    @State private var sevFilter: Severity? = nil
    @State private var catFilter: String = "All"
    @State private var query: String = ""
    @State private var expanded = Set<String>(["f-pairings"])

    var body: some View {
        if scanning {
            ScanningOverlay(deviceName: device?.name ?? "device")
        } else {
            VStack(spacing: 0) {
                if let d = device {
                    DeviceHero(device: d, findings: findings)
                }
                FilterBar(
                    findings: findings,
                    sev: $sevFilter,
                    cat: $catFilter,
                    query: $query
                )
                findingsList
            }
        }
    }

    private var filtered: [Finding] {
        findings.filter { f in
            if let s = sevFilter, f.severity != s { return false }
            if catFilter != "All", f.prettyCategory != catFilter { return false }
            if !query.isEmpty {
                let hay = "\(f.title) \(f.description) \(f.prettyCategory)".lowercased()
                if !hay.contains(query.lowercased()) { return false }
            }
            return true
        }
    }

    @ViewBuilder
    private var findingsList: some View {
        ScrollView {
            VStack(spacing: 0) {
                if filtered.isEmpty {
                    Text("No findings match these filters.")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.fgDim)
                        .frame(maxWidth: .infinity)
                        .padding(60)
                } else {
                    ForEach(filtered) { f in
                        FindingRow(
                            finding: f,
                            expanded: expanded.contains(f.id),
                            onToggle: { toggle(f.id) },
                            onGoto: onGoto
                        )
                    }
                }
                HStack {
                    Text("\(filtered.count) of \(findings.count) findings")
                    Spacer()
                    Text("scan completed in 58.4s · audit-id 7f3c91e2")
                }
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(Theme.fgFaint)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
        }
    }

    private func toggle(_ id: String) {
        if expanded.contains(id) { expanded.remove(id) } else { expanded.insert(id) }
    }
}

// MARK: - Device hero (identity + posture)

struct DeviceHero: View {
    let device: DisplayDevice
    let findings: [Finding]

    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            phoneCard
            identity
            scoreCard
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(
            LinearGradient(
                colors: [Theme.bg2, Theme.bg1],
                startPoint: .top, endPoint: .bottom
            )
        )
        .overlay(Rectangle().fill(Theme.line).frame(height: 0.5), alignment: .bottom)
    }

    private var phoneCard: some View {
        VStack(spacing: 0) {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: 0x1C2128), Color(hex: 0x0D1014)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                RoundedRectangle(cornerRadius: 9)
                    .fill(Theme.bg1)
                    .padding(5)
                    .overlay(
                        VStack(spacing: 6) {
                            LogoView(size: 32)
                            Text("iSpow · linked")
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundStyle(Theme.fgDim)
                        }
                    )
                Capsule()
                    .fill(Color.black)
                    .frame(width: 28, height: 8)
                    .offset(y: -68)
            }
            .frame(width: 88, height: 168)
            .overlay(
                RoundedRectangle(cornerRadius: 14).stroke(Theme.line3, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(device.name)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.fg)
            HStack(spacing: 8) {
                Text(device.model)
                Text("·").foregroundStyle(Theme.fgFaint)
                Text(device.storage)
                Text("·").foregroundStyle(Theme.fgFaint)
                Text(device.color)
            }
            .font(.system(size: 12))
            .foregroundStyle(Theme.fgDim)
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                identityRow("UDID", device.udid)
                identityRow("Serial", device.serial)
                identityRow("IMEI", device.imei)
                identityRow("iOS", device.ios)
            }
            .padding(.top, 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func identityRow(_ key: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(key)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Theme.fgDim)
                .frame(width: 50, alignment: .leading)
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Theme.fg)
                .textSelection(.enabled)
        }
    }

    // posture score panel
    private var scoreCard: some View {
        let counts: [Severity: Int] = Dictionary(grouping: findings, by: \.severity).mapValues(\.count)
        let critPenalty: Int = (counts[.critical] ?? 0) * 25
        let highPenalty: Int = (counts[.high] ?? 0) * 12
        let medPenalty: Int = (counts[.medium] ?? 0) * 5
        let lowPenalty: Int = (counts[.low] ?? 0)
        let raw: Int = 100 - critPenalty - highPenalty - medPenalty - lowPenalty
        let score: Int = max(0, raw)
        return Panel(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Eyebrow(text: "Posture score")
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(score)")
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(scoreColor(score))
                    Text("/ 100")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Theme.fgDim)
                    Spacer()
                    Text(scoreLabel(score))
                        .font(.system(size: 10, design: .monospaced))
                        .tracking(0.6)
                        .foregroundStyle(Theme.fgDim)
                }

                VStack(spacing: 4) {
                    ForEach([Severity.critical, .high, .medium, .low, .info], id: \.self) { s in
                        histogramRow(s, count: counts[s] ?? 0)
                    }
                }
            }
        }
        .frame(width: 240)
    }

    private func scoreColor(_ s: Int) -> Color {
        if s >= 85 { return Theme.accent }
        if s >= 60 { return Theme.sevLow }
        return Theme.sevHigh
    }

    private func scoreLabel(_ s: Int) -> String {
        if s >= 85 { return "GOOD" }
        if s >= 60 { return "FAIR" }
        return "AT RISK"
    }

    private func histogramRow(_ s: Severity, count: Int) -> some View {
        let color = SeverityMeta.color(s)
        return HStack(spacing: 8) {
            Text(SeverityMeta.label(s))
                .font(.system(size: 10, design: .monospaced))
                .tracking(0.6)
                .foregroundStyle(color)
                .frame(width: 60, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.05))
                    Capsule()
                        .fill(color)
                        .frame(width: min(geo.size.width, geo.size.width * CGFloat(min(100, count * 12)) / 100))
                        .opacity(count > 0 ? 1 : 0)
                }
            }
            .frame(height: 4)
            Text("\(count)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(count > 0 ? Theme.fg : Theme.fgFaint)
                .frame(width: 18, alignment: .trailing)
        }
    }
}

// MARK: - Filter bar

struct FilterBar: View {
    let findings: [Finding]
    @Binding var sev: Severity?
    @Binding var cat: String
    @Binding var query: String

    private var categories: [String] {
        var seen = Set<String>()
        var out: [String] = ["All"]
        for f in findings where !seen.contains(f.prettyCategory) {
            seen.insert(f.prettyCategory)
            out.append(f.prettyCategory)
        }
        return out
    }

    var body: some View {
        HStack(spacing: 10) {
            searchField
            severitySegmented
            Spacer()
            categoryPills
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Theme.bg1)
        .overlay(Rectangle().fill(Theme.line).frame(height: 0.5), alignment: .bottom)
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(Theme.fgDim)
            TextField("Filter findings…", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(Theme.fg)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.fgDim)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .frame(width: 240)
        .background(Theme.bg2)
        .overlay(
            RoundedRectangle(cornerRadius: 7).stroke(Theme.line2, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    private var severitySegmented: some View {
        HStack(spacing: 2) {
            segButton(label: "All", active: sev == nil) { sev = nil }
            ForEach([Severity.critical, .high, .medium, .low, .info], id: \.self) { s in
                segButton(label: SeverityMeta.label(s), active: sev == s) { sev = s }
            }
        }
        .padding(2)
        .background(Theme.bg2)
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.line, lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    private func segButton(label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(0.6)
                .foregroundStyle(active ? Theme.fg : Theme.fgMute)
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .background(active ? Theme.bg3 : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
    }

    private var categoryPills: some View {
        HStack(spacing: 4) {
            ForEach(categories, id: \.self) { c in
                Button { cat = c } label: {
                    Text(c)
                        .font(.system(size: 11.5))
                        .foregroundStyle(cat == c ? Theme.fg : Theme.fgMute)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(cat == c ? Theme.bg2 : .clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(cat == c ? Theme.line3 : .clear, lineWidth: 0.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Finding row

struct FindingRow: View {
    let finding: Finding
    let expanded: Bool
    let onToggle: () -> Void
    let onGoto: (Route) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.fgDim)
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                        .frame(width: 20)
                    SeverityPill(severity: finding.severity)
                        .frame(width: 76, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(finding.title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.fg)
                            .multilineTextAlignment(.leading)
                            .lineLimit(1)
                        Text(finding.description)
                            .font(.system(size: 11.5))
                            .foregroundStyle(Theme.fgDim)
                            .multilineTextAlignment(.leading)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 12)
                    Text(finding.prettyCategory)
                        .font(.system(size: 10, design: .monospaced))
                        .tracking(0.4)
                        .foregroundStyle(Theme.fgDim)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .background(expanded ? Color.white.opacity(0.02) : .clear)

            if expanded {
                expandedDetail
            }

            Rectangle().fill(Theme.line).frame(height: 0.5)
        }
        .background(expanded ? Color.white.opacity(0.02) : .clear)
    }

    private var expandedDetail: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(finding.description)
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.fgMute)
                .lineSpacing(2)
                .frame(maxWidth: 720, alignment: .leading)

            HStack(spacing: 16) {
                metaChip("source", "lockdownd")
                metaChip("id", finding.id)
                metaChip("ts", "2026-05-03T09:14:02Z")
                Spacer()
                if finding.id == "f-pairings" {
                    Btn(title: "Open Pairings", variant: .ghost, icon: "chevron.right") {
                        onGoto(.pairings)
                    }
                }
                Btn(title: "Copy JSON", variant: .subtle, icon: "doc.on.doc") {
                    let json = (try? JSONEncoder().encode(finding))
                        .flatMap { String(data: $0, encoding: .utf8) } ?? ""
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(json, forType: .string)
                }
            }
            .font(.system(size: 10.5, design: .monospaced))
            .foregroundStyle(Theme.fgDim)
        }
        .padding(.leading, 132)
        .padding(.trailing, 24)
        .padding(.bottom, 18)
    }

    private func metaChip(_ key: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(key).foregroundStyle(Theme.fgFaint)
            Text(value)
        }
    }
}

// MARK: - Scanning overlay

struct ScanningOverlay: View {
    let deviceName: String

    @State private var stepIdx: Int = 0
    @State private var logs: [(ts: String, msg: String)] = []

    private let steps = [
        "lockdownd handshake",
        "fetching identity (UDID, serial, IMEI)",
        "enumerating configuration profiles",
        "checking root CAs and trust store",
        "listing installed apps",
        "cross-checking stalkerware bundle list",
        "reading app entitlements",
        "enumerating Mac pairing records",
        "auditing escrow keybags",
        "evaluating posture (passcode, backup, lockdown)",
        "writing audit report",
    ]

    private var pct: Int { min(100, Int(Double(stepIdx) / Double(steps.count) * 100)) }
    private var currentStep: String { steps[min(stepIdx, steps.count - 1)] }

    var body: some View {
        VStack(spacing: 24) {
            spinner
            VStack(spacing: 6) {
                Text("Auditing \(deviceName)")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.fg)
                Text("\(pct)% · \(currentStep)")
                    .font(.system(size: 11, design: .monospaced))
                    .tracking(0.5)
                    .foregroundStyle(Theme.accent)
            }
            progressBar
            logBox
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
        .background(
            RadialGradient(colors: [Theme.accent.opacity(0.06), .clear],
                           center: UnitPoint(x: 0.5, y: 0.4), startRadius: 0, endRadius: 400)
                .background(Theme.bg1)
        )
        .task {
            for i in 1...steps.count {
                try? await Task.sleep(nanoseconds: 280_000_000)
                stepIdx = i
                let ts = String(format: "09:14:%02d", 2 + i)
                logs.append((ts, steps[i - 1]))
            }
        }
    }

    private var spinner: some View {
        ZStack {
            Circle().stroke(Theme.line2, lineWidth: 0.5).frame(width: 120, height: 120)
            SpinningArc()
                .stroke(Theme.accentLine, lineWidth: 1)
                .frame(width: 104, height: 104)
            Circle().stroke(Theme.accentLine.opacity(0.5), lineWidth: 0.5)
                .frame(width: 76, height: 76)
            LogoView(size: 40)
        }
    }

    private var progressBar: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(Theme.bg2).frame(width: 480, height: 4)
            Capsule().fill(Theme.accent)
                .frame(width: 480 * Double(pct) / 100, height: 4)
                .shadow(color: Theme.accent.opacity(0.7), radius: 4)
        }
    }

    private var logBox: some View {
        VStack(alignment: .leading, spacing: 2) {
            if logs.isEmpty {
                Text("Awaiting trust handshake…")
                    .foregroundStyle(Theme.fgFaint)
            }
            ForEach(Array(logs.enumerated()), id: \.offset) { _, log in
                HStack(spacing: 8) {
                    Text(log.ts).foregroundStyle(Theme.fgFaint)
                    Text("✓").foregroundStyle(Theme.accent)
                    Text(log.msg).foregroundStyle(Theme.fgMute)
                }
            }
        }
        .font(.system(size: 10.5, design: .monospaced))
        .padding(12)
        .frame(width: 480, height: 180, alignment: .topLeading)
        .background(Theme.bg2)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line, lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct SpinningArc: Shape {
    @State private var rotate: Double = 0
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addArc(center: CGPoint(x: rect.midX, y: rect.midY),
                 radius: rect.width / 2,
                 startAngle: .degrees(0),
                 endAngle: .degrees(280),
                 clockwise: false)
        return p
    }
}
