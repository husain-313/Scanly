import Foundation
import LocalAuthentication

/// Face ID / Touch ID gate for locked documents and app lock.
@MainActor
final class BiometricLock: ObservableObject {
    @Published var isUnlocked = false

    func authenticate(reason: String = "Unlock your documents") async {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // No biometrics/passcode set: don't block the user.
            isUnlocked = true
            return
        }
        do {
            let ok = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            isUnlocked = ok
        } catch {
            isUnlocked = false
        }
    }

    func lock() { isUnlocked = false }
}
