import AVFoundation

/// Thin wrapper over AVCaptureDevice audio authorization.
enum MicPermission {

    /// Resolve current status, prompting once if undetermined. The completion may arrive on a
    /// background thread — callers hop to the main actor before touching UI.
    static func ensureAccess(_ completion: @escaping @Sendable (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                completion(granted)
            }
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }
}
