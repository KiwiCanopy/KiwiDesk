import Foundation

extension DesktopOverview {
    /// One shared Desktop's row across every screen (#3602): what
    /// its header draws, the Desktop's own, never one column's.
    public struct Row: Sendable, Equatable {
        /// The Desktop's native Space id, the same on every screen.
        public let native: SkyLight.SpaceID
        /// Its number across screens (`Desktop.label`).
        public let label: Int
        /// The profile its binding names, nil where none is bound.
        public let profile: String?
        /// Whether the screens show it now, read for the Desktop
        /// itself, never as "any column shows it".
        public let isShown: Bool

        public init(
            native: SkyLight.SpaceID,
            label: Int,
            profile: String?,
            isShown: Bool
        ) {
            self.native = native
            self.label = label
            self.profile = profile
            self.isShown = isShown
        }
    }

    /// The rows `screens` share: one per Desktop where Desktops are
    /// shared, two or more screens list them, and every screen
    /// lists the same set in the same order; else none.
    static func rows(
        of screens: [Screen],
        shared: Bool,
        isShown: (SkyLight.SpaceID) -> Bool
    ) -> [Row] {
        guard shared, screens.count > 1, let first = screens.first
        else { return [] }
        let natives = first.desktops.map(\.native)
        guard !natives.isEmpty, !natives.contains(0),
            screens.allSatisfy({ $0.desktops.map(\.native) == natives })
        else { return [] }
        return first.desktops.map {
            Row(
                native: $0.native,
                label: $0.label,
                profile: $0.profile,
                isShown: isShown($0.native)
            )
        }
    }
}
