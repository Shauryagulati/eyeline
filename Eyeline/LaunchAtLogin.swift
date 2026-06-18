import ServiceManagement

/// Thin wrapper over `SMAppService.mainApp` (macOS 13+, we target 14) for the "Open at Login"
/// toggle. The OS owns the truth — this only reads the current status and registers/unregisters the
/// app as a login item. There's no preference of our own to persist: `SMAppService` is the single
/// source of truth, which is why every UI surface just re-reads `isEnabled` when it appears.
///
/// In development the app runs ad-hoc-signed from DerivedData; the OS may reject registration there.
/// `setEnabled` never throws to the caller — it logs and returns the *actual* resulting state, so the
/// UI reflects what really happened instead of an optimistic lie.
@MainActor
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            let service = SMAppService.mainApp
            if enabled {
                if service.status != .enabled { try service.register() }
            } else {
                if service.status == .enabled { try service.unregister() }
            }
        } catch {
            NSLog("Eyeline: Open at Login change to \(enabled) failed: \(error.localizedDescription)")
        }
        return isEnabled
    }
}
