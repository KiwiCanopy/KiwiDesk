import Foundation
import Testing

@testable import KiwiDesk

/// Structural 4f guards over the `SettingKey` census (#678):
/// one placement per key, no dead area or container, and every
/// area usable at rest. The locale resolution guard lives in
/// `SettingKeyLocaleTests`, the model parity guard in
/// `SettingKeyModelParityTests`.
@Suite("SettingKey census structure")
struct SettingKeyCensusTests {
    private let keys = SettingKey.allCases

    /// The tiers that put a row on a Settings surface. Derived
    /// here once; the shape test below is what keeps a new tier
    /// from silently straddling the boundary.
    private func hasSurface(_ tier: SettingTier) -> Bool {
        switch tier {
        case .atRest, .showMore, .immediate:
            return true
        case .luaOnly, .internalOnly, .outsideSettings:
            return false
        }
    }

    /// Every key resolves to exactly one placement: the switch
    /// guarantees "at least one", so the census half is that no
    /// two cases claim the same placement-table row.
    @Test func censusRowsAreUnique() {
        var seen: [String: SettingKey] = [:]
        for key in keys {
            let previous = seen.updateValue(key, forKey: key.id)
            #expect(
                previous == nil,
                "duplicate census row \(key.id)"
            )
        }
        #expect(keys.count == seen.count)
    }

    /// Placement and text agree with the tier: a surfaced row
    /// has an area, a container and a label; a surfaceless one
    /// has none of the three. `gatedBy` may only point at a
    /// surfaced row.
    @Test func placementShapeMatchesTier() {
        for key in keys {
            let placement = key.placement
            let text = key.text
            if hasSurface(placement.tier) {
                #expect(
                    placement.area != nil
                        && placement.container != nil
                        && text.label != nil,
                    "surfaced row \(key.id) lacks GUI fields"
                )
            } else {
                #expect(
                    placement.area == nil
                        && placement.container == nil
                        && text.label == nil,
                    "surfaceless row \(key.id) carries GUI data"
                )
            }
            if let gate = placement.gate {
                #expect(
                    hasSurface(placement.tier),
                    "surfaceless row \(key.id) carries a gate"
                )
                for owner in gate.settings {
                    #expect(
                        hasSurface(owner.placement.tier),
                        "\(key.id) gated by surfaceless row"
                    )
                    #expect(
                        owner != key,
                        "\(key.id) is gated by itself"
                    )
                }
                if case .anyOf(let owners) = gate {
                    #expect(
                        owners.count > 1,
                        "\(key.id): one-element anyOf"
                    )
                }
            }
            if placement.exemptFromContainerGate {
                #expect(
                    placement.container?.gate != nil,
                    "\(key.id): exempt but container ungated"
                )
            }
        }
    }

    /// A container-level gate names only surfaced owner rows,
    /// and an owner placed INSIDE the container it gates must
    /// carry `exemptFromContainerGate` — the escape is data,
    /// never an implicit rule, because a renderer that greys
    /// the owner with its container locks the gate shut.
    @Test func containerGatesNameSurfacedOwners() {
        var gated = 0
        for container in SettingsContainer.allCases {
            guard let gate = container.gate else { continue }
            gated += 1
            for owner in gate.settings {
                #expect(
                    hasSurface(owner.placement.tier),
                    "\(container) gated by surfaceless row"
                )
                if owner.placement.container == container {
                    #expect(
                        owner.placement.exemptFromContainerGate,
                        "gate owner \(owner.id) not exempt"
                    )
                }
            }
        }
        #expect(gated > 0)
    }

    /// No container is empty in either mode. A container's mode
    /// is its area's (`SettingsArea.minimumMode` — mode depth
    /// is per area, never per row), so the reduction is: every
    /// declared container carries at least one surfaced row.
    /// A container case nothing places into would render as an
    /// empty card the day views generate from the census.
    @Test func noContainerIsEmpty() {
        let used = Set(
            keys.compactMap { $0.placement.container }
        )
        for container in SettingsContainer.allCases {
            #expect(
                used.contains(container),
                "container \(container) has no surfaced rows"
            )
        }
    }

    /// Every declared area holds at least one surfaced row —
    /// a dead area case is a Home card with nothing behind it.
    @Test func noAreaIsEmpty() {
        let used = Set(keys.compactMap { $0.placement.area })
        for area in SettingsArea.allCases {
            #expect(
                used.contains(area),
                "area \(area) has no surfaced rows"
            )
        }
    }

    /// No area has zero at-rest rows: an area whose every row
    /// hides behind "Show more" opens as an empty-looking card.
    @Test func everyAreaHasAtRestRows() {
        var atRest: Set<SettingsArea> = []
        for key in keys where key.placement.tier == .atRest {
            if let area = key.placement.area {
                atRest.insert(area)
            }
        }
        for area in SettingsArea.allCases {
            #expect(
                atRest.contains(area),
                "area \(area) has no at-rest rows"
            )
        }
    }

    /// `SettingKey.allCases` is a hand concatenation —
    /// `CaseIterable` cannot synthesize it over associated
    /// values — so a sub-enum wired into the wrapper but
    /// forgotten there would compile (the id/placement/text
    /// switches force an arm, the static list does not) and its
    /// whole slice would silently drop out of every guard in
    /// these suites. Source pin: every wrapper case's sub-enum
    /// appears in the concatenation.
    @Test func allCasesConcatenatesEverySubEnum() throws {
        let file = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources")
            .appendingPathComponent("KiwiDesk")
            .appendingPathComponent("Settings")
            .appendingPathComponent("Census")
            .appendingPathComponent("SettingKey.swift")
        let source = try String(contentsOf: file, encoding: .utf8)
        let pattern = /case (\w+)\((\w+Key)\)/
        var wrapperCases = 0
        for match in source.matches(of: pattern) {
            wrapperCases += 1
            let needle =
                "\(match.2).allCases.map(Self.\(match.1))"
            #expect(
                source.contains(needle),
                "\(match.2) missing from SettingKey.allCases"
            )
        }
        // Vacuity pin: the wrapper declares its sub-enums in
        // this shape today; zero matches means the scan broke,
        // not that the census shrank.
        #expect(wrapperCases > 10)
    }
}
