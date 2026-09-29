import AppKit

/// Rendered item payload for AppBarOverlay (`KiwiCore.barItemText`, #294).
extension AppBarOverlay {
    public struct Item {
        public let id: WindowID
        /// App name for VoiceOver accessibility labeling (#901).
        public let name: String
        /// Display text resolved by driver (`KiwiCore.barItemText`).
        public let text: String
        public let icon: NSImage?
        /// App Font ligature to render instead of icon (#294).
        public let glyph: String?
        /// Grouped window count shown as badge.
        public let count: Int
        /// The windows the item stands for — its own, or a
        /// collapsed group's — which its menu names (#1518).
        public let members: [WindowID]
        /// The title was cut at `title_cap` (Core's verdict, the
        /// hover title's half of "hides text", #1514).
        public let titleCut: Bool

        public init(
            id: WindowID,
            name: String = "",
            text: String,
            icon: NSImage?,
            glyph: String? = nil,
            count: Int = 1,
            members: [WindowID]? = nil,
            titleCut: Bool = false
        ) {
            self.id = id
            self.name = name
            self.text = text
            self.icon = icon
            self.glyph = glyph
            self.count = count
            self.members = members ?? [id]
            self.titleCut = titleCut
        }
    }
}
