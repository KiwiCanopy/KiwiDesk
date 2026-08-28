import Foundation

/// The call-shape walk the two Reduce Motion guards share —
/// `ReduceMotionGateTests` and `ReduceMotionCensusTests`.
///
/// It lives here rather than in either of them because both
/// need the same two refusals, and a second copy is the drift
/// this file exists to prevent (`SourceScan`): harden the
/// whitespace skip in one and not the other, and the slack copy
/// silently stops seeing the sites its guard was written for.
extension SourceScan {
    /// Every call of `entry`, paired with the index of its
    /// opening paren (nil for the paren-less form).
    ///
    /// The whitespace between the name and the `(` is SKIPPED
    /// rather than required to be absent, and that is not
    /// tidiness: `.animation (x, value: y)` compiles and ships
    /// an ungated animation, and a needle demanding an adjacent
    /// paren does not see the site AT ALL — a fail-OPEN a
    /// guard-prover round produced by inserting one space. Only
    /// the imperative spelling may omit its parens entirely
    /// (Swift defaults the animation, so `withAnimation {` is an
    /// ungated call), which is the shape that shipped in
    /// `ShortcutsSection` and left that whole file unscanned
    /// until the prover found it (#989) — so `closureCounts` is
    /// the caller's, the census clause passing true for
    /// `.transaction { … }`.
    static func callSites(
        in source: [Character],
        for entry: String,
        closureCounts bare: Bool = false
    ) -> [(start: Int, paren: Int?)] {
        let needle = Array(entry)
        var found: [(start: Int, paren: Int?)] = []
        for start in source.indices
        where start + needle.count <= source.count
            && Array(source[start..<(start + needle.count)])
                == needle
        {
            // Skip a longer identifier that merely CONTAINS
            // the needle. Trailing letters are refused by the
            // paren requirement below (`.animations`, which the
            // settings model spells all over); leading ones
            // need this, or `RevealTimelineView {` answers for
            // `TimelineView` (guard-prover).
            if start > 0, Self.isIdentifier(source[start - 1]) {
                continue
            }
            var after = start + needle.count
            while after < source.count,
                source[after].isWhitespace
            {
                after += 1
            }
            guard after < source.count else { continue }
            if source[after] == "(" {
                found.append((start, after))
            } else if bare, source[after] == "{" {
                found.append((start, nil))
            }
        }
        return found
    }

    /// A mention of `spelling` that is not the tail of a
    /// longer identifier. No trailing boundary, deliberately:
    /// `NSAnimation` must go on catching `NSAnimationContext`.
    static func mentions(
        _ spelling: String,
        in source: [Character]
    ) -> Bool {
        let needle = Array(spelling)
        for start in source.indices
        where start + needle.count <= source.count
            && Array(source[start..<(start + needle.count)])
                == needle
        {
            if start > 0, isIdentifier(source[start - 1]) {
                continue
            }
            return true
        }
        return false
    }

    static func isIdentifier(_ character: Character)
        -> Bool
    {
        character.isLetter || character.isNumber
            || character == "_"
    }
}
