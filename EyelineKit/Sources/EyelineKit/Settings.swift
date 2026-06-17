import Foundation

/// Discrete panel-width choices the user picks in Settings.
public enum WidthPreset: String, Codable, CaseIterable, Sendable {
    case standard, wide, ultraWide

    /// Panel width in points for this preset.
    public var points: Double {
        switch self {
        case .standard:  return 360
        case .wide:      return 480
        case .ultraWide: return 600
        }
    }

    /// Human-facing label for the picker.
    public var label: String {
        switch self {
        case .standard:  return "Standard"
        case .wide:      return "Wide"
        case .ultraWide: return "Ultra-wide"
        }
    }
}

/// How the teleprompter advances. The user picks one in Settings; each maps to a `ScrollDriver`.
public enum ScrollMode: String, Codable, CaseIterable, Sendable {
    case timed       // constant speed (TimedScrollDriver)
    case loudness    // amplitude-gated (AmplitudeScrollDriver)
    case voice       // word-following (VoiceFollowScrollDriver)

    /// Human-facing label for the picker.
    public var label: String {
        switch self {
        case .timed:    return "Timed"
        case .loudness: return "Loudness"
        case .voice:    return "Voice"
        }
    }
}

/// User-tunable preferences. Pure value type — persisted as one JSON blob, applied by the app.
public struct Settings: Codable, Equatable, Sendable {
    public var speed: Double          // points/second
    public var fontSize: Double       // points
    public var widthPreset: WidthPreset
    public var mode: ScrollMode

    public static let speedRange: ClosedRange<Double> = 10...80
    public static let fontSizeRange: ClosedRange<Double> = 16...34

    /// The single source of truth for first-run defaults.
    public static let defaults = Settings(speed: 30, fontSize: 22, widthPreset: .standard, mode: .timed)

    public init(
        speed: Double = 30,
        fontSize: Double = 22,
        widthPreset: WidthPreset = .standard,
        mode: ScrollMode = .timed
    ) {
        self.speed = Settings.clampSpeed(speed)
        self.fontSize = Settings.clampFontSize(fontSize)
        self.widthPreset = widthPreset
        self.mode = mode
    }

    private enum CodingKeys: String, CodingKey {
        case speed, fontSize, widthPreset, mode
    }

    /// Tolerant decode: any missing or unreadable field falls back to its default rather than
    /// failing the whole blob. So adding a field (like `mode`) to an existing install never wipes
    /// the user's other settings, and an unknown `mode` raw value degrades to `.timed`. The
    /// memberwise init re-applies range clamping. (Encoding stays synthesized.)
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Settings.defaults
        let speed = ((try? c.decodeIfPresent(Double.self, forKey: .speed)) ?? nil) ?? d.speed
        let fontSize = ((try? c.decodeIfPresent(Double.self, forKey: .fontSize)) ?? nil) ?? d.fontSize
        let widthPreset = ((try? c.decodeIfPresent(WidthPreset.self, forKey: .widthPreset)) ?? nil) ?? d.widthPreset
        let mode = ((try? c.decodeIfPresent(ScrollMode.self, forKey: .mode)) ?? nil) ?? d.mode
        self.init(speed: speed, fontSize: fontSize, widthPreset: widthPreset, mode: mode)
    }

    public static func clampSpeed(_ v: Double) -> Double {
        min(max(v, speedRange.lowerBound), speedRange.upperBound)
    }

    public static func clampFontSize(_ v: Double) -> Double {
        min(max(v, fontSizeRange.lowerBound), fontSizeRange.upperBound)
    }
}
