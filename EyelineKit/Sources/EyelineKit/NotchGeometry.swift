import CoreGraphics

/// Pure geometry for placing the teleprompter panel relative to a display.
/// Kept free of AppKit so it tests headlessly; callers pass values read from NSScreen.
public enum NotchGeometry {

    /// Compute the panel frame in AppKit screen coordinates (origin bottom-left).
    ///
    /// - Parameters:
    ///   - screenFrame: the display's full frame (`NSScreen.frame`).
    ///   - topInset: height occupied by the menu bar / notch (`NSScreen.safeAreaInsets.top`).
    ///   - size: desired panel size.
    ///   - gap: vertical gap between the inset (notch/menu bar) and the panel top.
    /// - Returns: a frame horizontally centered, just below the top inset.
    public static func panelFrame(
        screenFrame: CGRect,
        topInset: CGFloat,
        size: CGSize,
        gap: CGFloat = 0
    ) -> CGRect {
        let x = screenFrame.minX + (screenFrame.width - size.width) / 2
        let y = screenFrame.maxY - topInset - gap - size.height
        return CGRect(x: x, y: y, width: size.width, height: size.height)
    }
}
