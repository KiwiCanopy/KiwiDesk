import Testing

@testable import KiwiDeskCore

/// The pure folding behind the 3-level "Start KiwiDesk" control
/// (#576). The real `register()` / launchctl paths touch
/// `SMAppService` and launchd and can't run headless, but the
/// mapping the read-through control depends on — dual state →
/// `AutoStartLevel`, plus the availability/approval carry-through —
/// is pure and pinned here.
@Suite("Auto-start level folding (#576)")
struct AutoStartLevelTests {
    /// A loaded service wins (it is the `RunAtLoad` + `KeepAlive`
    /// superset); otherwise the login item alone is plain at-login,
    /// and neither is off.
    @Test("level folds the dual state, service as the superset")
    func levelMapping() {
        #expect(
            AutoStartManager.level(
                loginOn: false,
                serviceLoaded: false
            ) == .off
        )
        #expect(
            AutoStartManager.level(
                loginOn: true,
                serviceLoaded: false
            ) == .atLogin
        )
        #expect(
            AutoStartManager.level(
                loginOn: false,
                serviceLoaded: true
            ) == .atLoginWithAutoRestart
        )
        // Service loaded wins even with the login item also on —
        // `apply(.atLoginWithAutoRestart)` sets both, so this is the
        // steady state of the top level.
        #expect(
            AutoStartManager.level(
                loginOn: true,
                serviceLoaded: true
            ) == .atLoginWithAutoRestart
        )
    }

    @Test("status folds login + service into level")
    func statusLevel() {
        let idle = ServiceStatus(isLoaded: false, pid: nil)
        let loaded = ServiceStatus(isLoaded: true, pid: 42)
        #expect(
            AutoStartManager.status(
                login: .notRegistered,
                service: idle
            ).level == .off
        )
        #expect(
            AutoStartManager.status(
                login: .enabled,
                service: idle
            ).level == .atLogin
        )
        #expect(
            AutoStartManager.status(
                login: .enabled,
                service: loaded
            ).level == .atLoginWithAutoRestart
        )
    }

    /// An unregisterable copy carries its reason through so the GUI
    /// disables levels 2 *and* 3 (registerable == false), leaving
    /// only "Never" — the whole-toggle grey #342 already showed.
    @Test("unavailable reason gates the upper levels")
    func unavailableCarriesThrough() {
        let idle = ServiceStatus(isLoaded: false, pid: nil)
        let translocated = AutoStartManager.status(
            login: .unavailable(.translocated),
            service: idle
        )
        #expect(translocated.unavailable == .translocated)
        #expect(!translocated.registerable)

        let bare = AutoStartManager.status(
            login: .unavailable(.notBundled),
            service: idle
        )
        #expect(bare.unavailable == .notBundled)
        #expect(!bare.registerable)

        // A registerable copy leaves both upper levels selectable.
        #expect(
            AutoStartManager.status(
                login: .enabled,
                service: idle
            ).registerable
        )
    }

    /// `.requiresApproval` reads as on (level at-login) and raises
    /// the approval flag so the GUI keeps the "confirm in System
    /// Settings" jump.
    @Test("requiresApproval reads on and flags for the jump")
    func requiresApprovalCarriesThrough() {
        let idle = ServiceStatus(isLoaded: false, pid: nil)
        let status = AutoStartManager.status(
            login: .requiresApproval,
            service: idle
        )
        #expect(status.level == .atLogin)
        #expect(status.requiresApproval)
        // Enabled is on without the approval nag.
        #expect(
            !AutoStartManager.status(
                login: .enabled,
                service: idle
            ).requiresApproval
        )
    }
}

/// The two rows turn 14b draws over the one folded level
/// (#678 item 16).
///
/// The pair *login OFF + restart ON* names no reachable state —
/// the LaunchAgent writes `RunAtLoad` and `KeepAlive` together —
/// so splitting the picker into two toggles moved the constraint
/// rather than removing it. These hold the half that survives
/// when no view is involved: greying the Advanced row is what a
/// reader sees, and this is what a CLI verb, a restored
/// preference or a future caller hits.
@Suite("Auto-start row pair (#678 item 16)")
struct AutoStartRowPairTests {
    @Test("the impossible pair collapses to off")
    func impossiblePairIsRefused() {
        // The whole point: restart ON with login OFF must not
        // survive as a level. It is discarded, not honoured.
        #expect(
            AutoStartLevel.level(
                openAtLogin: false,
                restartOnCrash: true
            ) == .off
        )
        #expect(
            AutoStartLevel.level(
                openAtLogin: false,
                restartOnCrash: false
            ) == .off
        )
    }

    @Test("the two reachable pairs map to their levels")
    func reachablePairsMap() {
        #expect(
            AutoStartLevel.level(
                openAtLogin: true,
                restartOnCrash: false
            ) == .atLogin
        )
        #expect(
            AutoStartLevel.level(
                openAtLogin: true,
                restartOnCrash: true
            ) == .atLoginWithAutoRestart
        )
    }

    /// Round-trip over every case, derived from `allCases` rather
    /// than a hand-listed three: a fourth level added later must
    /// either round-trip or fail here, not be silently omitted
    /// from the pair vocabulary.
    @Test("every level round-trips through its own pair")
    func everyLevelRoundTrips() {
        for level in AutoStartLevel.allCases {
            #expect(
                AutoStartLevel.level(
                    openAtLogin: level.opensAtLogin,
                    restartOnCrash: level.restartsOnCrash
                ) == level,
                Comment(
                    rawValue:
                        "\(level) does not survive being split "
                        + "into two rows and folded back"
                )
            )
        }
    }

    /// Restart implies login for every level that offers it —
    /// stated as the superset relation rather than as a fact
    /// about the three cases that exist today.
    @Test("restart is a superset of opening at login")
    func restartImpliesLogin() {
        for level in AutoStartLevel.allCases
        where level.restartsOnCrash {
            #expect(level.opensAtLogin)
        }
    }
}
