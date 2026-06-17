import KeyboardShortcuts

/// Strongly-typed global shortcut names. KeyboardShortcuts auto-persists the user's chosen
/// key combos to UserDefaults under these identifiers — no manual persistence needed.
extension KeyboardShortcuts.Name {
    static let togglePlay   = Self("togglePlay")
    static let restart      = Self("restart")
    static let toggleHidden = Self("toggleHidden")
}
