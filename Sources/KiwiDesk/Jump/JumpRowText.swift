import Foundation
import KiwiDeskCore

/// The words of a Jump to window row (#1875): Core hands over the
/// facts in a `JumpEntry` and the panel narrates them here (#96).
@MainActor
enum JumpRowText {
    /// One piece of the trailing column: a Space's glyph, when it
    /// has one, beside its words.
    struct Place: Equatable {
        let glyph: SpaceGlyph?
        let text: String
    }

    /// A Space's name: a numbered Space keeps the noun, a named one
    /// is its name.
    static func spaceName(_ id: SpaceID) -> String {
        guard Int(id.raw) != nil else { return id.raw }
        return L("jump.space.numbered", "Space %1$@", id.raw)
    }

    /// The trailing column at rest, nil where there is nothing to
    /// say. The Desktop shows only for a window on a Desktop its
    /// screen is not showing. A hidden app and a minimized window
    /// sit under their section's header, which says so; a
    /// minimized window names the Space it belongs to.
    static func place(of entry: JumpEntry) -> Place? {
        if entry.isHiddenApp { return nil }
        switch entry.status {
        case .minimized:
            return entry.space.map {
                Place(glyph: entry.spaceIcon, text: spaceName($0))
            }
        case .fullscreen:
            return Place(
                glyph: nil,
                text: L("jump.status.fullscreen", "Full Screen")
            )
        case .away(let desktop):
            return awayPlace(entry, desktop: desktop)
        case .shown:
            return entry.space.map {
                Place(glyph: entry.spaceIcon, text: spaceName($0))
            }
        }
    }

    /// The current Space, as ⇧ names it beside the source.
    static func here(of snapshot: JumpSnapshot) -> Place? {
        snapshot.here.map {
            Place(glyph: snapshot.hereIcon, text: spaceName($0))
        }
    }

    /// The frame ⇧ draws on the selected row: where it is, then
    /// where Move here takes it.
    static var wayHereFrame: String {
        L("jump.place.way_here", "%1$@ → %2$@")
    }

    /// The Hidden section's header — a key apart from a hidden
    /// app's spoken status, whose word agrees with one app, not
    /// many.
    static var hidden: String {
        L("jump.section.hidden", "Hidden")
    }

    /// The Minimized section's header, apart from a window's
    /// spoken status for the same reason.
    static var minimized: String {
        L("jump.section.minimized", "Minimized")
    }

    /// The footer's cue while the list runs past what it shows.
    static var scrollHint: String {
        L("jump.footer.scroll_hint", "Scroll for more windows")
    }

    /// What the row shows as its title: the window's title after
    /// its app, or the app alone where the window has none.
    static var titleFrame: String {
        L("jump.row.title", "%1$@ · %2$@")
    }

    /// The row as VoiceOver reads it: app, title, Space, Desktop.
    static func spoken(_ entry: JumpEntry) -> String {
        let place = spokenPlace(entry)
        switch (entry.title.isEmpty, place) {
        case (false, let place?):
            return L(
                "jump.row.ax.full",
                "%1$@, %2$@, %3$@",
                entry.app,
                entry.title,
                place
            )
        case (false, nil):
            return L(
                "jump.row.ax.titled",
                "%1$@, %2$@",
                entry.app,
                entry.title
            )
        case (true, let place?):
            return L(
                "jump.row.ax.placed",
                "%1$@, %2$@",
                entry.app,
                place
            )
        case (true, nil):
            return entry.app
        }
    }

    private static func awayPlace(
        _ entry: JumpEntry,
        desktop: Int?
    ) -> Place? {
        let name = entry.space.map(spaceName)
        switch (name, desktop) {
        case (let name?, let desktop?):
            return Place(
                glyph: entry.spaceIcon,
                text: L(
                    "jump.place.away",
                    "%1$@ · Desktop %2$d",
                    name,
                    desktop
                )
            )
        case (nil, let desktop?):
            return Place(glyph: nil, text: desktopName(desktop))
        case (let name?, nil):
            return Place(glyph: entry.spaceIcon, text: name)
        case (nil, nil):
            return nil
        }
    }

    private static func desktopName(_ number: Int) -> String {
        L("jump.place.desktop", "Desktop %1$d", number)
    }

    private static func spokenPlace(_ entry: JumpEntry) -> String? {
        if entry.isHiddenApp {
            return L("jump.status.hidden", "Hidden")
        }
        if entry.status == .minimized {
            return L("jump.status.minimized", "Minimized")
        }
        guard case .away(let desktop?) = entry.status,
            !entry.isHiddenApp
        else { return place(of: entry)?.text }
        guard let space = entry.space else {
            return desktopName(desktop)
        }
        return L(
            "jump.row.ax.away",
            "%1$@, Desktop %2$d",
            spaceName(space),
            desktop
        )
    }
}
