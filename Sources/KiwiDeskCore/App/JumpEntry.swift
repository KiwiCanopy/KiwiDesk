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

    /// Where the window is, as far as a pick is concerned.
    public enum Status: Sendable, Equatable {
        /// Tracked on a Desktop some screen shows.
        case shown
        /// Up on a Desktop no screen shows; `desktop` is its
        /// Mission Control number, a label only (profiles.md),
        /// nil where no reading named it.
        case away(desktop: Int?)
        case minimized
        case fullscreen
        case hidden
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

    public init(
        target: Target,
        pid: pid_t,
        app: String,
        title: String,
        space: SpaceID?,
        spaceIcon: SpaceGlyph?,
        status: Status
    ) {
        self.target = target
        self.pid = pid
        self.app = app
        self.title = title
        self.space = space
        self.spaceIcon = spaceIcon
        self.status = status
    }
}
