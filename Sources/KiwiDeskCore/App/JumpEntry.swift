import Foundation

/// One row of Jump to window (#1875): what Core knows about a
/// window — or a hidden app — and nothing the GUI narrates. The
/// panel builds its sentence from these facts (#96).
public struct JumpEntry: Sendable, Equatable {
    /// What a pick acts on.
    public enum Target: Sendable, Hashable {
        case window(WindowID)
        /// A hidden app: KiwiDesk knows no titles for its windows,
        /// so the row is the app's.
        case hiddenApp(pid_t)
    }

    /// Where the window is, as far as a pick is concerned; a
    /// hidden app's row is `.shown`, its target saying the rest.
    public enum Status: Sendable, Equatable {
        /// Tracked on a Desktop some screen shows — or a hidden
        /// app's row, which `isHiddenApp` tells apart.
        case shown
        /// Up on a Desktop no screen shows; `desktop` is its
        /// Mission Control number, counted across screens (#3103)
        /// — a label only (profiles.md), nil where no reading
        /// named it.
        case away(desktop: Int?)
        case minimized
        case fullscreen
        /// In the pocket (#2446): listed under its own section,
        /// after Hidden; a pick takes it out.
        case pocketed
    }

    public let target: Target
    public let pid: pid_t
    public let app: String
    /// Empty where KiwiDesk knows none — the panel shows the app.
    public let title: String
    /// Its Space — a sticky window's home, an away window's
    /// remembered one; nil where none is known.
    public let space: SpaceID?
    /// The Space's own icon, nil where it has none: the panel then
    /// shows the name alone rather than the id twice.
    public let spaceIcon: SpaceGlyph?
    public let status: Status
    /// Whether Move here would move the window into the current
    /// Space — the GUI draws the way there by it, never by its own
    /// reading of the gates `moveHere(_:)` applies.
    public let movesHere: Bool
    /// Why Swap here would trade nothing (#2885), nil where it
    /// trades: the GUI lights the swap's hint and words the row's
    /// reason by it alone.
    public let swapBlock: JumpSwapBlock?
    /// Why Move here would refuse the row, nil where it moves or
    /// has nothing to move (#2885).
    public let moveBlock: JumpMoveBlock?
    /// Whether a lens is on and this row's app is not one it holds:
    /// the row sits under "Other apps", after every member's (#2103
    /// ruling 36). False for every row while no lens is on.
    public let isOtherApp: Bool
    /// The screen a shown or away window is on where that is not
    /// the screen KiwiHub opened on (#2792); nil there, with one
    /// screen, and for every other status.
    public let screen: ScreenLabel?

    public init(
        target: Target,
        pid: pid_t,
        app: String,
        title: String,
        space: SpaceID?,
        spaceIcon: SpaceGlyph?,
        status: Status,
        movesHere: Bool = false,
        swapBlock: JumpSwapBlock? = nil,
        moveBlock: JumpMoveBlock? = nil,
        isOtherApp: Bool = false,
        screen: ScreenLabel? = nil
    ) {
        self.isOtherApp = isOtherApp
        self.screen = screen
        self.target = target
        self.pid = pid
        self.app = app
        self.title = title
        self.space = space
        self.spaceIcon = spaceIcon
        self.status = status
        self.movesHere = movesHere
        self.swapBlock = swapBlock
        self.moveBlock = moveBlock
    }
}

/// What Jump to window shows, read at ONE instant when the panel
/// opens (#1875): the rows, and the Space the user is in — the
/// "here" a Move here lands in, named with the rows' own reading.
public struct JumpSnapshot: Sendable, Equatable {
    public let entries: [JumpEntry]
    public let here: SpaceID?
    public let hereIcon: SpaceGlyph?
    /// Whether Swap here trades with a window in `here`; where that
    /// Space has no focus it trades with the global one (#2885), and
    /// no row draws a route to `here`.
    public let swapsInHere: Bool
    /// The app strip's apps, most recently used first (#3135).
    public let apps: [JumpApp]

    public init(
        entries: [JumpEntry],
        here: SpaceID?,
        hereIcon: SpaceGlyph?,
        swapsInHere: Bool = false,
        apps: [JumpApp]? = nil
    ) {
        self.entries = entries
        self.here = here
        self.hereIcon = hereIcon
        self.swapsInHere = swapsInHere
        self.apps = apps ?? JumpApp.listed(in: entries)
    }
}

/// Which tier a window ranks in (#1875, #1513 ▸ Ruling): an open
/// window — tracked or up on an away Desktop — before one put away
/// in the Dock, each by recency. The ONE rule Jump to window's list
/// and `move_here`'s pick share; hidden apps sit below both.
public enum JumpTier: Int, Comparable, CaseIterable, Sendable {
    case open
    case minimized

    public static func < (lhs: JumpTier, rhs: JumpTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Why KiwiHub's Swap here would trade nothing (#2885): the row's
/// window blocks it, or yours does. Core names it; the GUI words it.
public enum JumpSwapBlock: Sendable, Equatable {
    case floating
    case fullScreen
    case sticky
    case pocketed
    /// Tracked in no Space, so it holds no slot to trade.
    case unfiled
    case minimized
    case hiddenApp
    /// Up on another macOS Desktop, by its Mission Control number.
    case otherDesktop(Int?)
    /// The row is your own window.
    case yours
    case yoursFloating
    case yoursFullScreen
    case yoursSticky
    /// No window here to trade with.
    case nothingHere
}

/// Why Move here would refuse a row (#2885): full screen, or the
/// sticky gate keeping it where it is.
public enum JumpMoveBlock: Sendable, Equatable {
    case fullScreen
    case sticky
}

extension JumpEntry {
    /// Whether Swap here would trade the window with yours.
    public var swapsHere: Bool { swapBlock == nil }

    public var tier: JumpTier {
        status == .minimized ? .minimized : .open
    }

    /// Whether the row is the pocketed window's (#2446).
    public var isPocketed: Bool { status == .pocketed }

    /// Whether the row is a hidden app's rather than a window's.
    public var isHiddenApp: Bool {
        if case .hiddenApp = target { return true }
        return false
    }
}
