import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

private typealias F = BootRestoreFixture

/// The restart restore's progress (#2133), published from the
/// cross-session match through the boot tail, its arrivals and its
/// title pass: placing while records wait, done at the settle or
/// once none waits, none when another arrangement goes live.
@Suite("Cross-session restore progress (#2133)", .serialized)
@MainActor
struct CrossSessionRestorePhaseTests: CrossSessionFixture {
    private func recording(_ core: KiwiCore) -> () -> [RestorePhase] {
        var seen: [RestorePhase] = []
        core.onRestorePhaseChange = { seen.append($0) }
        return { seen }
    }

    @Test(
        "Boot, an arrival and the settle count the windows back",
        .enabled(if: NSScreen.main != nil)
    )
    func countsUpToTheSettle() throws {
        let core = try #require(
            boot([
                window(10, "com.a", "A"),
                window(11, "com.ide", "One"),
                window(12, "com.ide", "Two"),
            ])
        )
        let seen = recording(core)
        leave(
            previous([
                (F.hidden, "com.a", "A"),
                (F.hidden, "com.ide", "Two"),
                (F.hidden, "com.ide", "One"),
                (F.hidden, "app.zen", "Zen Browser"),
            ]),
            in: core
        )
        arrange(core)
        core.handle(.windowCreated(window(30, "app.zen", "Zen Browser")))
        core.crossSessionSettlePass()
        #expect(
            seen() == [
                .placing(placed: 1, total: 4),
                .placing(placed: 2, total: 4),
                .done(placed: 4, total: 4),
            ]
        )
        #expect(core.restorePhase == .done(placed: 4, total: 4))
    }

    @Test(
        "The last arrival ends it before the settle",
        .enabled(if: NSScreen.main != nil)
    )
    func lastArrivalEndsIt() throws {
        let core = try #require(boot([]))
        let seen = recording(core)
        leave(previous([(F.hidden, "app.zen", "Zen Browser")]), in: core)
        arrange(core)
        core.handle(.windowCreated(window(30, "app.zen", "Zen Browser")))
        #expect(
            seen() == [
                .placing(placed: 0, total: 1),
                .done(placed: 1, total: 1),
            ]
        )
    }

    @Test(
        "A settle with windows still missing ends it, and stays ended",
        .enabled(if: NSScreen.main != nil)
    )
    func settleEndsWithWindowsMissing() throws {
        let core = try #require(boot([]))
        let seen = recording(core)
        leave(
            previous([
                (F.hidden, "app.zen", "Zen Browser"),
                (F.hidden, "com.emu", "Emulator"),
            ]),
            in: core
        )
        arrange(core)
        core.crossSessionSettlePass()
        // Still matched after the settle, but the line has ended.
        core.handle(.windowCreated(window(30, "app.zen", "Zen Browser")))
        #expect(space(core, 30) == F.hidden)
        #expect(
            seen() == [
                .placing(placed: 0, total: 2),
                .done(placed: 0, total: 2),
            ]
        )
    }

    @Test(
        "Everything placed at boot publishes nothing",
        .enabled(if: NSScreen.main != nil)
    )
    func allAtBootIsSilent() throws {
        let core = try #require(boot([window(10, "com.a", "A")]))
        let seen = recording(core)
        leave(previous([(F.hidden, "com.a", "A")]), in: core)
        arrange(core)
        #expect(seen().isEmpty)
        #expect(core.restorePhase == .none)
    }

    @Test(
        "Another arrangement going live drops it to none",
        .enabled(if: NSScreen.main != nil)
    )
    func arrangementChangeDropsIt() throws {
        let core = try #require(boot([]))
        let seen = recording(core)
        leave(previous([(F.hidden, "app.zen", "Zen Browser")]), in: core)
        arrange(core)
        let other = core.buildProfile(name: "Other", modes: nil)
        core.profiles.becameLive(other, fits: true)
        core.handle(.windowCreated(window(30, "app.zen", "Zen Browser")))
        #expect(seen() == [.placing(placed: 0, total: 1), .none])
    }
}
