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
final class DesktopCueLedger {
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
    var onCue: @MainActor (DesktopSwitchCue) -> Void = { _ in }

    init() {}

    /// What a landing does with the debt: keep it for the next
    /// notification, or settle it — with a cue, or with none.
    enum Verdict: Equatable {
        case waiting
        case settled(DesktopSwitchCue?)
    }

    /// The one verdict on `owed` in `snapshot`. Past `bound` it
    /// settles with nothing; before its screen shows the target it
    /// waits; once shown it settles, with no cue on a non-user
    /// Space or a screen the core cannot name. Pure, so a fixture
    /// asserts it without a WindowServer.
    static func verdict(
        for owed: Owed,
        in snapshot: DesktopSnapshot,
        display: DisplayID?,
        loadedProfile: String?,
        now: Date
    ) -> Verdict {
        guard now.timeIntervalSince(owed.at) <= bound else {
            return .settled(nil)
        }
        guard snapshot.currentSpaces[owed.displayUUID] == owed.space
        else { return .waiting }
        guard snapshot.currentSpaceIsUser(on: owed.displayUUID),
            let display,
            let number = snapshot.number(of: owed.space)
        else { return .settled(nil) }
        let row = snapshot.spaces
            .filter { $0.displayUUID == owed.displayUUID && $0.isUser }
            .compactMap { snapshot.number(of: $0.id) }
            .sorted()
        guard let index = row.firstIndex(of: number) else {
            return .settled(nil)
        }
        return .settled(
            DesktopSwitchCue(
                display: display,
                number: number,
                position: index + 1,
                count: row.count,
                loadedProfile: loadedProfile
            )
        )
    }
}
