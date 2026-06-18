import Foundation

/// Pure word-alignment brain for Voice mode. Given a rolling tail of recently recognized words,
/// it figures out which word of the loaded script the speaker is on and exposes that as a locked
/// index + a 0…1 confidence + a 0…1 progress fraction (which the geometry bridge turns into a
/// scroll offset). No clock, no audio, no I/O — a deterministic function of (script, ingested
/// words), so it tests headlessly.
///
/// Algorithm (v1, deliberately simple per the "simplest thing that works" rule): anchor on the
/// *last* spoken word and score each candidate script position by how many of the last few words
/// line up backward from it (position-aligned, contiguous). The best position whose score clears
/// `matchThreshold` becomes the new lock; if nothing clears it, the index holds and confidence
/// decays (the "hold, then re-lock" behavior). Gap-tolerant DP alignment is intentionally out of
/// scope — the recognizer/aligner seam lets a smarter aligner swap in later without touching the
/// driver or UI.
public final class ScriptAligner {
    /// A script word: its normalized form (for matching) and where it starts in the original text
    /// (for geometry). `charOffset` counts Characters from the start of the original string.
    private struct Token {
        let normalized: String
        let charOffset: Int
    }

    private let tokens: [Token]
    private let totalChars: Int

    public private(set) var lockedIndex: Int = 0
    public private(set) var confidence: Double = 0

    /// How far back from the current lock to search for a re-lock (small re-reads / repeats).
    public var backWindow: Int
    /// How far forward from the current lock to search (skips ahead). Bounds work + false matches.
    public var forwardWindow: Int
    /// Minimum match score (0…1) required to move the lock; below this the index holds.
    public var matchThreshold: Double
    /// Multiplier applied to confidence each time no position clears the threshold.
    public var holdDecay: Double
    /// How many of the most recent spoken words to score against each candidate position.
    public var matchSpan: Int

    public init(
        script: String,
        backWindow: Int = 5,
        forwardWindow: Int = 30,
        matchThreshold: Double = 0.6,
        holdDecay: Double = 0.8,
        matchSpan: Int = 6
    ) {
        self.backWindow = backWindow
        self.forwardWindow = forwardWindow
        self.matchThreshold = matchThreshold
        self.holdDecay = holdDecay
        self.matchSpan = matchSpan

        var toks: [Token] = []
        var charIndex = 0
        // Walk the original characters, splitting on whitespace, recording each token's start.
        var current = ""
        var currentStart = 0
        func flush() {
            if !current.isEmpty {
                let norm = ScriptAligner.normalize(current)
                if !norm.isEmpty { toks.append(Token(normalized: norm, charOffset: currentStart)) }
                current = ""
            }
        }
        for ch in script {
            if ch.isWhitespace {
                flush()
            } else {
                if current.isEmpty { currentStart = charIndex }
                current.append(ch)
            }
            charIndex += 1
        }
        flush()
        self.tokens = toks
        self.totalChars = charIndex
    }

    /// Feed the latest rolling tail of recognized words. Updates `lockedIndex` and `confidence`.
    public func ingest(recentWords: [String]) {
        guard !tokens.isEmpty else { decay(); return }
        let spoken = recentWords.map(ScriptAligner.normalize).filter { !$0.isEmpty }
        guard !spoken.isEmpty else { decay(); return }

        let lo = max(0, lockedIndex - backWindow)
        let hi = min(tokens.count - 1, lockedIndex + forwardWindow)
        guard lo <= hi else { decay(); return }

        var bestScore = -1.0
        var bestIndex = lockedIndex
        var bestDist = Int.max
        for e in lo...hi {
            let score = scoreEndingAt(e, spoken: spoken)
            let dist = abs(e - lockedIndex)
            // Higher score wins; ties resolve to the candidate closest to the current lock,
            // so genuine ambiguity nudges minimally instead of jumping.
            if score > bestScore || (score == bestScore && dist < bestDist) {
                bestScore = score
                bestIndex = e
                bestDist = dist
            }
        }

        if bestScore >= matchThreshold {
            lockedIndex = bestIndex
            confidence = bestScore
        } else {
            decay()
        }
    }

    /// Fraction of the script (by character offset) the locked word sits at, 0…1.
    public var progressFraction: Double {
        guard totalChars > 0, tokens.indices.contains(lockedIndex) else { return 0 }
        // A token's *start* offset undershoots the end: the final token starts before the last
        // character, so its start-fraction is < 1 — and a one-token / single-long-line script
        // (start offset 0) would be pinned at 0 forever, so Voice mode could never scroll it. Map
        // the last token to full progress so the conclusion can come into view. Earlier tokens keep
        // their start offset, preserving the tuned mid-script look-ahead resting position.
        if lockedIndex == tokens.count - 1 { return 1 }
        let f = Double(tokens[lockedIndex].charOffset) / Double(totalChars)
        return min(max(f, 0), 1)
    }

    /// Seed the lock to roughly the given progress fraction (0…1) *without* ingesting words. Used
    /// when Voice mode is (re)entered at an already-scrolled position so the first recognized word
    /// re-locks near the current place instead of snapping the script back to the top (H1).
    /// Confidence resets to 0 — the seed is a hint, not a measured match.
    public func seek(toProgress fraction: Double) {
        guard !tokens.isEmpty, totalChars > 0 else { return }
        let targetOffset = min(max(fraction, 0), 1) * Double(totalChars)
        // Last token whose start is at or before the target character offset.
        var idx = 0
        for (i, token) in tokens.enumerated() where Double(token.charOffset) <= targetOffset {
            idx = i
        }
        lockedIndex = idx
        confidence = 0
    }

    /// Return to the top of the script. Called on Restart — *not* on mode switches.
    public func reset() {
        lockedIndex = 0
        confidence = 0
    }

    // MARK: - Internals

    /// Score how well the spoken tail aligns ending at script index `e`: the fraction of the last
    /// `K` words that match position-for-position walking backward (K bounded by span, spoken
    /// length, and the script start).
    private func scoreEndingAt(_ e: Int, spoken: [String]) -> Double {
        let k = min(matchSpan, min(spoken.count, e + 1))
        guard k > 0 else { return 0 }
        var matches = 0
        for j in 0..<k where tokens[e - j].normalized == spoken[spoken.count - 1 - j] {
            matches += 1
        }
        return Double(matches) / Double(k)
    }

    private func decay() {
        confidence *= holdDecay
    }

    /// Lowercase and strip everything but alphanumerics. Applied to both script and spoken words
    /// so they compare on equal terms.
    private static func normalize(_ s: String) -> String {
        var out = ""
        for scalar in s.lowercased().unicodeScalars where CharacterSet.alphanumerics.contains(scalar) {
            out.unicodeScalars.append(scalar)
        }
        return out
    }
}
