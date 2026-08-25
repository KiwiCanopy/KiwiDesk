import Foundation

/// The native Desktop verbs (#884, unlocking #25/#26):
/// `focus_desktop`, `move_to_desktop` and
/// `move_to_desktop_and_follow` — the Desktop-side twins of
/// `focus_space` / `move_to_space(_and_follow)`, driven through
/// `WMBridge` on stock macOS with SIP on.
///
/// **A Desktop number is its Mission Control number**, the one
/// shown in Mission Control and the one `bind_profile_to_desktop`
/// keys on, resolved in ONE `desktopSnapshot()` reading. The verb
/// then acts on the display that Desktop lives on — a Desktop has
/// exactly one — which is #890's "a number resolves against one
/// display's list" principle with no second lookup: a switch
/// changes that display's current Desktop and nothing else's.
///
/// **Performed is not applied** (os-private-apis.md): the bridge
/// returns nothing a caller can trust. A switch is confirmed by
/// the OS's own switch notification, which runs
/// `handleDesktopChange` exactly as a swipe does; a move is
/// confirmed at reveal, when the moved window re-enters
/// Accessibility on its new Desktop and the newcomer rules place
/// it. Neither verb keeps a memory of what it asked for — the
/// composed KiwiDesk-space target (a pending assignment applied
/// by the reveal reconcile) is the one item that would, and it is
/// tracked on #890, not shipped here.
extension KiwiCore {
    /// The resolved target of a Desktop verb: the WindowServer
    /// space id and the identifier of the display it lives on.
    struct DesktopTarget: Equatable {
        let space: SkyLight.SpaceID
        let displayIdentifier: String
        /// Whether the Desktop is already the one its display
        /// shows — a switch to it is a no-op.
        let isCurrent: Bool
    }

    /// Resolves a 1-based Mission Control number against one
    /// topology reading, or nil when no user Desktop has it.
    static func desktopTarget(
        number: Int,
        in snapshot: DesktopSnapshot
    ) -> DesktopTarget? {
        let users = snapshot.spaces.filter(\.isUser)
        guard number >= 1, number <= users.count else { return nil }
        let space = users[number - 1]
        return DesktopTarget(
            space: space.id,
            displayIdentifier: space.displayUUID,
            isCurrent: snapshot.currentSpaces[space.displayUUID]
                == space.id
        )
    }

    /// A verb's parse: the target, or the response that refuses.
    private enum DesktopResolution {
        case target(DesktopTarget)
        case refused(CommandResponse)
    }

    /// The parse shared by the three verbs: the bridge must be
    /// present, the argument a number, the number a Desktop.
    private func resolveDesktopArgument(
        _ args: [JSONValue]
    ) -> DesktopResolution {
        guard WMBridge.isAvailable else {
            return .refused(
                .fail(
                    "Desktop commands need macOS's window-management "
                        + "bridge, which this macOS does not expose"
                )
            )
        }
        guard let number = args.first?.intValue, number >= 1 else {
            return .refused(.fail("expected Desktop number (1-based)"))
        }
        guard
            let target = Self.desktopTarget(
                number: number,
                in: NativeSpaces.desktopSnapshot()
            )
        else {
            return .refused(.fail("no Desktop \(number)"))
        }
        return .target(target)
    }

    /// `focus_desktop <n>` (#26): switches the Desktop's display
    /// to it. The OS notification that follows runs the same
    /// switch handling a swipe does — binding, Space memory,
    /// retile, `desktop_change`.
    func focusDesktop(_ args: [JSONValue]) -> CommandResponse {
        switch resolveDesktopArgument(args) {
        case .refused(let response):
            return response
        case .target(let target):
            switchDesktop(to: target)
            return .ok()
        }
    }

    /// `move_to_desktop <n>` / `move_to_desktop_and_follow <n>`
    /// (#25): moves the focused window to the Desktop, and with
    /// `follow` switches there after it. Without follow the
    /// window leaves Accessibility's view the moment it lands —
    /// KiwiDesk's state drops it as vanished, the same way a
    /// window carried away by a swipe is dropped — and it rejoins
    /// at reveal through the newcomer rules.
    ///
    /// The move always dispatches: whether the window is already
    /// on that Desktop is not knowable from a target that is
    /// current on ITS display — the window may sit on another
    /// display whose current Desktop is a different one — and
    /// the bridge treats a same-Desktop move as the no-op it is.
    /// Only the follow stands down when the display already
    /// shows the target (`switchDesktop`).
    func moveToDesktop(
        _ args: [JSONValue],
        follow: Bool
    ) -> CommandResponse {
        guard let focused = focusedWindowID else {
            return .fail("no focused window")
        }
        switch resolveDesktopArgument(args) {
        case .refused(let response):
            return response
        case .target(let target):
            if !WMBridge.moveWindows([focused], to: target.space) {
                return .fail("the Desktop bridge refused the move")
            }
            if follow {
                switchDesktop(to: target)
            }
            return .ok()
        }
    }

    /// The one copy of the switch dispatch. Stamps the switch
    /// at INTENT time, the way the OS handler stamps it on
    /// arrival: a focus report between this dispatch and the
    /// notification is the transition talking, not the user
    /// (`scheduleFocusFollow`'s guard).
    private func switchDesktop(to target: DesktopTarget) {
        guard !target.isCurrent else { return }
        lastDesktopSwitch = Date()
        if !WMBridge.setCurrentSpace(
            target.space,
            displayIdentifier: target.displayIdentifier
        ) {
            onLog("focus_desktop: the Desktop bridge refused the switch")
        }
    }
}
