import SwiftUI
import EyelineKit

@MainActor
final class TeleprompterViewModel: ObservableObject {
    @Published var offset: Double = 0
    @Published var text: String = ""
    @Published var isPlaying: Bool = false
    /// Measured height of the rendered script, reported up from the view's layout.
    @Published var contentHeight: CGFloat = 0
    /// Live panel width (driven by the WidthPreset setting).
    @Published var width: CGFloat = PanelMetrics.defaultWidth
    /// Live script font size in points (driven by the font-size setting).
    @Published var fontSize: CGFloat = CGFloat(Settings.defaults.fontSize)
    /// Invoked when the user taps the panel. Wired to `NotchController.togglePlay`.
    var onTogglePlay: (() -> Void)?
}

struct TeleprompterView: View {
    @ObservedObject var model: TeleprompterViewModel
    /// When the user has asked for reduced motion, the decorative ease transitions below collapse to
    /// instant. The continuous teleprompter scroll itself is essential content motion (the whole
    /// point of the app), not decoration, so it's deliberately left running.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let inset = PanelMetrics.textInset
    private let corner = PanelMetrics.cornerRadius
    /// Recomputed whenever the model publishes a new width.
    private var size: CGSize { CGSize(width: model.width, height: PanelMetrics.height) }

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

    /// True once the script has scrolled to (or past) its end — the conclusion is fully in view.
    /// Drives both hiding the play affordance and keeping the final lines at full opacity.
    private var atEnd: Bool {
        model.contentHeight > 0 && displayOffset >= maxOffset
    }

    /// True when there are no words to read — a blank/whitespace body, or every script deleted.
    /// Drives the first-run hint so an empty card isn't a silent dead end.
    private var isEmptyScript: Bool {
        model.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// What VoiceOver reads as the card's value: the script text, or the first-run prompt when empty.
    private var accessibilityScriptValue: String {
        isEmptyScript ? "No script yet. Add one in Scripts from the menu bar." : model.text
    }

    /// Squared top edge so the card sits flush against the notch; only the bottom corners round.
    private var cardShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: corner,
            bottomTrailingRadius: corner,
            topTrailingRadius: 0,
            style: .continuous)
    }

    var body: some View {
        ZStack {
            cardShape.fill(Color.black)            // opaque — reads as an extension of the notch

            scrollingText
                .mask { edgeFade }                 // lines dissolve at the top/bottom edges

            // First-run / empty state — points the user at the Scripts window instead of a black void.
            if isEmptyScript {
                emptyHint
            }

            // Paused affordance — shown when there's something to scroll AND we haven't reached the
            // end. At the end it would just cover the final lines you're still reading; the whole
            // panel stays tappable, so a tap there restarts from the top.
            if !model.isPlaying && maxOffset > 0 && !atEnd {
                Image(systemName: "play.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white.opacity(0.95))
                    .padding(15)
                    .background(.ultraThinMaterial, in: Circle())
                    .transition(.opacity)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(cardShape)
        .contentShape(Rectangle())
        .onTapGesture { model.onTogglePlay?() }
        // The whole card is one play/pause control to VoiceOver: the label states the action it'll
        // perform, the value is the script itself (or the first-run prompt), and the explicit action
        // toggles playback so VO activation matches the tap gesture above.
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(model.isPlaying ? "Pause teleprompter" : "Play teleprompter")
        .accessibilityValue(accessibilityScriptValue)
        .accessibilityAction { model.onTogglePlay?() }
        .onPreferenceChange(ContentHeightKey.self) { height in
            model.contentHeight = height
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: model.isPlaying)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isEmptyScript)
        // Match the window-frame animation in NotchController.setWidth so the card's content and
        // its window grow in lockstep; font changes ease rather than snap.
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: model.width)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: model.fontSize)
    }

    /// The script laid out at its FULL height, then scrolled within a fixed, top-pinned, clipped
    /// window. The fixed `.frame` is what keeps the card from resizing around the tall text.
    private var scrollingText: some View {
        Text(model.text)
            .font(.system(size: model.fontSize, weight: .semibold, design: .rounded))
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
            // Dim only while paused mid-script; full brightness while playing AND once finished, so
            // you can clearly read the closing lines instead of squinting at dimmed text.
            .opacity(model.isPlaying || atEnd ? 1 : 0.55)
            .clipped()
    }

    /// Shown when the card has no words yet. Deliberately quiet — it reads as a gentle placeholder,
    /// not a control — and names the exact menu item ("Scripts…") so a first-run user knows where
    /// the app actually lives (it's menu-bar-only, with no Dock presence by default).
    private var emptyHint: some View {
        VStack(spacing: 5) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 18, weight: .medium))
            Text("Your script goes here")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
            Text("Add one in Scripts… from the menu bar")
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
        }
        .foregroundStyle(.white.opacity(0.7))
        .multilineTextAlignment(.center)
        .padding(.horizontal, inset)
        .transition(.opacity)
    }

    /// Soft fade occupying the top/bottom breathing room, so text appears and dissolves at the
    /// edges instead of hard-clipping. Fade ends exactly where the first readable line begins.
    private var edgeFade: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0.0),
                .init(color: .black, location: 0.10),
                .init(color: .black, location: 0.90),
                .init(color: .clear, location: 1.0),
            ],
            startPoint: .top, endPoint: .bottom)
    }
}

private struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
