import Foundation

/// Pure scroll-extent math, kept in the brain so it tests headlessly.
public enum ScrollBounds {
    /// The largest scroll offset worth reaching: once the remaining content fits the visible
    /// area, there is nothing left to scroll. Returns 0 when the whole script already fits.
    public static func maxOffset(contentHeight: Double, visibleHeight: Double) -> Double {
        max(0, contentHeight - visibleHeight)
    }
}
