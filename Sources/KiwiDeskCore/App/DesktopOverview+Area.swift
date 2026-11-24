import Foundation

extension DesktopOverview {
    /// One area of a split screen on a Desktop's card (#3572): a
    /// run of the Desktop's Space lines under the area's name.
    /// Facts only; the GUI words the name (#96).
    public struct Area: Sendable, Equatable {
        /// The area's stored identity.
        public let key: ScreenAreaKey
        /// The user's own name, nil where the area has none.
        public let name: String?
        /// Its positional default, outer word first; nil where the
        /// split names none.
        public let position: [ScreenAreaPosition]?
        /// The area KiwiHub opened over.
        public let isHere: Bool
        /// Its lines, as indices into the Desktop's `spaces`.
        public let lines: Range<Int>

        public init(
            key: ScreenAreaKey,
            name: String?,
            position: [ScreenAreaPosition]?,
            isHere: Bool,
            lines: Range<Int>
        ) {
            self.key = key
            self.name = name
            self.position = position
            self.isHere = isHere
            self.lines = lines
        }
    }
}

extension DesktopOverview.Desktop {
    /// The area holding line `index`, nil on an unsplit screen and
    /// for the unfiled line.
    public func area(of index: Int) -> DesktopOverview.Area? {
        areas.first { $0.lines.contains(index) }
    }

    /// The line a pick of the whole Desktop lands on (#3572 ruling
    /// 5): the shown line of the area KiwiHub opened over, else the
    /// first area's; on an unsplit screen its shown line; else its
    /// first.
    public var landingLine: Int {
        let area = areas.first(where: \.isHere) ?? areas.first
        let range = area?.lines ?? spaces.indices
        return range.first { spaces[$0].isShown }
            ?? spaces.firstIndex(where: \.isShown) ?? 0
    }
}
