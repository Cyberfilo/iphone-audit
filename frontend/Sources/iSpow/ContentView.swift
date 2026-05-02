import SwiftUI

struct ContentView: View {
    @EnvironmentObject var backend: BackendBridge

    @State private var route: Route = .audit
    @State private var selectedDevice: DisplayDevice? = nil
    @State private var scanning: Bool = false
    @State private var verified: Bool = false
    @State private var installPhase: VerifyScreen.Phase = .done
    @State private var showXml: Bool = false
    @State private var showRemoval: Bool = false
    @State private var lastPassword: String = "K7w-3M9q-Hpr-fX2c-LbN8-uVz4-aQ1d-Ej6t-RYs0"
    @State private var payloads: [PayloadOption] = Mock.payloads
    @State private var liveFindings: [Finding] = []
    @State private var installError: String? = nil

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                SidebarView(
                    selectedDevice: $selectedDevice,
                    route: $route,
                    devices: displayDevices
                )
                content
            }
            .background(Theme.bg1)

            if showRemoval {
                RemovalPasswordModal(
                    isPresented: $showRemoval,
                    device: selectedDevice,
                    password: lastPassword,
                    archivePath: backend.lastBuildResult?.archivePath,
                    onProceed: { Task { await proceedInstall() } }
                )
            }
        }
        .preferredColorScheme(.dark)
        .background(VibrancyView(material: .underWindowBackground, blending: .behindWindow))
    }

    private var content: some View {
        VStack(spacing: 0) {
            ContentToolbar(
                route: $route,
                device: selectedDevice,
                scanning: scanning,
                onScan: { Task { await runScan() } },
                onInstall: { Task { await buildAndInstall() } },
                onReverify: { Task { await reverify() } },
                onToggleXml: { showXml.toggle() }
            )

            // Most screens require a device. Only History/Settings work without one.
            if selectedDevice == nil && route != .history && route != .settings {
                NoDeviceState()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                routeContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg1)
        // When the user picks a different device, drop stale state for it.
        .onChange(of: selectedDevice?.id) { newId in
            Log.info("device switched -> \(newId ?? "nil")")
            liveFindings = []
            verified = false
            installPhase = .done
            scanning = false
            showXml = false
        }
        .onChange(of: route) { newRoute in
            Log.info("route -> \(newRoute.rawValue)")
        }
    }

    @ViewBuilder
    private var routeContent: some View {
        switch route {
        case .audit:
            AuditScreen(
                device: selectedDevice,
                findings: liveFindings,
                scanning: scanning
            ) { newRoute in route = newRoute }
        case .pairings:
            PairingsScreen(device: selectedDevice)
        case .harden:
            HardenScreen(
                device: selectedDevice,
                payloads: $payloads,
                showXml: showXml
            ) { Task { await buildAndInstall() } }
        case .verify:
            VerifyScreen(
                device: selectedDevice,
                before: liveFindings,
                after: verified ? afterFindings : liveFindings,
                phase: installPhase,
                onReverify: { Task { await reverify() } }
            )
        case .history:
            HistoryScreen(items: Mock.history)
        case .settings:
            SettingsScreen()
        }
    }

    private var afterFindings: [Finding] {
        let resolvedIds: Set<String> = ["f-pairings", "f-lockscreen-cc", "f-airdrop", "f-entitlements"]
        return liveFindings.filter { !resolvedIds.contains($0.id) }
    }

    private var displayDevices: [DisplayDevice] {
        backend.devices.map { d in
            DisplayDevice(
                id: d.udid, name: d.udid, model: "iPhone",
                storage: "—", color: "—", ios: "—",
                udid: d.udid, serial: "—", imei: "—",
                battery: 0, lastAudit: "—",
                posture: .ok, findings: 0, paired: 0, online: true
            )
        }
    }

    // MARK: - Async actions wired to backend

    @MainActor
    private func runScan() async {
        guard let d = backend.devices.first(where: { $0.udid == selectedDevice?.id }) else {
            return
        }
        scanning = true
        defer { scanning = false }
        do {
            _ = try await backend.quickAudit(udid: d.udid)
            if let report = backend.currentReport {
                liveFindings = report.findings
                applyFindingDrivenDefaults(report.findings)
            }
        } catch {
            // surface via toolbar/error state in a future iteration
        }
    }

    /// Auto-enable certain Hardening payload toggles based on what the
    /// audit found. Right now: turn on `pl-anonymous` when the device has
    /// no Apple ID — see `posture.no_apple_id` in the backend.
    @MainActor
    private func applyFindingDrivenDefaults(_ findings: [Finding]) {
        let hasNoAppleId = findings.contains { $0.id == "posture.no_apple_id" }
        if hasNoAppleId, let idx = payloads.firstIndex(where: { $0.id == "pl-anonymous" }) {
            payloads[idx].enabled = true
            Log.info("auto-enabled pl-anonymous (no Apple ID detected)")
        }
    }

    /// Build the .mobileconfig from the currently-toggled payloads, push it to
    /// the connected iPhone (the system Settings install prompt should appear
    /// on the device), and reveal the generated removal password in the modal.
    @MainActor
    private func buildAndInstall() async {
        guard let device = selectedDevice else {
            Log.warn("buildAndInstall: no device selected")
            installError = "No device selected."
            return
        }
        // Real device path: hit the backend.
        if backend.devices.contains(where: { $0.udid == device.id }) {
            Log.info("buildAndInstall: pushing to \(device.id)")
            do {
                let result = try await backend.buildAndInstall(udid: device.id, payloads: payloads)
                lastPassword = result.removalPassword
                installError = nil
                showRemoval = true
            } catch {
                Log.error("buildAndInstall failed: \(error)")
                installError = String(describing: error)
                showRemoval = true   // still show modal so user sees the error
            }
        } else {
            // Demo mode (no backend device matching the displayed selection): keep
            // the canned password but still walk through the modal so the wizard
            // exercises the same UI path.
            Log.info("buildAndInstall: demo mode (no real device matched)")
            showRemoval = true
        }
    }

    @MainActor
    private func proceedInstall() async {
        // The profile has already been pushed by `buildAndInstall`; this just
        // advances the wizard to the verify screen and runs the install
        // ceremony animation while the user taps Install on the iPhone.
        installPhase = .installing
        route = .verify
        try? await Task.sleep(nanoseconds: 4_500_000_000)
        installPhase = .done
        verified = true
    }

    @MainActor
    private func reverify() async {
        verified = false
        route = .audit
        await runScan()
        verified = true
        route = .verify
    }
}

// MARK: - Empty state when no device is connected

struct NoDeviceState: View {
    @EnvironmentObject var backend: BackendBridge

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "iphone.gen3.slash")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(Theme.fgFaint)

            VStack(spacing: 6) {
                Text("Connect an iPhone to begin")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.fg)
                Text("Plug in your iPhone via USB and tap “Trust This Computer” on the device. iSpow will list it in the sidebar.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.fgMute)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }

            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6))
                        .foregroundStyle(stateColor)
                    Text("Backend: \(backend.daemonState.displayLabel)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.fgDim)
                }
                Btn(title: "Refresh", variant: .ghost, icon: "arrow.clockwise") {
                    Task { await backend.refreshDevices() }
                }
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg1)
    }

    private var stateColor: Color {
        switch backend.daemonState {
        case .running: return Theme.accent
        case .starting: return Theme.sevLow
        case .error: return Theme.sevHigh
        case .idle: return Theme.fgFaint
        }
    }
}
