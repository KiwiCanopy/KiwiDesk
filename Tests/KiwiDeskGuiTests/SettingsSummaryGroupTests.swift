import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// One control, one change (#2450): the settings one control
/// writes together are one save-pill row while they agree, and one
/// row per changed member otherwise. Main-actor cost: one test
/// model per test, no scans. Locale pinned per body (#740).
@MainActor
@Suite("Summary groups fold in the save pill (#2450)")
struct SettingsSummaryGroupTests {
    private func pinEnglish() {
        LocalizationManager.shared.select("en")
    }

    private func gapRows(_ model: SettingsModel) -> [SettingsDiffRow] {
        SettingsDiffRowSource.rows(for: model).filter {
            if case .gaps = $0.key { return true }
            return false
        }
    }

    /// A master that only gates its followers — a switch, not a
    /// value they share — writes nothing to fold.
    private static let gatingMasters: Set<SettingKey> = [
        .colours(.animationsMaster)
    ]

    /// Every census master is a group, owns its followers outright
    /// (`masterWrites`) or only gates them.
    @Test("the groups are the masters whose followers list apart")
    func groupsMatchTheMasters() {
        let masters = Set(
            SettingKey.allCases.filter { $0.id.hasSuffix(" (master)") }
        )
        #expect(!SettingKey.summaryGroups.isEmpty)
        #expect(
            Set(SettingKey.summaryGroups.keys)
                == masters.subtracting(SettingKey.masterWrites.keys)
                .subtracting(Self.gatingMasters)
        )
    }

    /// A key added under a master's path joins its group, or one
    /// nudge lists it as a change of its own.
    @Test("every key under a master's path is a member")
    func membersAreComplete() {
        for (master, members) in SettingKey.summaryGroups {
            let base = master.id.replacingOccurrences(
                of: " (master)",
                with: ""
            )
            let under = SettingKey.allCases.filter {
                $0.id.hasPrefix(base + ".")
            }
            #expect(!under.isEmpty)
            #expect(Set(under) == Set(members), "\(master)")
        }
    }

    /// Every member's leaf, so a fixture can move one alone.
    private static let leaf:
        [SettingKey: WritableKeyPath<GuiConfig, CGFloat>] =
            [
                .gaps(.outerTop): \.settings.gapsGlobal.outer.top,
                .gaps(.outerBottom): \.settings.gapsGlobal.outer.bottom,
                .gaps(.outerLeft): \.settings.gapsGlobal.outer.left,
                .gaps(.outerRight): \.settings.gapsGlobal.outer.right,
                .gaps(.innerHorizontal):
                    \.settings.gapsGlobal.inner.horizontal,
                .gaps(.innerVertical): \.settings.gapsGlobal.inner.vertical,
                .behaviour(.minSizeStackWidth):
                    \.settings.minWindowSizes.stack.width,
                .behaviour(.minSizeStackHeight):
                    \.settings.minWindowSizes.stack.height,
                .behaviour(.minSizeFloatingWidth):
                    \.settings.minWindowSizes.floating.width,
                .behaviour(.minSizeFloatingHeight):
                    \.settings.minWindowSizes.floating.height,
            ]

    /// The fold names one value exactly when the master's own
    /// readout does, so a folded row never reads "mixed".
    @Test("the fold agrees with each master's readout")
    func foldAgreesWithTheReadout() {
        pinEnglish()
        let mixed = L("diff.value.mixed", "mixed")
        var fixtures = [GuiConfig()]
        for path in Self.leaf.values {
            var one = GuiConfig()
            one[keyPath: path] += 7
            fixtures.append(one)
        }
        var square = GuiConfig()
        square.settings.minWindowSizes = .init(all: .init(width: 4, height: 9))
        fixtures.append(square)
        var checked = 0
        for config in fixtures {
            for master in SettingKey.summaryAxes.keys {
                let readout = SettingsValueReadout.rows(
                    for: master,
                    old: config,
                    new: config
                ).first?.newValue
                #expect(
                    SettingKey.summarizes(master, in: config)
                        == (readout != mixed),
                    "\(master): \(readout ?? "nil")"
                )
                checked += 1
            }
        }
        #expect(
            checked == fixtures.count * SettingKey.summaryAxes.count
        )
    }

    /// An axis holds one kind of value: a group of one axis may mix
    /// edges, but a multi-axis group's axes split by the last path
    /// component (width, height).
    @Test("each axis of a multi-axis group is one kind")
    func axesAreHomogeneous() {
        var checked = 0
        for (master, axes) in SettingKey.summaryAxes where axes.count > 1 {
            checked += 1
            for axis in axes {
                let kinds = Set(
                    axis.map { $0.id.split(separator: ".").last ?? "" }
                )
                #expect(kinds.count == 1, "\(master): \(kinds)")
            }
        }
        // The minimum window size group is the multi-axis case.
        #expect(checked > 0)
    }

    @Test("every group is a master over members under its path")
    func groupsAreWellFormed() {
        for (master, members) in SettingKey.summaryGroups {
            #expect(members.count > 1)
            #expect(SettingsRevertRegister.writers[master] != nil)
            let base = master.id.replacingOccurrences(
                of: " (master)",
                with: ""
            )
            for member in members {
                #expect(member.id.hasPrefix(base + "."), "\(member)")
                #expect(member.summaryMaster == master)
            }
            // A master writing its members unconditionally would
            // never let them list apart.
            #expect(SettingKey.masterWrites[master] == nil)
        }
    }

    @Test("the outer slider's nudge is one Outer gap row")
    func outerNudgeIsOneRow() throws {
        pinEnglish()
        let model = makeTestModel(root: .advanced)
        model.config.settings.gapsGlobal.outer = .init(
            top: 14,
            bottom: 14,
            left: 14,
            right: 14
        )
        let rows = gapRows(model)
        let row = try #require(rows.first)
        #expect(rows.count == 1, "\(rows.map(\.key))")
        #expect(row.key == .gaps(.outer))
        #expect(row.newValue == "14 pt")
        #expect(row.revert == .census)
    }

    @Test("the inner slider's nudge is one Inner gap row")
    func innerNudgeIsOneRow() {
        pinEnglish()
        let model = makeTestModel(root: .advanced)
        model.config.settings.gapsGlobal.inner.horizontal = 3
        model.config.settings.gapsGlobal.inner.vertical = 3
        #expect(gapRows(model).map(\.key) == [.gaps(.inner)])
    }

    @Test("edges that differ list each changed edge alone")
    func differingEdgesListApart() {
        pinEnglish()
        let model = makeTestModel(root: .advanced)
        model.config.settings.gapsGlobal.outer.top = 2
        model.config.settings.gapsGlobal.outer.left = 4
        #expect(
            gapRows(model).map(\.key)
                == [.gaps(.outerTop), .gaps(.outerLeft)]
        )
    }

    /// The fold reads every member, not only the changed ones: one
    /// edge brought level with the rest is the whole group's row.
    @Test("one edge brought level with the rest folds the group")
    func levellingEdgeFolds() {
        pinEnglish()
        let model = makeTestModel(root: .advanced)
        model.cleanConfig.settings.gapsGlobal.outer.right = 4
        model.config = model.cleanConfig
        model.config.settings.gapsGlobal.outer.right =
            model.config.settings.gapsGlobal.outer.top
        #expect(gapRows(model).map(\.key) == [.gaps(.outer)])
    }

    @Test("a folded row's revert takes every edge back")
    func foldedRevertTakesAll() throws {
        pinEnglish()
        let model = makeTestModel(root: .advanced)
        let clean = model.cleanConfig.settings.gapsGlobal.outer
        model.config.settings.gapsGlobal.outer = .init(
            top: 30,
            bottom: 30,
            left: 30,
            right: 30
        )
        let row = try #require(gapRows(model).first)
        SettingsRevertRegister.writers[row.key]?.apply(model, nil)
        #expect(model.config.settings.gapsGlobal.outer == clean)
        #expect(SettingsRevertRegister.writers[row.key]?.takesGroup != true)
    }

    @Test("a live change of every edge is one live row")
    func liveRowFolds() throws {
        pinEnglish()
        let model = makeTestModel(root: .advanced)
        var saved = model.cleanConfig.settings
        saved.gapsGlobal.outer = .init(top: 2, bottom: 2, left: 2, right: 2)
        var live = model.cleanConfig.settings
        live.gapsGlobal.outer = .init(top: 9, bottom: 9, left: 9, right: 9)
        model.cleanConfig.settings = live
        model.config = model.cleanConfig
        // Each leaf is `saved` with that one edge live, as Core
        // hands it over.
        var leaves: [String: TilingSettings] = [:]
        let edges: [(String, WritableKeyPath<Gaps.Outer, CGFloat>)] = [
            ("top", \.top), ("bottom", \.bottom),
            ("left", \.left), ("right", \.right),
        ]
        for (name, edge) in edges {
            var one = saved
            one.gapsGlobal.outer[keyPath: edge] = 9
            leaves["gap.global.outer.\(name)"] = one
        }
        model.unsavedLive = UnsavedLiveSettings(
            saved: saved,
            live: live,
            leaves: leaves
        )
        let rows = SettingsDiffRowSource.rows(for: model)
        let row = try #require(rows.first)
        #expect(rows.count == 1, "\(rows.map(\.key))")
        #expect(row.key == .gaps(.outer))
        #expect(row.section == .live)
        // Its Keep carries the leaves of every edge.
        #expect(row.keepIDs.count == 4)
    }
}

/// The minimum window size master (#2237) folds per axis: one row
/// while every layout shares its width and its height.
@MainActor
@Suite("Minimum window size folds per axis (#2450)")
struct MinSizeSummaryTests {
    private func sizeRows(_ model: SettingsModel) -> [SettingKey] {
        SettingsDiffRowSource.rows(for: model).map(\.key).filter {
            if case .behaviour = $0 { return true }
            return false
        }
    }

    @Test("a master width nudge is one row")
    func widthNudgeIsOneRow() {
        LocalizationManager.shared.select("en")
        let model = makeTestModel(root: .advanced)
        model.setMinSize(420, axis: .width, for: nil)
        #expect(sizeRows(model) == [.behaviour(.minWindowSize)])
    }

    @Test("one layout's width is that row alone")
    func layoutEditListsApart() {
        LocalizationManager.shared.select("en")
        let model = makeTestModel(root: .advanced)
        model.setMinSize(420, axis: .width, for: .stack)
        #expect(sizeRows(model) == [.behaviour(.minSizeStackWidth)])
    }

    /// The master's readout says "mixed" while heights differ, so
    /// a width nudge then lists each layout's width.
    @Test("a width nudge over differing heights lists apart")
    func differingHeightsListApart() {
        LocalizationManager.shared.select("en")
        let model = makeTestModel(root: .advanced)
        model.cleanConfig.settings.minWindowSizes.stack.height = 150
        model.config = model.cleanConfig
        model.setMinSize(420, axis: .width, for: nil)
        #expect(sizeRows(model).count == 6)
        #expect(!sizeRows(model).contains(.behaviour(.minWindowSize)))
    }
}
