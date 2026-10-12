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
        /// Mission Control number, a label only (profiles.md),
        /// nil where no reading named it.
        case away(desktop: Int?)
        case minimized
        case fullscreen
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

    public init(
        target: Target,
        pid: pid_t,
        app: String,
        title: String,
        space: SpaceID?,
        spaceIcon: SpaceGlyph?,
        status: Status,
        movesHere: Bool = false
    ) {
        self.target = target
        self.pid = pid
        self.app = app
        self.title = title
        self.space = space
        self.spaceIcon = spaceIcon
        self.status = status
        self.movesHere = movesHere
    }
}

/// What Jump to window shows, read at ONE instant when the panel
/// opens (#1875): the rows, and the Space the user is in — the
/// "here" a Move here lands in, named with the rows' own reading.
public struct JumpSnapshot: Sendable, Equatable {
    public let entries: [JumpEntry]
    public let here: SpaceID?
    public let hereIcon: SpaceGlyph?

    public init(
        entries: [JumpEntry],
        here: SpaceID?,
        hereIcon: SpaceGlyph?
    ) {
        self.entries = entries
        self.here = here
        self.hereIcon = hereIcon
    }
}

extension JumpEntry {
    /// Whether the row is a hidden app's rather than a window's.
    public var isHiddenApp: Bool {
        if case .hiddenApp = target { return true }
        return false
    }
}
