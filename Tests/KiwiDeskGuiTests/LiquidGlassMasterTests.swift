import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// What the one Liquid Glass row WRITES and SHOWS (#1307).
///
/// Nothing else can see either half. The census records one row
/// over three stored leaves, and a master that flips two of them
/// ships a switch whose whole claim — one finish across both
/// bars and the shortcuts panel — is false at the pixel on
/// whichever surface it missed. The `?` half matters for the
/// same reason: a boolean cannot show "two of three", so the
/// sentence is the only channel that state has.
@MainActor
@Suite("The Liquid Glass master")
struct LiquidGlassMasterTests {
    /// The default this suite reasons from (tests.md): all three
    /// ship OFF together, so an untouched config already agrees
    /// with what the row shows and the master never has to write
    /// to make that true. A panel defaulting ON would render
    /// glass beside a switch reading off.
    @Test("the shipped surfaces already agree")
    func shippedSurfacesAgree() {
        let settings = TilingSettings()
        #expect(settings.appBarStyle.liquidGlass == false)
        #expect(settings.spaceBarStyle.liquidGlass == false)
        #expect(settings.shortcutPanelLiquidGlass == false)
        #expect(
            LiquidGlassAgreement(settings: settings).differ
                == false
        )
    }

    @Test("the master writes all three surfaces")
    func masterFansOut() {
        for on in [true, false] {
            let model = makeTestModel()
            // Seed the OPPOSITE first, or the `false` pass
            // starts where it means to end and a setter that
            // writes nothing passes it.
            model.config.settings.appBarStyle.liquidGlass = !on
            model.config.settings.spaceBarStyle.liquidGlass = !on
            model.config.settings.shortcutPanelLiquidGlass = !on
            model.liquidGlassMaster.wrappedValue = on
            let settings = model.config.settings
            #expect(settings.appBarStyle.liquidGlass == on)
            #expect(settings.spaceBarStyle.liquidGlass == on)
            #expect(settings.shortcutPanelLiquidGlass == on)
        }
    }

    /// Both values of the choice, and the third leaf tested on
    /// its own: a guard that only ever flips all three at once
    /// is blind to a master that reads two of them.
    @Test("the master shows on only when all three are on")
    func masterShowsAllThree() {
        let model = makeTestModel()
        model.liquidGlassMaster.wrappedValue = true
        #expect(model.liquidGlassMaster.wrappedValue)
        model.config.settings.shortcutPanelLiquidGlass = false
        #expect(model.liquidGlassMaster.wrappedValue == false)
        model.config.settings.shortcutPanelLiquidGlass = true
        model.config.settings.spaceBarStyle.liquidGlass = false
        #expect(model.liquidGlassMaster.wrappedValue == false)
        model.config.settings.spaceBarStyle.liquidGlass = true
        model.config.settings.appBarStyle.liquidGlass = false
        #expect(model.liquidGlassMaster.wrappedValue == false)
    }

    /// The `?` predicate, at both its answers — and it is the
    /// SAME reading the row shows, so the switch and its
    /// explanation cannot contradict.
    @Test("divergence is seen only while they disagree")
    func divergenceSeen() {
        var settings = TilingSettings()
        #expect(!LiquidGlassAgreement(settings: settings).differ)
        settings.appBarStyle.liquidGlass = true
        settings.spaceBarStyle.liquidGlass = true
        settings.shortcutPanelLiquidGlass = true
        #expect(!LiquidGlassAgreement(settings: settings).differ)
        settings.spaceBarStyle.liquidGlass = false
        #expect(LiquidGlassAgreement(settings: settings).differ)
        #expect(
            !LiquidGlassAgreement(settings: settings).allOn
        )
    }

    /// A retired row is not a retired setting: both bar verbs
    /// still reach their leaves, which is what keeps #678 Phase
    /// 2's per-layout precedent standing.
    @Test("the two bar leaves stay Lua-reachable")
    func barLeavesStayLuaOnly() {
        #expect(
            SettingKey.appBar(.appBarLiquidGlass).placement
                == .luaOnly
        )
        #expect(
            SettingKey.spaceBar(.spaceBarLiquidGlass).placement
                == .luaOnly
        )
    }

    /// The panel's half of the switch, which no behavioural
    /// test can reach: `LiquidGlassMasterTests` never leaves the
    /// model, and the view is AppKit-hosted. Hardcode either end
    /// and the row keeps writing a leaf nothing reads — the
    /// user-visible half of #1307 gone, suite still green.
    ///
    /// Two needles because they are two different failures: the
    /// controller can stop READING the setting, and the view can
    /// stop HANDING it to the material.
    @Test("the panel is wired to the setting it stores")
    func panelReadsTheSetting() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Shortcuts")
        let files = try SourceScan.swiftSources(under: root)
        func source(_ name: String) throws -> String {
            let file = try #require(
                files.first { $0.lastPathComponent == name }
            )
            return SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            .split(whereSeparator: \.isWhitespace).joined()
        }
        #expect(
            try source("ShortcutsPanelController.swift")
                .contains("settings.shortcutPanelLiquidGlass"),
            """
            the controller no longer reads the stored leaf, so \
            the one Liquid Glass row cannot reach the panel.
            """
        )
        #expect(
            try source("ShortcutsPanelView.swift")
                .contains("enabled:liquidGlass"),
            """
            the panel no longer hands its setting to \
            `glassChrome`, so it draws one finish whatever the \
            row says.
            """
        )
    }

    /// DERIVED, not restated: walk what the edit actually
    /// MOVED and require it to equal what the census declares —
    /// a hand-typed copy of the same three strings agrees with
    /// the census and with nothing else (`rule-authoring.md`).
    /// `BorderMastersFanOutTests` owns this shape for the two
    /// border masters; the glass master needed its own, and
    /// `guard-prover` measured the gap: with the panel leaf
    /// deleted from `masterWrites`, `SettingsDraftDiffTests` and
    /// both border suites stayed green.
    @Test("the declaration matches what the master writes")
    func declarationMatchesTheWrite() {
        let key = SettingKey.colours(.liquidGlassMaster)
        let model = makeTestModel()
        let before = SettingsDraftDiff.leaves(of: model.config)
        model.liquidGlassMaster.wrappedValue = true
        let after = SettingsDraftDiff.leaves(of: model.config)
        let moved = Set(before.keys).union(after.keys)
            .filter { before[$0] != after[$0] }
        #expect(
            moved == Set(SettingKey.masterWrites[key] ?? []),
            Comment(
                rawValue:
                    "\(key.id) writes \(moved.sorted()) — "
                    + "SettingKey.masterWrites disagrees"
            )
        )
    }

    /// The sentence the declaration exists FOR: three leaves
    /// move, and the save pill books one change.
    @Test("one edit of the master counts once")
    func oneEditCountsOnce() {
        let key = SettingKey.colours(.liquidGlassMaster)
        let model = makeTestModel()
        let clean = model.config
        model.liquidGlassMaster.wrappedValue = true
        let diff = SettingsDraftDiff.between(
            config: model.config,
            cleanConfig: clean
        )
        #expect(diff.unattributed.isEmpty)
        #expect(diff.changedSettings == [key])
    }

    /// The CONSUMER, which the predicate tests are structurally
    /// blind to. `guard-prover` (2026-09-07) replaced the row's
    /// `agreement.differ ? differHelp : baseHelp` with
    /// `baseHelp` — the two-of-three state becomes invisible,
    /// which is the whole reason the sentence exists — and every
    /// test in the tree stayed green, `extract-keys` included,
    /// because `differHelp` remained a live call site.
    @Test("the row asks the agreement which help to show")
    func rowConsultsTheAgreement() throws {
        let file = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Colors/"
                    + "GlassCard.swift"
            )
        let source = SourceScan.stripComments(
            try String(contentsOf: file, encoding: .utf8)
        )
        .split(whereSeparator: \.isWhitespace).joined()
        #expect(
            source.contains("agreement.differ?differHelp"),
            """
            the row no longer picks its help from the \
            agreement, so a config with two of three surfaces \
            on says nothing about it.
            """
        )
    }

    /// A retired row can come back BESIDE the order list rather
    /// than in it, which the census read above cannot see:
    /// `guard-prover` hand-rolled a glass `ToggleRow` into
    /// `AppBarCard` and the whole 4884-test suite passed.
    @Test("no bar card draws a Liquid Glass toggle of its own")
    func barsDrawNoGlassToggle() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Bars"
            )
        let files = try SourceScan.swiftSources(under: root)
        #expect(files.count > 3)
        for file in files {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            .split(whereSeparator: \.isWhitespace).joined()
            #expect(
                !source.contains("isOn:style.liquidGlass"),
                Comment(
                    rawValue:
                        "\(file.lastPathComponent) draws a "
                        + "Liquid Glass toggle again — the one "
                        + "row lives on Colours & Animations "
                        + "and writes all three leaves (#1307)."
                )
            )
        }
    }
}
