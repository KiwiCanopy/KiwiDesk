import Foundation
import KiwiDeskCore

/// A row's place on another screen (#2792): the screen is named
/// before the Desktop, a dot between every part, and last when
/// spoken.
extension JumpRowText {
    /// `Place.text` split around the screen's name.
    struct ScreenRun: Equatable {
        let lead: String
        let name: String
        let trail: String
    }

    /// Stands in for the screen's name in a frame, so the frame's
    /// own text can be split around it.
    private static let mark = "\u{FFFC}"

    static func shownPlace(
        _ entry: JumpEntry,
        space: SpaceID,
        screen: ScreenLabel
    ) -> Place {
        framed(
            L("jump.place.screen", "%1$@ · %2$@", spaceName(space), mark),
            glyph: entry.spaceIcon,
            screen: screen
        )
    }

    static func awayScreenPlace(
        _ entry: JumpEntry,
        name: String?,
        desktop: Int?,
        screen: ScreenLabel
    ) -> Place? {
        switch (name, desktop) {
        case (let name?, let desktop?):
            return framed(
                L(
                    "jump.place.away_screen",
                    "%1$@ · %2$@ · Desktop %3$d",
                    name,
                    mark,
                    desktop
                ),
                glyph: entry.spaceIcon,
                screen: screen
            )
        case (nil, let desktop?):
            return framed(
                L(
                    "jump.place.desktop_screen",
                    "%1$@ · Desktop %2$d",
                    mark,
                    desktop
                ),
                glyph: nil,
                screen: screen
            )
        case (let name?, nil):
            return framed(
                L("jump.place.screen", "%1$@ · %2$@", name, mark),
                glyph: entry.spaceIcon,
                screen: screen
            )
        case (nil, nil):
            return nil
        }
    }

    /// The spoken place of a row on another screen, nil for any
    /// other row.
    static func spokenScreenPlace(_ entry: JumpEntry) -> String? {
        guard let label = entry.screen else { return nil }
        let screen = label.displayName
        let name = entry.space.map(spaceName)
        let desktop: Int? = {
            if case .away(let desktop) = entry.status { return desktop }
            return nil
        }()
        switch (name, desktop) {
        case (let name?, let desktop?):
            return L(
                "jump.row.ax.away_screen",
                "%1$@, Desktop %2$d on %3$@",
                name,
                desktop,
                screen
            )
        case (nil, let desktop?):
            return L(
                "jump.row.ax.desktop_screen",
                "Desktop %1$d on %2$@",
                desktop,
                screen
            )
        case (let name?, nil):
            return L("jump.row.ax.screen", "%1$@ on %2$@", name, screen)
        case (nil, nil):
            return nil
        }
    }

    private static func framed(
        _ text: String,
        glyph: SpaceGlyph?,
        screen label: ScreenLabel
    ) -> Place {
        let name = label.displayName
        let parts = text.components(separatedBy: mark)
        guard parts.count == 2 else {
            return Place(
                glyph: glyph,
                text: text.replacingOccurrences(of: mark, with: name)
            )
        }
        return Place(
            glyph: glyph,
            text: parts[0] + name + parts[1],
            screen: ScreenRun(lead: parts[0], name: name, trail: parts[1])
        )
    }
}
