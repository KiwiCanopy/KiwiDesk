import Foundation

/// The empty-display heal (#1175): a connected monitor is never
/// left with zero spaces. Runs at the tail of the one total
/// resolve every relocation path funnels through, so the Lua
/// pin that moves a screen's last space away and the dirty
/// profile whose spaces all belong to another screen are healed
/// at the same door.
extension KiwiCore {
    /// Seeds one space on every connected display the resolve
    /// left empty: a fresh number, the layout the starter setup
    /// opens that screen in (#1018), pinned to the monitor so the
    /// next resolve keeps it there. Heal, never refuse (owner,
    /// 2026-08-31): a refusal makes pin order matter and turns a
    /// valid-looking config into an error.
    ///
    /// Idempotent per monitor: a re-apply that reset the pins
    /// finds its earlier seed through `healedSpaces` and re-pins
    /// it, windows and all, rather than minting a second one —
    /// unless the profile now pins that space itself, which
    /// makes it the profile's.
    func healEmptyDisplays(mainID: DisplayID?) {
        let displays = state.workspaces.allDisplays
        let ordered = PositionalDisplays.ordered(
            displays,
            mainID: mainID
        )
        let leads = StarterAllocation.modes(
            sizes: StarterSetup.sizes(
                displays: displays,
                mainID: mainID
            )
        )
        for (position, display) in ordered.enumerated()
        where state.workspaces.spaces(on: display.id).isEmpty {
            let seed: SpaceID
            if let earlier = healedSpaces[display.fingerprint],
                state.workspaces[earlier] != nil,
                spacePins[earlier] == nil
            {
                seed = earlier
            } else {
                seed = nextFreeSpaceNumber()
                let mode = leads[position].first ?? .bsp
                state.workspaces.ensureSpace(seed, mode: mode)
                healedSpaces[display.fingerprint] = seed
            }
            spacePins[seed] = display.fingerprint
            mainSpaces.remove(seed)
            state.workspaces.assign(seed, to: display.id)
            onLog(
                "heal: display '\(display.name)' had no space — "
                    + "seeded space \(seed.raw)"
            )
        }
    }

    /// The smallest positive number no live space is called.
    private func nextFreeSpaceNumber() -> SpaceID {
        let taken = Set(
            state.workspaces.allSpaces.compactMap { Int($0.id.raw) }
        )
        var number = 1
        while taken.contains(number) { number += 1 }
        return SpaceID(number)
    }
}
