import CoreGraphics
import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Screens area against the census (#678 Phase 3, turn 13b).
///
/// As in Profiles the promise is the WEAKER one: every container
/// here is a bespoke view, and in this area the reason is as
/// strong as it gets — the placement container is a PICTURE, so
/// its rows are positioned by the real display arrangement and
/// there is no reading order for a `ForEach` to walk. The order
/// lists record membership for the placement table and search.
@Suite("Screens render ↔ census parity")
struct ScreensCensusRenderTests {
    private func display(
        _ id: UInt32,
        _ name: String,
        x: CGFloat = 0,
        width: CGFloat = 1500
    ) -> Display {
        Display(
            id: DisplayID(id),
            name: name,
            frame: CGRect(x: x, y: 0, width: width, height: 1000)
        )
    }

    /// A picture with every kind of chip in it: one pinned, one
    /// automatic, one following main, and one pinned to hardware
    /// that is away.
    private var expander: ScreensFamilyRows {
        let left = display(1, "Left")
        let right = display(2, "Right", x: 1500)
        return ScreensFamilyRows(
            spaces: [
                SpaceID("code"), SpaceID("web"),
                SpaceID("chat"), SpaceID("media"),
            ],
            mainSpaces: [SpaceID("chat")],
            resolutions: [
                SpaceID("code"): .pinned(left.fingerprint),
                SpaceID("web"): .auto(right.fingerprint),
                SpaceID("chat"): .main,
                SpaceID("media"): .pinned("Away:1000x1000"),
            ],
            pins: [
                SpaceID("code"): left.fingerprint,
                SpaceID("media"): "Away:1000x1000",
            ],
            displays: [left, right]
        )
    }

    private func censusRows(
        _ container: SettingsContainer
    ) -> Set<SettingKey> {
        Set(
            SettingKey.allCases.filter {
                $0.placement.area == .screens
                    && $0.placement.container == container
                    && [.atRest, .showMore]
                        .contains($0.placement.tier)
            }
        )
    }

    @Test("each container renders exactly its census rows")
    func listsMatchCensus() {
        for (container, order) in ScreensRowOrder.byContainer {
            #expect(
                Set(order) == censusRows(container),
                Comment(
                    rawValue:
                        "\(container) drifted from the census — "
                        + "a row moves by editing the census, "
                        + "and the order list follows"
                )
            )
            #expect(
                order.count == Set(order).count,
                "\(container) lists a row twice"
            )
        }
    }

    @Test("the area holds only the containers it renders")
    func containersMatch() {
        let declared = Set(
            SettingKey.allCases
                .filter { $0.placement.area == .screens }
                .filter {
                    [.atRest, .showMore]
                        .contains($0.placement.tier)
                }
                .compactMap { $0.placement.container }
        )
        #expect(
            declared == Set(ScreensRowOrder.byContainer.keys)
        )
    }

    /// The bespoke claim, read off the TREE rather than restated
    /// against another literal.
    ///
    /// Stated limit: the needle is `ForEach(ScreensRowOrder.`,
    /// so a container walking a LOCAL COPY of a list passes. The
    /// `files.count` floor is what keeps the scan from passing
    /// over nothing at all.
    @Test("the bespoke containers really have no ForEach")
    func bespokeMeansNoForEach() throws {
        #expect(
            ScreensRowOrder.bespokeContainers
                == Set(ScreensRowOrder.byContainer.keys)
        )
        let root = SourceScan.repoRoot(from: #filePath)
        var files = try SourceScan.swiftSources(
            under: root.appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Screens"
            )
        )
        files += try SourceScan.swiftSources(
            under: root.appendingPathComponent(
                "Sources/KiwiDesk/Settings/Sections"
            )
        ).filter {
            $0.lastPathComponent.hasPrefix("ScreensSection")
        }
        // Assert the scan found its input before asserting about
        // it: an enumerator over a renamed directory yields [] and
        // every check below would pass for having looked at
        // nothing.
        //
        // Tight, not merely non-zero: at a floor of 10 the whole
        // `Sections/` half could stop being scanned and the
        // Components half alone would still clear it
        // (guard-prover, 2026-08-04).
        #expect(files.count >= 13)
        for file in files {
            let source = try SourceScan.blankedSource(at: file)
            let squashed = source.split(
                whereSeparator: \.isWhitespace
            ).joined()
            #expect(
                !squashed.contains("ForEach(ScreensRowOrder."),
                Comment(
                    rawValue:
                        "\(file.lastPathComponent) walks an order "
                        + "list — that container is no longer "
                        + "bespoke, and bespokeContainers must "
                        + "say so"
                )
            )
        }
    }

    /// Every key the area places expands to at least one row, and
    /// which keys draw NONE is data rather than a skipped branch.
    /// Here the set is EMPTY: every Screens key draws something,
    /// the banner included — it is one row whose presence is its
    /// gate's answer, not a family that lost its rows.
    @Test("every placed key expands to rows")
    func familiesExpand() {
        let drawsNothing: Set<SettingKey> = []
        let placed = SettingKey.allCases.filter {
            if case .screens = $0 { return true }
            return false
        }
        #expect(!placed.isEmpty)
        for key in placed {
            let rows = expander.rows(for: key)
            if drawsNothing.contains(key) {
                #expect(rows == nil)
            } else {
                #expect(
                    rows?.isEmpty == false,
                    Comment(
                        rawValue: "\(key.id) claims a row tier "
                            + "but expands to nothing"
                    )
                )
            }
        }
    }

    /// Each family expands once per INSTANCE. Set equality over
    /// `SettingKey` cannot see any of this: an expansion that
    /// collapsed to one row would still satisfy `familiesExpand`.
    @Test("families expand once per instance")
    func instanceCounts() {
        #expect(
            expander.rows(for: .screens(.spacePins))
                == [.space("code"), .space("web")]
        )
        #expect(
            expander.rows(for: .screens(.mainSpaces))
                == [.space("chat")]
        )
        #expect(
            expander.rows(for: .screens(.orphanPinClear))
                == [.orphan("media")]
        )
        #expect(
            expander.rows(for: .screens(.fingerprints))
                == [
                    .display("Left:1500x1000"),
                    .display("Right:1500x1000"),
                ]
        )
        #expect(
            expander.rows(for: .screens(.placementUnavailable))
                == [.banner]
        )
    }

    /// **Every space sits in exactly one place** (#53: there is no
    /// unassigned list). The three chip families partition the
    /// declared spaces — carded, following main, or waiting on an
    /// absent monitor — and nothing but this holds it: each
    /// family's own count is right in isolation while a space
    /// falls through all three, or shows up in two.
    @Test("the chip families partition the spaces")
    func everySpaceLandsExactlyOnce() {
        let carded = expander.rows(for: .screens(.spacePins))
        let tray = expander.rows(for: .screens(.mainSpaces))
        let orphans = expander.rows(
            for: .screens(.orphanPinClear)
        )
        let places =
            (carded ?? []).map(\.spaceName)
            + (tray ?? []).map(\.spaceName)
            + (orphans ?? []).map(\.spaceName)
        let named = places.compactMap { $0 }
        #expect(named.count == places.count)
        #expect(Set(named).count == named.count, "a space twice")
        #expect(
            Set(named) == Set(expander.spaces.map(\.raw)),
            "a space is drawn nowhere"
        )
    }

    /// The partition holds in the two cases that break it, and
    /// the plain fixture above cannot see either.
    ///
    /// Its two displays have distinct names, so dropping
    /// `cardedSpaces`' dedupe changes nothing there; and its
    /// orphaned pin is not a follows-main space, so dropping
    /// `orphans`' exclusion changes nothing either. Both fixes
    /// were invisible to the whole suite until this fixture
    /// (code review round 2, 2026-08-04).
    @Test("twins and double-assignment keep the partition")
    func partitionSurvivesAmbiguityAndOverlap() {
        // Two displays that are ONE identity to KiwiDesk, and a
        // space carrying both a stale pin and follows-main —
        // reachable from Lua, which does not keep them exclusive.
        let left = display(1, "Twin")
        let right = display(2, "Twin", x: 1500)
        let expander = ScreensFamilyRows(
            spaces: [
                SpaceID("code"), SpaceID("web"), SpaceID("both"),
            ],
            mainSpaces: [SpaceID("both")],
            resolutions: [
                SpaceID("code"): .pinned(left.fingerprint),
                SpaceID("web"): .auto(right.fingerprint),
                SpaceID("both"): .main,
            ],
            pins: [
                SpaceID("code"): left.fingerprint,
                SpaceID("both"): "Away:1000x1000",
            ],
            displays: [left, right]
        )
        #expect(expander.hasAmbiguousDisplays)
        let places =
            (expander.rows(for: .screens(.spacePins)) ?? [])
            + (expander.rows(for: .screens(.mainSpaces)) ?? [])
            + (expander.rows(for: .screens(.orphanPinClear))
                ?? [])
        let named = places.compactMap(\.spaceName)
        #expect(named.count == places.count)
        // Twins would otherwise claim `code` and `web` twice…
        #expect(Set(named).count == named.count, "a space twice")
        // …and the double-assigned space belongs to the tray, not
        // to the tray AND the orphan card.
        #expect(
            Set(named) == Set(expander.spaces.map(\.raw)),
            "a space is drawn nowhere"
        )
        #expect(
            expander.rows(for: .screens(.orphanPinClear))?
                .isEmpty == true
        )
    }

    /// A key outside `ScreensKey` expands to nil rather than to
    /// an empty list, so a renderer cannot mistake a foreign key
    /// for a family that lost its rows.
    @Test("a foreign key expands to nil")
    func foreignKey() {
        #expect(expander.rows(for: .spaces(.spaceList)) == nil)
    }
}

extension ScreensRowInstance {
    /// The space an instance names, for the partition guard.
    fileprivate var spaceName: String? {
        switch self {
        case .space(let name), .orphan(let name): return name
        case .display, .banner: return nil
        }
    }
}
