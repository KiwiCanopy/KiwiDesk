import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// `resetSurfaces()` is a per-visit REGISTER, and registers are
/// what get forgotten: the third field joined it in #1127 with
/// nothing but a hand-listed test naming the same three, which
/// is parity-tests.md's threshold crossed — past two mirrors,
/// ship a forget-proof test rather than a fourth hand list.
///
/// The miss is silent and its cost is stated on the struct
/// itself: a per-visit landing that survives a reset is silently
/// promoted to a process-lifetime one, so the window re-opens on
/// the surface the last visit left. So the sweep is by
/// reflection over EVERY stored field, and a field that must
/// survive says so in `survivesReset` — the
/// `resolved` / `resolvedElsewhere` shape this area already
/// uses, where a new field landing in neither list reds.
@Suite("Settings navigation reset register")
struct SettingsNavigationResetTests {
    /// Fields a visit is meant to KEEP, each with its reason.
    /// A reveal is requested from outside and consumed by the
    /// apply that renders it; the flash pair and the reveal
    /// target belong to that same in-flight request, and the
    /// counter is monotonic by construction.
    private static let survivesReset: Set<String> = [
        "pendingReveal", "pendingModeNotice", "pendingScroll",
        "flash", "flashToken", "revealTarget", "homeReturnFocus",
    ]

    /// Every field set away from its fresh value, so a field the
    /// sweep reads as "cleared" was provably dirtied first.
    private func dirtied() -> SettingsNavigation {
        var nav = SettingsNavigation()
        nav.pendingReveal = SettingsAnchor(destination: .shortcuts)
        nav.pendingModeNotice = .shortcuts
        nav.pendingScroll = "anchor"
        nav.setRevealTarget("anchor")
        _ = nav.startFlash("anchor")
        nav.layoutModeTab = .stack
        nav.shortcutsLayer = "media"
        nav.spaceOverridesFocus = SpaceID("code")
        nav.homeReturnFocus = .shortcuts
        nav.navigationMovesFocus = true
        return nav
    }

    private func fields(
        _ nav: SettingsNavigation
    ) -> [String: String] {
        var out: [String: String] = [:]
        for child in Mirror(reflecting: nav).children {
            guard let label = child.label else { continue }
            out[label] = String(describing: child.value)
        }
        return out
    }

    @Test("every per-visit surface is cleared, or declared kept")
    func resetClearsEverySurface() {
        let fresh = fields(SettingsNavigation())
        let dirty = fields(dirtied())
        #expect(!fresh.isEmpty)
        // Vacuity: a field the fixture forgot to dirty would
        // read as cleared without the reset touching it.
        for (name, value) in fresh {
            #expect(
                dirty[name] != value,
                Comment(
                    rawValue: "\(name) was never dirtied, so "
                        + "this suite cannot tell whether "
                        + "resetSurfaces clears it"
                )
            )
        }
        var nav = dirtied()
        nav.resetSurfaces()
        let after = fields(nav)
        for (name, value) in after {
            if Self.survivesReset.contains(name) {
                #expect(
                    value != fresh[name],
                    Comment(
                        rawValue: "\(name) is declared to "
                            + "survive a visit but was cleared"
                    )
                )
            } else {
                #expect(
                    value == fresh[name],
                    Comment(
                        rawValue: "\(name) survived "
                            + "resetSurfaces — a per-visit "
                            + "landing promoted to a "
                            + "process-lifetime one, or a field "
                            + "that belongs in survivesReset"
                    )
                )
            }
        }
    }
}
