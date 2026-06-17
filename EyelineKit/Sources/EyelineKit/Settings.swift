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

/// User-tunable preferences. Pure value type — persisted as one JSON blob, applied by the app.
public struct Settings: Codable, Equatable, Sendable {
    public var speed: Double          // points/second
    public var fontSize: Double       // points
    public var widthPreset: WidthPreset

    public static let speedRange: ClosedRange<Double> = 10...80
    public static let fontSizeRange: ClosedRange<Double> = 16...34

    /// The single source of truth for first-run defaults.
    public static let defaults = Settings(speed: 30, fontSize: 22, widthPreset: .standard)

    public init(speed: Double = 30, fontSize: Double = 22, widthPreset: WidthPreset = .standard) {
        self.speed = Settings.clampSpeed(speed)
        self.fontSize = Settings.clampFontSize(fontSize)
        self.widthPreset = widthPreset
    }

    public static func clampSpeed(_ v: Double) -> Double {
        min(max(v, speedRange.lowerBound), speedRange.upperBound)
    }

    public static func clampFontSize(_ v: Double) -> Double {
        min(max(v, fontSizeRange.lowerBound), fontSizeRange.upperBound)
    }
}
