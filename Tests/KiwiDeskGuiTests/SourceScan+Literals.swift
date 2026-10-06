import Foundation

/// Quote-aware source scrubbing.
///
/// These live in the `SourceScan` family rather than beside their
/// caller for the reason that family exists: a second copy of a
/// walker that drifts silently changes what a guard observes.
extension SourceScan {
    /// Blanks comments AND string literals, keeping every
    /// character position and every newline so offsets and line
    /// numbers stay usable; a literal keeps its delimiters and
    /// loses its interior. It is `stripped`'s walk under the
    /// blanking policy, never a walk of its own: the toggle it
    /// used to carry knew neither `"""` nor `#"…"#` and darkened
    /// the rest of a file (#1320, `SourceScanBlankerTests`).
    ///
    /// The literal half matters on its own: a needle must not be
    /// satisfiable by a string that merely spells it, which is
    /// how an accessibility label once stood in for a layout.
    static func blankingCommentsAndLiterals(
        _ source: String
    ) -> String {
        stripped(Array(source), blanking: true)
    }
}
