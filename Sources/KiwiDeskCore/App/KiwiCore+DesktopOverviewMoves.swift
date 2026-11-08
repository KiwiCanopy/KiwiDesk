import Foundation

/// What a pick on KiwiHub's Desktops side does (#1229). Each door
/// reads the Desktops afresh at the press and picks the route the
/// verbs a binding runs take — `move_to_space` onto a Desktop its
/// screen shows, `move_to_desktop` with its Space onto one it does
/// not (#2888) — naming the window, so the verbs' own gates refuse
/// and no pick acts on a focus it did not mean.
extension KiwiCore {
    /// Moves `window` into `space` on the Desktop `native`, and
    /// follows it where asked; whether the verb moved it.
    @discardableResult
    public func overviewMove(
        _ window: WindowID,
        into space: SpaceID,
        onDesktop native: SkyLight.SpaceID,
        follow: Bool
    ) -> Bool {
        let snapshot = desktopMemory.readDesktops()
        let id = JSONValue.number(Double(window.raw))
        let target = JSONValue.string(space.raw)
        if Self.isShown(native, in: snapshot) {
            let verb = follow ? "move_to_space_and_follow" : "move_to_space"
            return overviewSend(verb, [target, id])
        }
        guard let number = snapshot.number(of: native) else { return false }
        let verb =
            follow ? "move_to_desktop_and_follow" : "move_to_desktop"
        return overviewSend(verb, [.number(Double(number)), target, id])
    }

    /// Moves `window` to the Desktop `native`, into no named Space.
    @discardableResult
    public func overviewMove(
        _ window: WindowID,
        toDesktop native: SkyLight.SpaceID
    ) -> Bool {
        guard let number = desktopMemory.readDesktops().number(of: native)
        else { return false }
        return overviewSend(
            "move_to_desktop",
            [.number(Double(number)), .null, .number(Double(window.raw))]
        )
    }

    /// Goes to `space` on the Desktop `native`: directly where its
    /// screen shows it, else to the Space's last-focused window
    /// there, else to the Desktop.
    public func overviewJump(
        to space: SpaceID,
        onDesktop native: SkyLight.SpaceID,
        lastFocused: WindowID?
    ) {
        let snapshot = desktopMemory.readDesktops()
        if Self.isShown(native, in: snapshot) {
            overviewSend("focus_space", [.string(space.raw)])
        } else if let lastFocused {
            jump(to: .window(lastFocused))
        } else {
            overviewJump(toDesktop: native)
        }
    }

    /// Switches to the Desktop `native`, as a swipe would.
    public func overviewJump(toDesktop native: SkyLight.SpaceID) {
        guard let number = desktopMemory.readDesktops().number(of: native)
        else { return }
        overviewSend("focus_desktop", [.number(Double(number))])
    }

    /// Whether a screen shows `native` now; a reading with no
    /// Desktops (no SkyLight) has the one Desktop it shows.
    static func isShown(
        _ native: SkyLight.SpaceID,
        in snapshot: DesktopSnapshot
    ) -> Bool {
        guard let space = snapshot.spaces.first(where: { $0.id == native })
        else { return snapshot.spaces.isEmpty }
        return snapshot.currentSpaces[space.displayUUID].map {
            $0 == native
        } ?? space.isCurrent
    }

    /// One verb inside the user motion scope (#804); whether it ran.
    @discardableResult
    private func overviewSend(_ verb: String, _ args: [JSONValue]) -> Bool {
        withUserMotion { execute(verb, args: args) }.isSuccess
    }
}
