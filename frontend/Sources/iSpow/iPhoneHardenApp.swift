import SwiftUI

@main
struct iPhoneHardenApp: App {
    @StateObject private var backend = BackendBridge()

    init() {
        Log.reset()
        Log.info("=== iSpow launched (PID \(ProcessInfo.processInfo.processIdentifier)) ===")
    }

    var body: some Scene {
        WindowGroup("iSpow — iPhone Audit & Hardening") {
            ContentView()
                .environmentObject(backend)
                .frame(minWidth: 1180, minHeight: 760, idealHeight: 820)
                .preferredColorScheme(.dark)
                .task {
                    Log.info("WindowGroup .task starting backend")
                    await backend.start()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
    }
}
