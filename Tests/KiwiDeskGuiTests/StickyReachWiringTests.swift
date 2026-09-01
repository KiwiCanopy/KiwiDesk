import Foundation
import Testing

@testable import KiwiDesk

/// The register of #1145's production wirings — the
/// `FollowFocusSeamTests` shape: the ledger is unit-tested, but
/// every hook that CALLS the refresh, and the bridge dispatch
/// itself, reaches no unit test (the bridge is deaf under
/// `swift test`), so deleting any one of them leaves the ledger
/// suites fully green while the feature silently stops at that
/// seam. A new refresh site joins this map in the same change.
@Suite("Sticky reach wiring")
struct StickyReachWiringTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    /// Needles over stripped source, per file. Where a needle
    /// runs THROUGH neighbouring statements, the neighbours are
    /// glue locating the hook (tests.md: a contiguous needle is
    /// not a value pin) — the assertion is that the refresh
    /// sits at that seam. This file is named in
    /// `WMBridgeSeamTests.scanExempt`: the bridge tokens below
    /// are scan strings, never calls.
    private static let needles: [String: [String]] = [
        "Sources/KiwiDeskCore/App/KiwiCore+StickyReach.swift": [
            // The dispatch closures hand the ledger the REAL
            // bridge ops, and their Bool outcomes fold back in.
            "add:{id,addsinWMBridge.addWindows([id],"
                + "to:Array(adds))}",
            "remove:{id,dropsinWMBridge.removeWindows([id],"
                + "from:Array(drops))}",
            // One home set per window per pass, wanted and
            // retiring alike.
            "homes[id]=windowServerHome(of:id,in:spaces)",
            // Both entry points gate on the capability.
            "funcrefreshStickyReach(){guardcanDriveDesktops",
            "funcrefreshStickyReach(spaces:[NativeSpace]){"
                + "guardcanDriveDesktops",
            // The override verb applies its write immediately.
            "state.stickyReachOverrides[focused]=nil}"
                + "refreshStickyReach()",
        ],
        "Sources/KiwiDeskCore/Profiles/KiwiCore+Desktops.swift": [
            // The eager refresh threads the handler's ONE
            // snapshot (profiles.md)…
            "refreshStickyReach(spaces:snapshot.spaces)",
            // …and the settle re-asserts after the arrivals
            // sweep, so a fresh Desktop gains its travelers.
            "eventLoop.reconcileOnScreenArrivals()"
                + "refreshStickyReach()",
        ],
        "Sources/KiwiDeskCore/App/KiwiCore+Events.swift": [
            // A restored sticky intent reaches its Desktops at
            // arrival.
            "ifstate.windows[window.id]?.isSticky==true{"
                + "refreshStickyReach()}",
            // A replug births fresh Desktops.
            "emitMonitorChange()refreshStickyReach()",
            // A destroyed window's ledger drops without
            // dispatch.
            "stickyReach.forget(id)",
            // …and a terminated app's whole roster does too.
            "case.appTerminated:"
                + "forgetTerminatedStickyReach()",
        ],
        "Sources/KiwiDeskCore/App/KiwiCore+RekeyEvent.swift": [
            "ifstate.windows[new]?.isSticky==true{"
                + "refreshStickyReach()}"
        ],
        "Sources/KiwiDeskCore/App/KiwiCore+Lifecycle.swift": [
            "retireStickyReach()"
        ],
        "Sources/KiwiDeskCore/Commands/KiwiCore+Commands.swift": [
            // The scope verbs apply the Desktop half too — the
            // needle runs THROUGH the refresh, since a call
            // deleted after the retile leaves every suite green.
            "state.setSticky(focused,scope)retile()"
                + "refreshStickyReach()"
        ],
        "Sources/KiwiDeskCore/Commands/KiwiCore+StickyCommands.swift": [
            // The toggle takes effect in both directions, NOW.
            "stickyStyle.desktopReach=flag"
                + "refreshStickyReach()"
        ],
        "Sources/KiwiDeskCore/App/KiwiCore+GuiConfig.swift": [
            // The Settings Save path replaces the settings —
            // this IS the row's apply (#1145 review blocker) —
            // and the refresh sits at the TAIL, after the pins
            // and `resolveSpaceDisplays()` a 📌 derivation
            // reads (re-review round 2).
            "resolveSpaceDisplays()retile(force:true)"
                + "emitSpaceChange()refreshStickyReach()"
        ],
        "Sources/KiwiDeskCore/Profiles/KiwiCore+ProfileResolution.swift": [
            // Both apply tails, distinguished by the override
            // re-registration each runs first — the profile one
            // passes the profile's tiers, the composed one nils.
            "profileIgnoreRules:profile.ignoreRules)"
                + "resolveSpaceDisplays()"
                + "retile(force:forceRetile)emitSpaceChange()"
                + "refreshStickyReach()",
            "profileIgnoreRules:nil)resolveSpaceDisplays()"
                + "retile(force:forceRetile)emitSpaceChange()"
                + "refreshStickyReach()",
        ],
        "Sources/KiwiDeskCore/App/KiwiCore+Reset.swift": [
            "loadConfig()resolveSpaceDisplays()"
                + "retile(force:true)emitSpaceChange()"
                + "refreshStickyReach()"
        ],
        "Sources/KiwiDeskCore/Commands/KiwiCore+SpaceCommands.swift": [
            // A cross-display re-home moves a 📌 window's
            // wanted Desktops with it — deferred so the
            // re-derivation reads the NEW membership.
            "defer{ifstate.windows[window]?.isSticky==true{"
                + "refreshStickyReach()}}"
        ],
        "Sources/KiwiDeskCore/Commands/KiwiCore+DesktopMove.swift": [
            // A Desktop move migrates the window's home —
            // possibly INTO an asserted space — and the async
            // move outruns the eager pass, so a deferred settle
            // re-derives once it lands (re-review round 2).
            "ifstate.windows[focused]?.isSticky==true{"
                + "refreshStickyReach()"
                + "deferred.schedule(.stickyReachSettle,"
        ],
    ]

    @Test("every production wiring survives at its seam")
    func wiringsAreDrawn() throws {
        for (file, wants) in Self.needles {
            let url = Self.root.appendingPathComponent(file)
            let source = SourceScan.stripComments(
                try String(contentsOf: url, encoding: .utf8)
            )
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")
            #expect(!wants.isEmpty)
            for want in wants {
                #expect(
                    source.contains(want),
                    Comment(
                        rawValue:
                            "\(file) lost its #1145 wiring: "
                            + want
                    )
                )
            }
        }
    }

    /// The Settings row is the one surfacing branch the resolver
    /// cannot see (gui.md's `surfacingBranchesAreDrawn` class):
    /// hidden without the bridge, never greyed.
    @Test("the sticky-reach row is drawn behind the capability")
    func settingsRowSurfaces() throws {
        let url = Self.root.appendingPathComponent(
            "Sources/KiwiDesk/Settings/Components/"
                + "GapsAndBorders/StickyMarkEditor.swift"
        )
        let source = SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        .replacingOccurrences(of: " ", with: "")
        .replacingOccurrences(of: "\n", with: "")
        #expect(
            source.contains(
                "ifmodel.canDriveDesktops{ToggleRow(label:L("
                    + "\"sticky.desktop_reach\","
            )
        )
    }

    /// The capability-PRESENT branch of the search filter — the
    /// mirrors are pinned false everywhere else, so without
    /// this the true side is exercised by nothing (#1145
    /// review). Process-global: sets the static and resets.
    @Test("the search index carries the row when the bridge is up")
    @MainActor
    func searchIndexesTheRowWithTheBridge() {
        let before = SettingsSearchIndex.canDriveDesktops
        defer { SettingsSearchIndex.canDriveDesktops = before }
        SettingsSearchIndex.canDriveDesktops = false
        #expect(
            !SettingsSearchIndex.indexes(
                .borders(.stickyDesktopReach)
            )
        )
        SettingsSearchIndex.canDriveDesktops = true
        #expect(
            SettingsSearchIndex.indexes(
                .borders(.stickyDesktopReach)
            )
        )
    }
}
