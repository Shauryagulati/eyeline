import Testing
@testable import EyelineKit

@Suite struct ScrollBoundsTests {
    @Test func tallContentScrollsTheDifference() {
        #expect(ScrollBounds.maxOffset(contentHeight: 500, visibleHeight: 116) == 384)
    }

    @Test func contentShorterThanViewportDoesNotScroll() {
        #expect(ScrollBounds.maxOffset(contentHeight: 80, visibleHeight: 116) == 0)
    }

    @Test func contentEqualToViewportDoesNotScroll() {
        #expect(ScrollBounds.maxOffset(contentHeight: 116, visibleHeight: 116) == 0)
    }
}
