import Foundation
import Testing

@testable import KiwiDesk

/// The register of #1145's production wirings — the
/// `FollowFocusSeamTests` shape: the ledger and the wanted-set
/// derivation are unit-tested, but every hook that CALLS the
/// refresh, and the bridge dispatch itself, reaches no unit test
/// (the bridge is deaf under `swift test`), so deleting any one
/// of them leaves `StickyReachTests` fully green while the
/// feature silently stops at that seam. A new refresh site joins
/// this map in the same change.
@Suite("Sticky reach wiring")
struct StickyReachWiringTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    /// Needles over stripped source, per file. Where a needle
    /// runs THROUGH neighbouring statements, the neighbours are
    /// glue locating the hook (tests.md: a contiguous needle is
    /// not a value pin) — the assertion is that the refresh
    /// sits at that seam.
    private static let needles: [String: [String]] = [
        "Sources/KiwiDeskCore/App/KiwiCore+StickyReach.swift": [
            // The dispatch pair, and the removal-side exclusion
            // of the window's own home — a removal naming the
            // space a window lives on takes it off its own
            // Desktop. The bridge token is split so the
            // `WMBridgeSeamTests` test-tree scan keeps watching
            // THIS file for a real bridge call while these scan
            // strings stay invisible to it.
            "WMBridge" + ".addWindows([id],to:Array(adds))",
            "letsafe=drops.subtracting(keep)",
            "WMBridge" + ".removeWindows([id],from:Array(safe))",
            // Both entry points gate on the capability.
            "funcrefreshStickyReach(){guardcanDriveDesktops",
            "funcrefreshStickyReach(spaces:[NativeSpace]){"
                + "guardcanDriveDesktops",
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
        ],
        "Sources/KiwiDeskCore/App/KiwiCore+RekeyEvent.swift": [
            "ifstate.windows[new]?.isSticky==true{"
                + "refreshStickyReach()}"
        ],
        "Sources/KiwiDeskCore/App/KiwiCore+Lifecycle.swift": [
            "retireStickyReach()"
        ],
        "Sources/KiwiDeskCore/Commands/KiwiCore+Commands.swift": [
            // The scope verbs apply the Desktop half too.
            "state.setSticky(focused,scope)retile()"
        ],
        "Sources/KiwiDeskCore/Commands/KiwiCore+StickyCommands.swift": [
            // The toggle takes effect in both directions.
            "stickyStyle.desktopReach=flag"
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

    /// The scope verbs' refresh sits AFTER the retile — one
    /// contiguous needle, since the two statements' order is the
    /// hook (the refresh reads the state the verb just wrote).
    @Test("the sticky verbs refresh after their retile")
    func verbsRefresh() throws {
        let url = Self.root.appendingPathComponent(
            "Sources/KiwiDeskCore/Commands/KiwiCore+Commands.swift"
        )
        let source = SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        .replacingOccurrences(of: " ", with: "")
        .replacingOccurrences(of: "\n", with: "")
        #expect(
            source.contains(
                "state.setSticky(focused,scope)retile()"
                    + "refreshStickyReach()"
            )
        )
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
}
