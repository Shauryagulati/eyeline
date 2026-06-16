import Foundation

/// Pure mapping from a linear RMS amplitude to a normalized 0…1 level over a dBFS window.
/// Kept free of AVFoundation so it tests headlessly; the mic meter computes RMS and calls this.
public enum AudioLevel {

    /// - Parameters:
    ///   - rms: linear RMS amplitude of an audio buffer (0…1 for normalized float samples).
    ///   - floorDB: dBFS that maps to 0 (quiet room). Default -50.
    ///   - ceilDB: dBFS that maps to 1 (loud speech). Default -10.
    /// - Returns: normalized level in 0…1.
    public static func normalized(rms: Double, floorDB: Double = -50, ceilDB: Double = -10) -> Double {
        guard rms > 0 else { return 0 }
        let db = 20 * log10(rms)
        let clamped = min(max(db, floorDB), ceilDB)
        return (clamped - floorDB) / (ceilDB - floorDB)
    }
}
