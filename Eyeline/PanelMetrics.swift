import CoreGraphics

/// Single source of truth for the notch panel's fixed geometry. Width is now user-tunable
/// (see WidthPreset / Settings); height and the rounding/inset stay constant. Referenced by
/// NotchPanel (initial window size), NotchController (positioning), and TeleprompterView (layout).
enum PanelMetrics {
    static let height: CGFloat = 140
    static let defaultWidth: CGFloat = 360   // matches WidthPreset.standard.points
    static let cornerRadius: CGFloat = 18
    /// Inner padding — used as both the horizontal text inset and the top/bottom breathing room.
    static let textInset: CGFloat = 14
}
