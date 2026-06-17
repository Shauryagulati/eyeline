import CoreGraphics

/// Single source of truth for the notch panel's dimensions and styling metrics.
/// Referenced by NotchPanel (window size), NotchController (positioning), and TeleprompterView
/// (layout) so the three can never drift out of sync.
enum PanelMetrics {
    static let size = CGSize(width: 360, height: 140)
    static let cornerRadius: CGFloat = 18
    /// Inner padding — used as both the horizontal text inset and the top/bottom breathing room.
    static let textInset: CGFloat = 14
}
