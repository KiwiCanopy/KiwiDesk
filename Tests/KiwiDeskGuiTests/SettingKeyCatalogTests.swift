import Foundation
import Testing

@testable import KiwiDesk

/// Structural 4f guards over the `SettingKey` census (#678):
/// one placement per key, no dead area or container, and every
/// area usable at rest. The locale resolution guard lives in
/// `SettingKeyLocaleTests`, the model parity guard in
/// `SettingKeyModelParityTests`.
@Suite("SettingKey catalog structure")
struct SettingKeyCatalogTests {
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
        }
    }

    /// No container is empty in either mode. A container's mode
    /// is its area's (`SettingsArea.isNerdOnly` — mode depth is
    /// per area, never per row), so the reduction is: every
    /// declared container carries at least one surfaced row.
    /// A container case nothing places into would render as an
    /// empty card the day views generate from the catalog.
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
}
