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
            // need the boundary, or `RevealTimelineView {`
            // answers for `TimelineView`.
            //
            // A DOT-PREFIXED needle is exempt, and getting that
            // wrong cost the gate clause its main shape: the
            // character before `.animation` is the last one of
            // the RECEIVER, so a boundary there refuses
            // `field.animation(…)` — every inline chain — and
            // leaves only calls whose receiver ended on the
            // previous line. The tree writes them at the start
            // of a chain line, so the count parity stayed exact
            // and hid it completely (guard-prover). The leading
            // `.` IS the boundary for those.
            if Self.needsBoundary(entry), start > 0,
                Self.isIdentifier(source[start - 1])
            {
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
            if needsBoundary(spelling), start > 0,
                isIdentifier(source[start - 1])
            {
                continue
            }
            return true
        }
        return false
    }

    /// Whether a needle needs a leading boundary at all. One
    /// starting with `.` carries its own, and applying a second
    /// refuses the receiver in front of it.
    ///
    /// **What the exemption trades**, stated here because the
    /// two rounds before it each documented a refinement's win
    /// and not its cost, and the undocumented half is what the
    /// next round found. With no leading boundary, a dotted
    /// needle matches on ANY receiver — so an ordinary call
    /// that merely shares the name answers for it:
    /// `Self.animation(for: step)`, a factory RETURNING an
    /// animation rather than starting one, reds as an ungated
    /// site, and a string literal quoting `field.animation(…)`
    /// reds too. That is the direction to trade in — it fails
    /// SHUT, and the alternative was a walk blind to every
    /// inline chain in the tree — but a shared animation
    /// factory is a plausible next file, and its author will
    /// arrive here (guard-prover).
    static func needsBoundary(_ needle: String) -> Bool {
        needle.first != "."
    }

    /// Whether `character` continues an identifier — the
    /// family's ONE copy of that predicate. `orDot` adds `.`,
    /// which `SourceScan+InterpolatedLabels` needs so a dotted
    /// path (`fileURL(`) does not read as a bare `L(` call.
    ///
    /// Three hand-spellings of this lived here before, and the
    /// difference between them is exactly the subtle part: this
    /// diff's own history is a dot-prefix mistake that cost the
    /// gate clause every inline call site for a commit, without
    /// moving a single count (code review, #1069).
    static func isIdentifier(
        _ character: Character,
        orDot: Bool = false
    ) -> Bool {
        character.isLetter || character.isNumber
            || character == "_" || (orDot && character == ".")
    }
}
