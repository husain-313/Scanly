import SwiftUI

/// Hosts the library and, when app lock is on, a Face ID gate.
struct RootView: View {
    @AppStorage("appLockEnabled") private var appLockEnabled = false
    @StateObject private var lock = BiometricLock()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            LibraryView()
                .blur(radius: shouldGate ? 24 : 0)

            if shouldGate {
                lockScreen
            }
        }
        .task { if appLockEnabled { await lock.authenticate() } }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background && appLockEnabled { lock.lock() }
        }
    }

    private var shouldGate: Bool { appLockEnabled && !lock.isUnlocked }

    private var lockScreen: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill").font(.system(size: 44))
            Text("Scanly is locked").font(.headline)
            Button("Unlock") { Task { await lock.authenticate() } }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
    }
}
