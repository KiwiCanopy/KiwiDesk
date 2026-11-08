import Foundation

/// What KiwiHub's Desktops side shows, read at ONE instant when the
/// side opens (#1229): every screen in its physical order, its
/// macOS Desktops, the KiwiDesk Spaces on each and their windows.
/// Facts only; the GUI words them (#96).
public struct DesktopOverview: Sendable, Equatable {
    public let screens: [Screen]
    /// The window the user is in, which "Move window there" moves.
    public let yours: WindowID?

    public init(screens: [Screen], yours: WindowID?) {
        self.screens = screens
        self.yours = yours
    }

    /// One connected screen's row.
    public struct Screen: Sendable, Equatable {
        public let display: DisplayID
        /// The screen's own name, shown even with one screen.
        public let name: String
        /// The screen with the menu bar.
        public let isMain: Bool
        /// The screen KiwiHub opened on.
        public let isHere: Bool
        public let desktops: [Desktop]

        public init(
            display: DisplayID,
            name: String,
            isMain: Bool,
            isHere: Bool,
            desktops: [Desktop]
        ) {
            self.display = display
            self.name = name
            self.isMain = isMain
            self.isHere = isHere
            self.desktops = desktops
        }
    }

    /// One macOS Desktop's card.
    public struct Desktop: Sendable, Equatable {
        /// The Desktop's native Space id.
        public let native: SkyLight.SpaceID
        /// Its number on its own screen, the label (#2792).
        public let label: Int
        /// The number a verb takes (`focus_desktop`), nil where no
        /// reading numbers it.
        public let number: Int?
        /// Whether its screen shows it now.
        public let isShown: Bool
        /// The profile its binding names, nil where none is bound.
        public let profile: String?
        public let spaces: [SpaceLine]

        public init(
            native: SkyLight.SpaceID,
            label: Int,
            number: Int?,
            isShown: Bool,
            profile: String?,
            spaces: [SpaceLine]
        ) {
            self.native = native
            self.label = label
            self.number = number
            self.isShown = isShown
            self.profile = profile
            self.spaces = spaces
        }
    }

    /// One KiwiDesk Space on a Desktop.
    public struct SpaceLine: Sendable, Equatable {
        /// Nil for the windows on this Desktop no Space holds yet.
        public let space: SpaceID?
        public let glyph: SpaceGlyph?
        public let mode: LayoutMode?
        /// Whether the Desktop shows this Space — on a hidden
        /// Desktop, the one it returns to.
        public let isShown: Bool
        public let marker: Marker?
        public let windows: [Window]
        /// The window this Space last focused on this Desktop.
        public let lastFocused: WindowID?

        public init(
            space: SpaceID?,
            glyph: SpaceGlyph?,
            mode: LayoutMode?,
            isShown: Bool,
            marker: Marker?,
            windows: [Window],
            lastFocused: WindowID?
        ) {
            self.space = space
            self.glyph = glyph
            self.mode = mode
            self.isShown = isShown
            self.marker = marker
            self.windows = windows
            self.lastFocused = lastFocused
        }
    }

    /// The Space marker the Space Bar draws (#1507, #1790).
    public enum Marker: Sendable, Equatable {
        case held
        case temporary
    }

    /// One window's icon on a Space line.
    public struct Window: Sendable, Equatable, Identifiable {
        public let id: WindowID
        public let pid: pid_t
        public let app: String
        public let title: String
        /// Why it cannot be picked up, nil where it can.
        public let block: CarryBlock?

        public init(
            id: WindowID,
            pid: pid_t,
            app: String,
            title: String,
            block: CarryBlock?
        ) {
            self.id = id
            self.pid = pid
            self.app = app
            self.title = title
            self.block = block
        }
    }

    /// Why a window cannot be picked up (#1229 ▸ Carrying).
    public enum CarryBlock: Sendable, Equatable {
        /// On a Desktop no screen shows (until #2884).
        case otherDesktop
        case pocketed
        case fullScreen
    }
}

extension DesktopOverview {
    /// Every window on the overview, by id.
    public func window(_ id: WindowID) -> Window? {
        for screen in screens {
            for desktop in screen.desktops {
                for line in desktop.spaces {
                    if let hit = line.windows.first(where: { $0.id == id }) {
                        return hit
                    }
                }
            }
        }
        return nil
    }
}
