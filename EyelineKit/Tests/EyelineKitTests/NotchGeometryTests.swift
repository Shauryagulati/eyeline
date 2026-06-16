import Testing
import CoreGraphics
@testable import EyelineKit

@Suite("NotchGeometry")
struct NotchGeometryTests {

    @Test("centers the panel horizontally on the display")
    func centersHorizontally() {
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let frame = NotchGeometry.panelFrame(
            screenFrame: screen, topInset: 38,
            size: CGSize(width: 300, height: 120))
        #expect(frame.midX == screen.midX)
    }

    @Test("places the panel below the top inset by the gap")
    func belowTopInset() {
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let frame = NotchGeometry.panelFrame(
            screenFrame: screen, topInset: 38,
            size: CGSize(width: 300, height: 120), gap: 4)
        // AppKit y grows upward; panel top = screen top - inset - gap.
        // CGFloat(...) so #expect captures both operands as CGFloat (a bare integer-literal
        // RHS is typed Int inside the macro and the comparison wrongly reports false).
        #expect(frame.maxY == CGFloat(982 - 38 - 4))
    }

    @Test("respects a non-zero screen origin (display to the left of main)")
    func respectsScreenOrigin() {
        let screen = CGRect(x: -1512, y: 0, width: 1512, height: 982)
        let frame = NotchGeometry.panelFrame(
            screenFrame: screen, topInset: 38,
            size: CGSize(width: 300, height: 120))
        #expect(frame.midX == screen.midX)
        #expect(frame.minX == CGFloat(-1512 + (1512 - 300) / 2))
    }
}
