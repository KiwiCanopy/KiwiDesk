import AppKit

/// The peek body's geometry, split from `BarPeekBody.swift` at the
/// 350-line ceiling.
extension BarPeekBody {
    /// The peek's geometry and reading sizes, one home.
    enum Metrics {
        /// A fixed reading size, never the strip-depth ladders, or
        /// a thin bar's peek turns unreadable (#1946).
        static let textSize: CGFloat = 13
        /// The header's size: the menus' section header.
        static let headerSize: CGFloat = 11
        /// The whole panel's widest; a title wraps inside it.
        static let maxWidth: CGFloat = 280
        static let padH: CGFloat = 12
        static let padV: CGFloat = 9
        static let headerGap: CGFloat = 4
        /// Space either side of a hairline between two windows.
        static let rowGap: CGFloat = 5
        /// Space either side of a hairline between two apps.
        static let groupGap: CGFloat = 8
        static let iconSide: CGFloat = 16
        static let iconGap: CGFloat = 5
        /// The least room between a title and its Pocket key, the
        /// key's own column (#2923 ▸ Ruling 5).
        static let chordGap: CGFloat = 24
        /// The "more" line's chevron.
        static let chevronSide: CGFloat = 12
        static let cornerRadius: CGFloat = 11
        /// The gap between the bar's panel and the peek.
        static let stripGap: CGFloat = 6
        static let screenMargin: CGFloat = 8
        /// How far a button's hover fill reaches past its text.
        static let hoverPadH: CGFloat = 6
        static let hoverPadV: CGFloat = 3
        static let hoverRadius: CGFloat = 6
        /// The focused row's check (#2063), and its column past the
        /// titles' wrap width: the check plus a gap before it.
        static let checkSide: CGFloat = 12
        static let checkColumn: CGFloat = 16
    }
}
