import SwiftUI

// MARK: - Design tokens (mirrors theme.jsx)

enum Theme {
    // Backgrounds — cool-tinted near-blacks, layered
    static let bg0 = Color(hex: 0x0A0C0F)   // window outer
    static let bg1 = Color(hex: 0x0E1116)   // app body
    static let bg2 = Color(hex: 0x13171D)   // panels / cards
    static let bg3 = Color(hex: 0x191E26)   // hover / raised
    static let bg4 = Color(hex: 0x222933)   // input fills

    // Borders
    static let line  = Color.white.opacity(0.06)
    static let line2 = Color.white.opacity(0.10)
    static let line3 = Color.white.opacity(0.16)

    // Text
    static let fg     = Color(hex: 0xE8ECF2)
    static let fgMute = Color(hex: 0x9BA4B3)
    static let fgDim  = Color(hex: 0x6A7382)
    static let fgFaint = Color(hex: 0x454C57)

    // Accent — cool cyan-green ("secure / active"); approximated from oklch(78% 0.15 175)
    static let accent      = Color(hex: 0x49E0C8)
    static let accentSoft  = Color(hex: 0x49E0C8).opacity(0.14)
    static let accentLine  = Color(hex: 0x49E0C8).opacity(0.45)
    static let accentHover = Color(hex: 0x65EAD4)

    // Severity scale (oklch approximations)
    static let sevInfo = Color(hex: 0x9BB1C2)
    static let sevLow  = Color(hex: 0xC9A042) // amber
    static let sevMed  = Color(hex: 0xCF7A3A) // orange
    static let sevHigh = Color(hex: 0xCF4F36) // red-orange
    static let sevCrit = Color(hex: 0xC23A35) // crimson

    // Critical-ish backgrounds for windows + scanlines
    static let desktop = Color(hex: 0x05060A)

    // Fonts
    static let mono     = "SF Mono"        // JetBrains Mono → SF Mono fallback (system)
    static let monoSize: CGFloat = 11.5
    static let ui       = ".AppleSystemUIFont"
    static let display  = ".AppleSystemUIFont"
}

extension Color {
    init(hex: UInt32, opacity: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >>  8) & 0xFF) / 255
        let b = Double( hex        & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}

// MARK: - Severity meta

enum SeverityMeta {
    static func color(_ s: Severity) -> Color {
        switch s {
        case .info:     return Theme.sevInfo
        case .low:      return Theme.sevLow
        case .medium:   return Theme.sevMed
        case .high:     return Theme.sevHigh
        case .critical: return Theme.sevCrit
        }
    }

    static func label(_ s: Severity) -> String {
        switch s {
        case .info:     return "INFO"
        case .low:      return "LOW"
        case .medium:   return "MED"
        case .high:     return "HIGH"
        case .critical: return "CRIT"
        }
    }
}

// MARK: - Primitives (pills, dots, eyebrows, panels, buttons)

struct SeverityPill: View {
    let severity: Severity
    var size: PillSize = .small

    enum PillSize { case small, large }

    var body: some View {
        let color = SeverityMeta.color(severity)
        Text(SeverityMeta.label(severity))
            .font(.system(size: size == .small ? 9 : 10.5, weight: .semibold, design: .monospaced))
            .tracking(1.0)
            .foregroundStyle(color)
            .padding(.horizontal, size == .small ? 6 : 9)
            .padding(.vertical, size == .small ? 1 : 3)
            .background(color.opacity(0.14))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(color.opacity(0.35), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

struct SeverityDot: View {
    let severity: Severity
    var size: CGFloat = 8

    var body: some View {
        Circle()
            .fill(SeverityMeta.color(severity))
            .frame(width: size, height: size)
            .shadow(color: SeverityMeta.color(severity).opacity(0.5), radius: 4)
    }
}

struct Eyebrow: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .tracking(1.4)
            .foregroundStyle(Theme.fgDim)
    }
}

struct Panel<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background(Theme.bg2)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Theme.line, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

enum BtnVariant { case `default`, subtle, primary, danger, ghost }

struct Btn: View {
    let title: String
    var variant: BtnVariant = .default
    var icon: String? = nil
    var disabled: Bool = false
    var action: () -> Void = {}

    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .medium))
                }
                Text(title)
                    .font(.system(size: 12.5, weight: .medium))
            }
            .foregroundStyle(fgColor)
            .padding(.horizontal, 12)
            .frame(height: 28)
            .background(bgColor)
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(borderColor, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .opacity(disabled ? 0.5 : 1)
        .disabled(disabled)
        .onHover { hover = $0 }
    }

    private var bgColor: Color {
        switch variant {
        case .default: return hover ? Theme.bg3 : Theme.bg2
        case .subtle:  return hover ? Color.white.opacity(0.04) : .clear
        case .primary: return hover ? Theme.accentHover : Theme.accent
        case .danger:  return hover ? Color(hex: 0xE0584A) : Color(hex: 0xC23A35)
        case .ghost:   return hover ? Theme.bg2 : .clear
        }
    }

    private var fgColor: Color {
        switch variant {
        case .primary: return Color(hex: 0x06120F)
        case .danger:  return .white
        case .subtle:  return Theme.fgMute
        default:       return Theme.fg
        }
    }

    private var borderColor: Color {
        switch variant {
        case .default, .ghost: return Theme.line2
        default: return .clear
        }
    }
}

// MARK: - Logo

struct LogoView: View {
    var size: CGFloat = 18

    var body: some View {
        ZStack {
            // Shield outline with gradient stroke
            ShieldShape()
                .stroke(LinearGradient(colors: [Theme.accentHover, Color(hex: 0x49B3D6)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.4)
                .background(
                    ShieldShape()
                        .fill(Theme.accent.opacity(0.06))
                )
                .frame(width: size, height: size)

            // Concentric pulse circles
            Circle()
                .stroke(Theme.accent.opacity(0.7), lineWidth: 1.2)
                .frame(width: size * 0.33, height: size * 0.33)
                .offset(y: -size * 0.05)
            Circle()
                .stroke(Theme.accent.opacity(0.4), lineWidth: 0.7)
                .frame(width: size * 0.7, height: size * 0.7)
                .offset(y: -size * 0.05)
        }
        .frame(width: size, height: size)
    }
}

private struct ShieldShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height
        path.move(to: CGPoint(x: w * 0.5, y: 0.05 * h))
        path.addLine(to: CGPoint(x: w * 0.15, y: 0.20 * h))
        path.addLine(to: CGPoint(x: w * 0.15, y: 0.50 * h))
        path.addCurve(to: CGPoint(x: w * 0.5, y: 0.95 * h),
                      control1: CGPoint(x: w * 0.15, y: 0.78 * h),
                      control2: CGPoint(x: w * 0.30, y: 0.93 * h))
        path.addCurve(to: CGPoint(x: w * 0.85, y: 0.50 * h),
                      control1: CGPoint(x: w * 0.70, y: 0.93 * h),
                      control2: CGPoint(x: w * 0.85, y: 0.78 * h))
        path.addLine(to: CGPoint(x: w * 0.85, y: 0.20 * h))
        path.closeSubpath()
        return path
    }
}

// MARK: - Window chrome

struct TrafficLights: View {
    var onClose: () -> Void = {
        NSApp.keyWindow?.performClose(nil)
    }
    var onMinimize: () -> Void = {
        NSApp.keyWindow?.performMiniaturize(nil)
    }
    var onZoom: () -> Void = {
        NSApp.keyWindow?.performZoom(nil)
    }

    @State private var hover = false

    var body: some View {
        HStack(spacing: 8) {
            light(color: Color(hex: 0xFF5F57), glyph: "✕", action: onClose)
            light(color: Color(hex: 0xFEBC2E), glyph: "−", action: onMinimize)
            light(color: Color(hex: 0x28C840), glyph: "+", action: onZoom)
        }
        .onHover { hover = $0 }
    }

    private func light(color: Color, glyph: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle().fill(color)
                Circle().stroke(Color.black.opacity(0.4), lineWidth: 0.5)
                if hover {
                    Text(glyph)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.55))
                }
            }
            .frame(width: 12, height: 12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Visual effect background (vibrancy)

struct VibrancyView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .underWindowBackground
    var blending: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blending
        v.state = .active
        return v
    }

    func updateNSView(_ v: NSVisualEffectView, context: Context) {
        v.material = material
        v.blendingMode = blending
    }
}
