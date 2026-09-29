import Foundation

/// The Layout menu's rows (#752, #762, #1179): one per layout in
/// `allCases` order, the live one checked with "not saved to
/// profile" beneath it while it differs from the saved one, and
/// the Keep row, armed on any screen's drift. The status item's
/// Layout menu and a Space chip's (#1518) both build from this;
/// each supplies its own words (#96) and its own actions.
public enum LayoutModeRows {
    /// A mode row's look.
    public struct Entry: Equatable {
        public let mode: LayoutMode
        public let title: String
        public let symbol: String
        public let checked: Bool
        public let subtitle: String?
    }

    /// The menu's words, from whichever side draws it.
    public struct Words {
        public var name: @MainActor (LayoutMode) -> String
        public var unsaved: String

        public init(
            name: @escaping @MainActor (LayoutMode) -> String,
            unsaved: String
        ) {
            self.name = name
            self.unsaved = unsaved
        }
    }

    @MainActor
    public static func entries(
        live: LayoutMode?,
        drifted: Bool,
        words: Words
    ) -> [Entry] {
        LayoutMode.allCases.map { mode in
            let current = mode == live
            return Entry(
                mode: mode,
                title: words.name(mode),
                symbol: mode.symbol,
                checked: current,
                subtitle: current && drifted ? words.unsaved : nil
            )
        }
    }

    /// Whether a Space stands on a temporary layout: its live mode
    /// differs from a KNOWN saved one — an unknown never fakes one.
    public static func drifted(
        live: LayoutMode?,
        saved: LayoutMode?
    ) -> Bool {
        guard let live, let saved else { return false }
        return live != saved
    }

    /// Whether the Keep row is armed. Keep saves the whole live
    /// profile (#1179), so drift in any Space the menu shows or
    /// names arms it — every shown Space, and a chip's own.
    public static func keepArmed(drifts: [Bool]) -> Bool {
        drifts.contains(true)
    }

    /// Core's words for a menu Core draws — the keys the Settings
    /// window's own names use, so one translation serves both.
    @MainActor
    static var coreWords: Words {
        Words(
            name: { mode in
                switch mode {
                case .bsp: return L("layout.bsp.name", "BSP")
                case .stack: return L("layout.stack.name", "Stack")
                case .scrolling:
                    return L("layout.scrolling.name", "Scrolling")
                case .grid: return L("layout.grid.name", "Grid")
                case .monocle:
                    return L("layout.monocle.name", "Monocle")
                case .track: return L("layout.track.name", "Track")
                case .floating:
                    return L("layout.floating.name", "Floating")
                }
            },
            unsaved: L("menu.layout.unsaved", "not saved to profile")
        )
    }
}
