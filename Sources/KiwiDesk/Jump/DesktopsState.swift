import Foundation
import KiwiDeskCore

/// A Space line on the Desktops side, by its indices into the
/// overview: screen column, Desktop card, line (#1229).
struct DesktopsPlace: Hashable {
    var screen: Int
    var desktop: Int
    var line: Int
}

/// What KiwiHub's Desktops side shows and where its selection is
/// (#1229): pure, so every key and click is testable without a
/// panel. Places are Space lines; inside one, a window is selected;
/// carried windows ride along until a drop or a cancel.
struct DesktopsState: Equatable {
    let overview: DesktopOverview
    /// The side's sizes for this overview (#3164): its icon slots
    /// per screen column, which the keys scroll by, and what the
    /// side draws.
    let geometry: DesktopsGeometry
    private(set) var place: DesktopsPlace?
    /// The selected window: non-nil while inside a Space.
    private(set) var window: WindowID?
    /// Picked windows, in pick order.
    private(set) var carried: [WindowID] = []
    private(set) var query = ""
    /// Each line's first shown slot, where it scrolled.
    private(set) var offsets: [DesktopsPlace: Int] = [:]

    var isInside: Bool { window != nil }
    var isCarrying: Bool { !carried.isEmpty }

    /// Opens on the Space line the KiwiHub area shows (#3572).
    init(overview: DesktopOverview, geometry: DesktopsGeometry) {
        self.overview = overview
        self.geometry = geometry
        place = Self.startPlace(in: overview)
    }

    private static func startPlace(
        in overview: DesktopOverview
    ) -> DesktopsPlace? {
        let screens = overview.screens
        guard !screens.isEmpty else { return nil }
        let screen = screens.firstIndex(where: \.isHere) ?? 0
        let desktops = screens[screen].desktops
        guard !desktops.isEmpty else { return nil }
        // Behind a full-screen Space, the Desktop the live Spaces
        // hold (#3486).
        let desktop =
            desktops.firstIndex(where: \.isShown)
            ?? desktops.firstIndex(where: \.holdsLive) ?? 0
        guard !desktops[desktop].spaces.isEmpty else { return nil }
        return DesktopsPlace(
            screen: screen,
            desktop: desktop,
            line: desktops[desktop].landingLine
        )
    }

    // MARK: Reading

    func desktop(_ place: DesktopsPlace) -> DesktopOverview.Desktop? {
        guard overview.screens.indices.contains(place.screen) else {
            return nil
        }
        let desktops = overview.screens[place.screen].desktops
        guard desktops.indices.contains(place.desktop) else { return nil }
        return desktops[place.desktop]
    }

    func line(_ place: DesktopsPlace) -> DesktopOverview.SpaceLine? {
        guard let desktop = desktop(place),
            desktop.spaces.indices.contains(place.line)
        else { return nil }
        return desktop.spaces[place.line]
    }

    var selectedLine: DesktopOverview.SpaceLine? { place.flatMap(line) }

    /// A line's windows as drawn: matches first, each part in its
    /// Space's order (#1229, #3624).
    func ordered(_ place: DesktopsPlace) -> [DesktopOverview.Window] {
        guard let windows = line(place)?.windows else { return [] }
        let hit = windows.filter { matches($0, at: place) }
        return hit + windows.filter { !matches($0, at: place) }
    }

    /// The icons `place`'s line shows at once; more fold into "+n".
    func slots(_ place: DesktopsPlace) -> Int {
        let slots = geometry.slots
        return slots.indices.contains(place.screen) ? slots[place.screen] : 1
    }

    /// The first slot a line shows.
    func offset(_ place: DesktopsPlace) -> Int {
        let count = ordered(place).count
        let stored = offsets[place] ?? 0
        return max(0, min(stored, count - slots(place)))
    }

    /// How many windows sit off each edge of the line's slots.
    func hidden(_ place: DesktopsPlace) -> (before: Int, after: Int) {
        let count = ordered(place).count
        let first = offset(place)
        return (first, max(0, count - first - slots(place)))
    }

    /// The selected window's index in its line, as drawn.
    var windowIndex: Int? {
        guard let window, let place else { return nil }
        return ordered(place).firstIndex { $0.id == window }
    }

    // MARK: Search

    /// Matches move to the front. Typing never acts: a selection
    /// still matching stays, one the query dims moves to the first
    /// match (#3624), and a selected window that no longer matches
    /// leaves the Space for its place.
    mutating func setQuery(_ text: String) {
        query = text
        offsets = [:]
        settle()
        reveal()
    }

    // MARK: Selection

    mutating func select(_ place: DesktopsPlace) {
        guard line(place) != nil else { return }
        self.place = place
        window = nil
    }

    /// Selects a window on `place`, entering its Space.
    mutating func select(window id: WindowID, in place: DesktopsPlace) {
        guard ordered(place).contains(where: { $0.id == id }) else {
            return
        }
        self.place = place
        window = id
        reveal()
    }

    /// Scrolls the selected window's line so the window shows.
    mutating func reveal() {
        guard let place, let index = windowIndex else { return }
        let first = offset(place)
        if index < first {
            offsets[place] = index
        } else if index >= first + slots(place) {
            offsets[place] = index - slots(place) + 1
        }
    }

    /// A "+n" click: the next hidden window on that side, opened.
    mutating func revealMore(_ place: DesktopsPlace, forward: Bool) {
        let drawn = ordered(place)
        let first = offset(place)
        let next = forward ? first + slots(place) : first - 1
        guard drawn.indices.contains(next) else { return }
        offsets[place] = forward ? first + 1 : first - 1
        select(window: drawn[next].id, in: place)
    }

    // MARK: Carrying

    /// Picks `id` up, or puts it back; the refusal where it cannot
    /// be picked up (#1229 ▸ Carrying).
    mutating func togglePick(_ id: WindowID) -> DesktopOverview.CarryBlock? {
        if let index = carried.firstIndex(of: id) {
            carried.remove(at: index)
            if carried.isEmpty { settle() }
            return nil
        }
        if let block = pickBlock(id) { return block }
        carried.append(id)
        return nil
    }

    /// Why ⌘↩ would refuse `id`; nil where it picks up or puts back.
    func pickBlock(_ id: WindowID) -> DesktopOverview.CarryBlock? {
        carried.contains(id) ? nil : overview.window(id)?.block
    }

    /// Puts every picked window back; a selection the query dims
    /// once nothing rides along moves to a match.
    mutating func cancelCarry() {
        carried = []
        settle()
    }

    /// Leaves the Space for its place.
    mutating func leave() { window = nil }

    /// Enters the selected place's Space on its last-focused window,
    /// or its first; false where it holds none.
    mutating func open() -> Bool {
        guard let place, let line = line(place) else { return false }
        let drawn = reachable(place)
        guard let first = drawn.first else { return false }
        let last = line.lastFocused.flatMap { id in
            drawn.first { $0.id == id }
        }
        select(window: (last ?? first).id, in: place)
        return true
    }
}
