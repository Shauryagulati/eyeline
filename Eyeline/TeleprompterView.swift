import SwiftUI
import EyelineKit

@MainActor
final class TeleprompterViewModel: ObservableObject {
    @Published var offset: Double = 0
    @Published var text: String = ""
    @Published var isPlaying: Bool = false
    /// Measured height of the rendered script, reported up from the view's layout.
    @Published var contentHeight: CGFloat = 0
    /// Invoked when the user taps the panel. Wired to `NotchController.togglePlay`.
    var onTogglePlay: (() -> Void)?
}

struct TeleprompterView: View {
    @ObservedObject var model: TeleprompterViewModel

    private let size = PanelMetrics.size
    private let inset = PanelMetrics.textInset
    private let corner = PanelMetrics.cornerRadius

    /// Readable area = panel height minus top + bottom breathing room.
    private var visibleHeight: CGFloat { size.height - inset * 2 }

    private var maxOffset: CGFloat {
        CGFloat(ScrollBounds.maxOffset(
            contentHeight: Double(model.contentHeight),
            visibleHeight: Double(visibleHeight)))
    }

    /// Clamp the scroll so the script can't run off into empty space once it has been measured.
    private var displayOffset: CGFloat {
        model.contentHeight > 0 ? min(CGFloat(model.offset), maxOffset) : CGFloat(model.offset)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(.black.opacity(0.85))

            scrollingText

            // Paused affordance — shown only when there is actually something to scroll.
            if !model.isPlaying && maxOffset > 0 {
                Image(systemName: "play.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white.opacity(0.95))
                    .padding(15)
                    .background(.ultraThinMaterial, in: Circle())
                    .transition(.opacity)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { model.onTogglePlay?() }
        .onPreferenceChange(ContentHeightKey.self) { height in
            model.contentHeight = height
        }
        .animation(.easeInOut(duration: 0.2), value: model.isPlaying)
    }

    /// The script laid out at its FULL height, then scrolled within a fixed, top-pinned, clipped
    /// window. The fixed `.frame` is what keeps the card from resizing around the tall text.
    private var scrollingText: some View {
        Text(model.text)
            .font(.system(size: 22, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .lineSpacing(6)
            .frame(width: size.width - inset * 2)          // fixed column → deterministic wrap
            .fixedSize(horizontal: false, vertical: true)  // full height, never truncate
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: ContentHeightKey.self, value: proxy.size.height)
                }
            )
            .offset(y: inset - displayOffset)              // scrolls upward as offset grows
            .frame(width: size.width, height: size.height, alignment: .top)
            .opacity(model.isPlaying ? 1 : 0.5)
            .clipped()
    }
}

private struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
