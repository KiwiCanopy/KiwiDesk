import Foundation

/// What the Desktop switch cue shows (#2142): the Desktop a
/// KiwiDesk switch landed on, on the screen that switched. Core
/// names it; the GUI draws the plate and speaks it (#96).
public struct DesktopSwitchCue: Equatable, Sendable {
    /// The screen that switched — the only one the plate draws on.
    public let display: DisplayID
    /// The Desktop's Mission Control number, global across
    /// screens: the label Mission Control draws and the number
    /// `focus_desktop` takes. A label, never a lookup key (#1147).
    public let number: Int
    /// 1-based place among that screen's Desktops — the filled dot.
    public let position: Int
    /// How many Desktops that screen has — one dot each.
    public let count: Int
    /// The profile this switch loaded through a Desktop binding;
    /// nil where the live profile stayed.
    public let loadedProfile: String?

    public init(
        display: DisplayID,
        number: Int,
        position: Int,
        count: Int,
        loadedProfile: String?
    ) {
        self.display = display
        self.number = number
        self.position = position
        self.count = count
        self.loadedProfile = loadedProfile
    }
}

/// The cue a KiwiDesk switch owes until the OS confirms it
/// (#2142): owed at the accepted set, paid by the switch handler
/// that sees the target shown, dropped past `bound`.
@MainActor
public final class DesktopCueLedger {
    struct Owed: Equatable {
        let displayUUID: String
        let space: SkyLight.SpaceID
        let at: Date
    }

    /// Past the ~120 ms a set takes to land and the notification
    /// that follows it; a switch never confirmed owes nothing.
    static let bound: TimeInterval = 2

    var owed: Owed?

    /// Fed every cue the handler pays; the GUI draws it.
    public var onCue: @MainActor (DesktopSwitchCue) -> Void = { _ in }

    init() {}

    /// The cue `owed` earns in `snapshot`, or nil: expired, its
    /// screen not showing the target yet, a non-user Space, or a
    /// screen the core cannot name. Pure, so a fixture asserts it
    /// without a WindowServer.
    static func cue(
        for owed: Owed,
        in snapshot: DesktopSnapshot,
        display: DisplayID?,
        loadedProfile: String?,
        now: Date
    ) -> DesktopSwitchCue? {
        guard now.timeIntervalSince(owed.at) <= bound,
            snapshot.currentSpaces[owed.displayUUID] == owed.space,
            snapshot.currentSpaceIsUser(on: owed.displayUUID),
            let display,
            let number = snapshot.number(of: owed.space)
        else { return nil }
        let row = snapshot.spaces
            .filter { $0.displayUUID == owed.displayUUID && $0.isUser }
            .compactMap { snapshot.number(of: $0.id) }
            .sorted()
        guard let index = row.firstIndex(of: number) else { return nil }
        return DesktopSwitchCue(
            display: display,
            number: number,
            position: index + 1,
            count: row.count,
            loadedProfile: loadedProfile
        )
    }
}
