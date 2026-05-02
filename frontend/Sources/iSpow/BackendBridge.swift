import Foundation
import Combine

@MainActor
final class BackendBridge: ObservableObject {
    enum DaemonState: Equatable {
        case idle
        case starting
        case running
        case error(String)

        var displayLabel: String {
            switch self {
            case .idle: return "idle"
            case .starting: return "starting…"
            case .running: return "running"
            case .error(let msg): return "error: \(msg)"
            }
        }
    }

    @Published var devices: [Device] = []
    @Published var currentReport: AuditReport?
    @Published var currentRecommendation: HardeningRecommendation?
    @Published var diffReport: DiffReport?
    @Published var lastBuildResult: BuildProfileResult?
    @Published var isWorking = false
    @Published var daemonState: DaemonState = .idle

    private var process: Process?
    private var connection: UnixSocketConnection?
    private var nextRequestID = 1
    private var pending: [Int: CheckedContinuation<Data, Error>] = [:]
    private let socketPath: String
    private let pythonExecutable: String

    init(
        socketPath: String = "/tmp/iphone-audit.sock",
        pythonExecutable: String = ProcessInfo.processInfo.environment["IPHONE_AUDIT_PYTHON"]
            ?? "/usr/bin/env python3"
    ) {
        self.socketPath = socketPath
        self.pythonExecutable = pythonExecutable
    }

    // MARK: - Lifecycle

    func start() async {
        Log.info("BackendBridge.start()")
        daemonState = .starting
        do {
            try spawnBackend()
            try await connectWithRetry(maxAttempts: 20, delay: 0.15)
            daemonState = .running
            Log.info("daemon running, refreshing devices")
            await refreshDevices()
        } catch {
            Log.error("start failed: \(error)")
            daemonState = .error(String(describing: error))
        }
    }

    func stop() {
        Log.info("BackendBridge.stop()")
        process?.terminate()
        process = nil
        connection = nil
        daemonState = .idle
    }

    private func spawnBackend() throws {
        let proc = Process()
        let resolution = resolveBackendInvocation()
        proc.executableURL = resolution.executable
        proc.arguments = resolution.arguments + ["daemon", "--socket", socketPath]
        var env = ProcessInfo.processInfo.environment
        if let pythonpath = resolution.pythonPath {
            env["PYTHONPATH"] = pythonpath + (env["PYTHONPATH"].map { ":\($0)" } ?? "")
        }
        proc.environment = env
        try proc.run()
        self.process = proc
    }

    /// Resolve how to launch the backend. In priority order:
    ///   1. PyInstaller-bundled `iphone-audit-backend` inside `Contents/Resources/backend/`.
    ///   2. Sibling-folder `backend/.venv/bin/python -m iphone_audit` (most common
    ///      personal-build layout: iSpow.app sits next to the backend folder).
    ///   3. `IPHONE_AUDIT_PYTHON` env var pointing at a Python interpreter.
    ///   4. `/usr/bin/env python3 -m iphone_audit` (relies on PATH).
    private struct BackendResolution {
        let executable: URL
        let arguments: [String]
        let pythonPath: String?  // for option (2) we also export PYTHONPATH so the package is importable
    }

    private func resolveBackendInvocation() -> BackendResolution {
        // (1) bundled PyInstaller binary
        if let bundled = Bundle.main.url(
            forResource: "iphone-audit-backend",
            withExtension: nil,
            subdirectory: "backend"
        ) {
            return BackendResolution(executable: bundled, arguments: [], pythonPath: nil)
        }

        // (2) sibling backend folder (the layout this repo ships with)
        if let sibling = locateSiblingBackend() {
            return BackendResolution(
                executable: sibling.python,
                arguments: ["-m", "iphone_audit"],
                pythonPath: sibling.packagePath.path
            )
        }

        // (3) explicit override
        let parts = pythonExecutable.split(separator: " ").map(String.init)
        if !parts.isEmpty {
            return BackendResolution(
                executable: URL(fileURLWithPath: parts[0]),
                arguments: Array(parts.dropFirst()) + ["-m", "iphone_audit"],
                pythonPath: nil
            )
        }

        // (4) last-resort: env python3 from PATH
        return BackendResolution(
            executable: URL(fileURLWithPath: "/usr/bin/env"),
            arguments: ["python3", "-m", "iphone_audit"],
            pythonPath: nil
        )
    }

    /// Walk up from the running .app to look for `…/backend/.venv/bin/python`
    /// alongside `…/backend/iphone_audit/`.
    private func locateSiblingBackend() -> (python: URL, packagePath: URL)? {
        let bundleURL = Bundle.main.bundleURL
        var search: [URL] = []
        // .app → parent → grandparent (covers iSpow/iSpow.app and iSpow/dist/iSpow.app)
        var cursor = bundleURL.deletingLastPathComponent()
        for _ in 0..<4 {
            search.append(cursor)
            cursor = cursor.deletingLastPathComponent()
        }
        let fm = FileManager.default
        for root in search {
            let backend = root.appendingPathComponent("backend")
            let python = backend.appendingPathComponent(".venv/bin/python")
            let packagePath = backend  // backend/iphone_audit is importable when PYTHONPATH=backend
            let pkg = backend.appendingPathComponent("iphone_audit/__init__.py")
            if fm.fileExists(atPath: python.path), fm.fileExists(atPath: pkg.path) {
                return (python, packagePath)
            }
        }
        return nil
    }

    private func connectWithRetry(maxAttempts: Int, delay: TimeInterval) async throws {
        var lastError: Error?
        for attempt in 0 ..< maxAttempts {
            do {
                let conn = try UnixSocketConnection(path: socketPath)
                self.connection = conn
                Log.info("connected to socket on attempt \(attempt + 1)")
                startReadLoop(connection: conn)
                return
            } catch {
                lastError = error
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        Log.error("connect failed after \(maxAttempts) attempts: \(lastError.map(String.init(describing:)) ?? "?")")
        throw lastError ?? UnixSocketConnection.SocketError.closed
    }

    /// Read loop runs on a global dispatch queue so the blocking `read(2)`
    /// in `UnixSocketConnection.readLine()` cannot stall the main thread.
    /// Results are posted back to the main actor for delivery.
    private func startReadLoop(connection: UnixSocketConnection) {
        Log.info("startReadLoop on global queue")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            while true {
                let line: Data
                do {
                    line = try connection.readLine()
                } catch {
                    Log.warn("readLine failed: \(error)")
                    Task { @MainActor [weak self] in
                        self?.failAllPending(with: error)
                    }
                    return
                }
                let id = Self.parseResponseID(line)
                Task { @MainActor [weak self] in
                    self?.deliver(id: id, payload: line)
                }
            }
        }
    }

    private static func parseResponseID(_ data: Data) -> Int {
        struct IDOnly: Decodable { let id: Int? }
        if let parsed = try? JSONDecoder().decode(IDOnly.self, from: data) {
            return parsed.id ?? -1
        }
        return -1
    }

    private func deliver(id: Int, payload: Data) {
        guard let cont = pending.removeValue(forKey: id) else {
            Log.warn("deliver: no pending continuation for id=\(id)")
            return
        }
        cont.resume(returning: payload)
    }

    private func failAllPending(with error: Error) {
        Log.warn("failAllPending: \(pending.count) waiters, error=\(error)")
        for (_, cont) in pending {
            cont.resume(throwing: error)
        }
        pending.removeAll()
    }

    // MARK: - RPC primitive

    private func call(method: String, params: [String: Any] = [:]) async throws -> Data {
        guard let connection else { throw UnixSocketConnection.SocketError.closed }
        let id = nextRequestID
        nextRequestID += 1
        let request: [String: Any] = [
            "jsonrpc": "2.0",
            "id": id,
            "method": method,
            "params": params,
        ]
        let body = try JSONSerialization.data(withJSONObject: request, options: [])
        let response: Data = try await withCheckedThrowingContinuation { cont in
            self.pending[id] = cont
            do {
                try connection.writeLine(body)
            } catch {
                self.pending.removeValue(forKey: id)
                cont.resume(throwing: error)
            }
        }
        return response
    }

    private struct RPCEnvelope<T: Decodable>: Decodable {
        let id: Int
        let result: T?
        let error: RPCError?
    }
    private struct RPCError: Decodable, Error {
        let code: Int
        let message: String
    }

    private func decode<T: Decodable>(_ data: Data, as type: T.Type) throws -> T {
        let env = try JSONDecoder().decode(RPCEnvelope<T>.self, from: data)
        if let err = env.error { throw err }
        guard let result = env.result else {
            throw NSError(domain: "iSpow", code: 0, userInfo: [NSLocalizedDescriptionKey: "Missing result"])
        }
        return result
    }

    // MARK: - High-level API

    private struct DevicesResult: Decodable { let devices: [Device] }
    private struct ReportResult: Decodable { let report: AuditReport }
    private struct AdviceResult: Decodable { let recommendation: HardeningRecommendation }
    private struct DiffResult: Decodable { let diff: DiffReport }
    private struct InstallResult: Decodable { let queued: Bool }
    private struct PingResult: Decodable { let pong: Bool }

    func ping() async throws -> Bool {
        let data = try await call(method: "ping")
        return try decode(data, as: PingResult.self).pong
    }

    func refreshDevices() async {
        do {
            let data = try await call(method: "list_devices")
            let res = try decode(data, as: DevicesResult.self)
            Log.info("refreshDevices: \(res.devices.count) device(s)")
            self.devices = res.devices
        } catch {
            Log.warn("refreshDevices failed: \(error)")
        }
    }

    func quickAudit(udid: String) async throws -> AuditReport {
        Log.info("quickAudit udid=\(udid)")
        isWorking = true; defer { isWorking = false }
        let data = try await call(method: "quick_audit", params: ["udid": udid])
        let res = try decode(data, as: ReportResult.self)
        Log.info("quickAudit returned \(res.report.findings.count) findings")
        self.currentReport = res.report
        return res.report
    }

    func getAdvice(useLLM: Bool) async throws -> HardeningRecommendation {
        guard let report = currentReport else {
            throw NSError(domain: "iSpow", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "No audit report loaded"])
        }
        isWorking = true; defer { isWorking = false }
        let reportDict = try jsonObject(from: report)
        let data = try await call(method: "get_advice", params: [
            "report": reportDict,
            "use_llm": useLLM,
        ])
        let res = try decode(data, as: AdviceResult.self)
        self.currentRecommendation = res.recommendation
        return res.recommendation
    }

    func buildAndInstall(udid: String) async throws -> BuildProfileResult {
        guard let rec = currentRecommendation else {
            throw NSError(domain: "iSpow", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "No recommendation loaded"])
        }
        isWorking = true; defer { isWorking = false }
        let recDict = try jsonObject(from: rec)
        let data = try await call(method: "build_and_install", params: [
            "udid": udid,
            "recommendation": recDict,
        ])
        let build = try decode(data, as: BuildAndInstallResult.self)
        self.lastBuildResult = BuildProfileResult(
            profilePath: build.profilePath,
            archivePath: build.archivePath,
            removalPassword: build.removalPassword,
            sizeBytes: build.sizeBytes
        )
        Log.info("build_and_install ok queued=\(build.queued) canonical=\(build.profilePath) archive=\(build.archivePath ?? "none")")
        return self.lastBuildResult!
    }

    /// Build a `.mobileconfig` from the user-curated payload toggles and push
    /// it to the device in one round-trip. Returns the build result with
    /// generated removal password.
    func buildAndInstall(udid: String, payloads: [PayloadOption]) async throws -> BuildProfileResult {
        Log.info("buildAndInstall(payloads): \(payloads.filter(\.enabled).count) enabled / \(payloads.count) total")
        isWorking = true; defer { isWorking = false }
        let recommendation = recommendationDict(from: payloads)
        let data = try await call(method: "build_and_install", params: [
            "udid": udid,
            "recommendation": recommendation,
        ])
        let build = try decode(data, as: BuildAndInstallResult.self)
        let result = BuildProfileResult(
            profilePath: build.profilePath,
            archivePath: build.archivePath,
            removalPassword: build.removalPassword,
            sizeBytes: build.sizeBytes
        )
        self.lastBuildResult = result
        Log.info("build_and_install ok queued=\(build.queued) canonical=\(build.profilePath) archive=\(build.archivePath ?? "none")")
        return result
    }

    private struct BuildAndInstallResult: Decodable {
        let profilePath: String
        let archivePath: String?
        let removalPassword: String
        let sizeBytes: Int
        let queued: Bool

        enum CodingKeys: String, CodingKey {
            case profilePath = "profile_path"
            case archivePath = "archive_path"
            case removalPassword = "removal_password"
            case sizeBytes = "size_bytes"
            case queued
        }
    }

    func verify(udid: String) async throws -> DiffReport {
        guard let before = currentReport else {
            throw NSError(domain: "iSpow", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "No baseline report"])
        }
        isWorking = true; defer { isWorking = false }
        let beforeDict = try jsonObject(from: before)
        let data = try await call(method: "verify", params: [
            "udid": udid,
            "before": beforeDict,
        ])
        let res = try decode(data, as: DiffResult.self)
        self.diffReport = res.diff
        return res.diff
    }

    // MARK: - Helpers

    private func jsonObject<T: Encodable>(from value: T) throws -> Any {
        let data = try JSONEncoder().encode(value)
        return try JSONSerialization.jsonObject(with: data, options: [])
    }

    /// Convert the user's curated payload toggles into the JSON shape the
    /// backend's `HardeningRecommendation` Pydantic model expects.
    private func recommendationDict(from payloads: [PayloadOption]) -> [String: Any] {
        let enabled = payloads.filter { $0.enabled && !$0.locked }
        let payloadDicts: [[String: Any]] = enabled.compactMap { payloadToBackendDict($0) }
        return [
            "summary": "User-curated hardening — \(enabled.count) payload(s) enabled.",
            "risk_level": "medium",
            "payloads": payloadDicts,
            "user_actions": [],
            "deferred_findings": [],
        ]
    }

    /// Map one PayloadOption (the design system's friendly representation) to
    /// a `(payload_type, fields)` pair the backend builder will write into the
    /// .mobileconfig. Only payload IDs present in this switch produce output;
    /// others (including the locked removal-password row) are dropped — the
    /// backend always inserts its own RemovalPassword child.
    private func payloadToBackendDict(_ p: PayloadOption) -> [String: Any]? {
        let mapped: (type: String, fields: [String: Any])? = {
            switch p.id {
            case "pl-passcode":
                return ("com.apple.passcode", [
                    "forcePIN": true,
                    "requireAlphanumeric": true,
                    "minLength": 8,
                    "minComplexChars": 1,
                    "maxFailedAttempts": 10,
                    "maxInactivity": 2,
                    "pinHistory": 5,
                ])
            case "pl-restrict-lockscreen":
                return ("com.apple.applicationaccess", [
                    "allowLockScreenControlCenter": false,
                    "allowLockScreenNotificationsView": false,
                    "allowLockScreenTodayView": false,
                ])
            case "pl-airdrop":
                return ("com.apple.applicationaccess", [
                    "allowAirDrop": false,
                ])
            case "pl-backup-enc":
                return ("com.apple.applicationaccess", [
                    "forceEncryptedBackup": true,
                ])
            case "pl-ads":
                return ("com.apple.applicationaccess", [
                    "forceLimitAdTracking": true,
                    "allowDiagnosticSubmission": false,
                    "allowDiagnosticSubmissionModification": false,
                    "allowSiriServerLogging": false,
                ])
            case "pl-keychain":
                return ("com.apple.applicationaccess", [
                    "allowCloudKeychainSync": false,
                ])
            case "pl-enterprise":
                return ("com.apple.applicationaccess", [
                    "allowEnterpriseAppTrust": false,
                ])
            case "pl-anonymous":
                // No-Apple-ID lockdown: silence every Apple endpoint that
                // still leaks unauthenticated metadata.
                return ("com.apple.applicationaccess", [
                    // Telemetry & ad tracking
                    "allowDiagnosticSubmission": false,
                    "allowDiagnosticSubmissionModification": false,
                    "forceLimitAdTracking": true,
                    "allowApplePersonalizedAdvertising": false,
                    // Siri / dictation phone-home
                    "allowSiriServerLogging": false,
                    "allowAssistantUserGeneratedContent": false,
                    "allowDictation": false,
                    // Spotlight / Safari telemetry
                    "allowSpotlightInternetResults": false,
                    "safariAllowAutoFill": false,
                    // iCloud sync surfaces (defence in depth)
                    "allowCloudBackup": false,
                    "allowCloudDocumentSync": false,
                    "allowCloudPhotoLibrary": false,
                    "allowCloudKeychainSync": false,
                    "allowMyPhotoStream": false,
                    "allowSharedStream": false,
                    // Apple-ID-gated services
                    "allowGameCenter": false,
                    "allowFindMyDevice": false,
                    "allowFindMyFriends": false,
                ])
            default:
                return nil
            }
        }()

        guard let mapped else { return nil }
        return [
            "payload_type": mapped.type,
            "rationale": p.blurb,
            "fields": mapped.fields,
            "addresses_finding_ids": p.addresses,
        ]
    }
}
