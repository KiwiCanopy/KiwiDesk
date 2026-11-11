import Foundation
import KiwiDeskCore

/// A Space line on the Desktops side, by its indices into the
/// overview: screen row, Desktop card, line (#1229).
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
    /// The icons a Space line shows at once; more fold into "+n".
    static let slots = 5

    let overview: DesktopOverview
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

    /// Opens on the Space line the KiwiHub screen shows.
    init(overview: DesktopOverview) {
        self.overview = overview
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
        let desktop = desktops.firstIndex(where: \.isShown) ?? 0
        let lines = desktops[desktop].spaces
        guard !lines.isEmpty else { return nil }
        let line = lines.firstIndex(where: \.isShown) ?? 0
        return DesktopsPlace(screen: screen, desktop: desktop, line: line)
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

    /// Whether `window` matches what is typed; everything does while
    /// nothing is.
    func matches(_ window: DesktopOverview.Window) -> Bool {
        guard !query.isEmpty else { return true }
        return window.app.localizedCaseInsensitiveContains(query)
            || window.title.localizedCaseInsensitiveContains(query)
    }

    /// A line's windows as drawn: matches first, each part in its
    /// Space's order (#1229 ▸ Search).
    func ordered(_ place: DesktopsPlace) -> [DesktopOverview.Window] {
        guard let windows = line(place)?.windows else { return [] }
        return windows.filter(matches) + windows.filter { !matches($0) }
    }

    /// Whether any window of the place matches; a place with none
    /// dims while a search is typed.
    func hasMatch(_ place: DesktopsPlace) -> Bool {
        query.isEmpty || ordered(place).contains(where: matches)
    }

    /// The first slot a line shows.
    func offset(_ place: DesktopsPlace) -> Int {
        let count = ordered(place).count
        let stored = offsets[place] ?? 0
        return max(0, min(stored, count - Self.slots))
    }

    /// How many windows sit off each edge of the line's slots.
    func hidden(_ place: DesktopsPlace) -> (before: Int, after: Int) {
        let count = ordered(place).count
        let first = offset(place)
        return (first, max(0, count - first - Self.slots))
    }

    /// The selected window's index in its line, as drawn.
    var windowIndex: Int? {
        guard let window, let place else { return nil }
        return ordered(place).firstIndex { $0.id == window }
    }

    // MARK: Search

    /// Matches move to the front; the selection stays where it is,
    /// and a selected window that no longer matches leaves the
    /// Space for its place.
    mutating func setQuery(_ text: String) {
        query = text
        offsets = [:]
        if let window, let found = overview.window(window), !matches(found) {
            self.window = nil
        }
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
        } else if index >= first + Self.slots {
            offsets[place] = index - Self.slots + 1
        }
    }

    /// A "+n" click: the next hidden window on that side, opened.
    mutating func revealMore(_ place: DesktopsPlace, forward: Bool) {
        let drawn = ordered(place)
        let first = offset(place)
        let next = forward ? first + Self.slots : first - 1
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

    mutating func cancelCarry() { carried = [] }

    /// Leaves the Space for its place.
    mutating func leave() { window = nil }

    /// Enters the selected place's Space on its last-focused window,
    /// or its first; false where it holds none.
    mutating func open() -> Bool {
        guard let place, let line = line(place) else { return false }
        let drawn = ordered(place)
        guard let first = drawn.first else { return false }
        let last = line.lastFocused.flatMap { id in
            drawn.first { $0.id == id && matches($0) }
        }
        select(window: (last ?? first).id, in: place)
        return true
    }
}
