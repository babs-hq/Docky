import Foundation
import LocalAuthentication
import Observation

enum SignatureLockError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "Set up a passcode or Face ID in the Settings app to use this feature."
        }
    }
}

/// Optionally asks for Face ID (or the device passcode) before the saved signature can be used.
@Observable
final class SignatureLock {
    private static let enabledKey = "requiresAuthenticationForSignature"

    private(set) var isEnabled: Bool
    private(set) var isUnlocked = false

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isEnabled = defaults.bool(forKey: Self.enabledKey)
    }

    /// "Face ID", "Touch ID", or "Passcode", depending on what this device has.
    var methodName: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "Passcode"
        }
    }

    /// Turning the lock on *or off* requires authenticating, so someone holding an
    /// unlocked phone can't simply switch it off.
    func setEnabled(_ enabled: Bool) async throws {
        guard enabled != isEnabled else { return }
        guard try await authenticate(reason: "Confirm it's you to change this setting.") else { return }

        isEnabled = enabled
        defaults.set(enabled, forKey: Self.enabledKey)
        isUnlocked = enabled
    }

    /// Returns true if the signature may be used right now, asking for Face ID if needed.
    func unlock() async -> Bool {
        guard isEnabled, !isUnlocked else { return true }

        do {
            isUnlocked = try await authenticate(reason: "Unlock your saved signature.")
        } catch {
            // The device no longer has a passcode or Face ID, so it has no protection
            // of its own. Locking the user out of their signature wouldn't add any.
            isUnlocked = true
        }
        return isUnlocked
    }

    /// Called when the app goes to the background.
    func lock() {
        isUnlocked = false
    }

    // MARK: - Private

    /// True on success, false if the user cancelled or failed.
    /// Throws if this device can't authenticate at all.
    private func authenticate(reason: String) async throws -> Bool {
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else {
            throw SignatureLockError.unavailable
        }
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch {
            return false
        }
    }
}
