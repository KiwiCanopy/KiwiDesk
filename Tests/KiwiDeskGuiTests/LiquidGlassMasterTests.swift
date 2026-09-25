import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// What the one Liquid Glass row WRITES and SHOWS (#1307).
///
/// Nothing else can see either half. The census records one row
/// over two stored leaves — the bars' shelf (one leaf since
/// #1517) and the shortcuts panel — and a master that flips one
/// ships a switch whose whole claim — one finish across the bars
/// and the panel — is false at the pixel on whichever surface it
/// missed. The `?` half matters for the same reason: a boolean
/// cannot show "one of two", so the sentence is the only channel
/// that state has.
@MainActor
@Suite("The Liquid Glass master")
struct LiquidGlassMasterTests {
    /// The default this suite reasons from (tests.md): both
    /// ship ON together (owner ruling 2026-09-10), so an untouched
    /// config already agrees with what the row shows and the
    /// master never has to write to make that true. A panel
    /// defaulting OFF would render no glass beside a switch
    /// reading on.
    @Test("the shipped surfaces already agree")
    func shippedSurfacesAgree() {
        let settings = TilingSettings()
        // Agreement, never the polarity: a retune of the default
        // must not red this (tests.md ▸ a clause pins the SHAPE).
        #expect(
            LiquidGlassAgreement(settings: settings).differ
                == false
        )
    }

    /// Every stored leaf the master writes — the shelf, the panel,
    /// the drag markers (#1620) and the sticky mark (#1621).
    private static let leaves: [WritableKeyPath<TilingSettings, Bool>] =
        [
            \.kiwishelf.liquidGlass,
            \.shortcutPanelLiquidGlass,
            \.dragLiquidGlass,
            \.stickyStyle.liquidGlass,
        ]

    /// The shipped default, pinned ONCE (#1369): the migration's
    /// premise is that absence now means on, so a revert of the
    /// flip reds here and nowhere else.
    @Test("the shipped default is on")
    func shippedDefaultIsOn() {
        let settings = TilingSettings()
        for leaf in Self.leaves { #expect(settings[keyPath: leaf]) }
    }

    @Test("the master writes every surface")
    func masterFansOut() {
        for on in [true, false] {
            let model = makeTestModel()
            // Seed the OPPOSITE first, or the `false` pass
            // starts where it means to end and a setter that
            // writes nothing passes it.
            for leaf in Self.leaves {
                model.config.settings[keyPath: leaf] = !on
            }
            model.liquidGlassMaster.wrappedValue = on
            let settings = model.config.settings
            for leaf in Self.leaves {
                #expect(settings[keyPath: leaf] == on, "\(leaf)")
            }
        }
    }

    /// Both values of the choice, and each leaf tested on its
    /// own: a guard that only ever flips both at once is blind to
    /// a master that reads one of them.
    @Test("the master shows on only when every leaf is on")
    func masterShowsEveryLeaf() {
        for leaf in Self.leaves {
            let model = makeTestModel()
            model.liquidGlassMaster.wrappedValue = true
            #expect(model.liquidGlassMaster.wrappedValue)
            model.config.settings[keyPath: leaf] = false
            #expect(
                model.liquidGlassMaster.wrappedValue == false,
                "\(leaf)"
            )
            #expect(
                LiquidGlassAgreement(settings: model.config.settings)
                    .differ,
                "\(leaf)"
            )
        }
    }

    /// The `?` predicate, at both its answers — and it is the
    /// SAME reading the row shows, so the switch and its
    /// explanation cannot contradict.
    @Test("divergence is seen only while they disagree")
    func divergenceSeen() {
        var settings = TilingSettings()
        #expect(!LiquidGlassAgreement(settings: settings).differ)
        settings.kiwishelf.liquidGlass = true
        settings.shortcutPanelLiquidGlass = true
        #expect(!LiquidGlassAgreement(settings: settings).differ)
        settings.kiwishelf.liquidGlass = false
        #expect(LiquidGlassAgreement(settings: settings).differ)
        #expect(
            !LiquidGlassAgreement(settings: settings).allOn
        )
    }

    /// A retired row is not a retired setting: the shelf's
    /// leaf still has its Lua verb, and no row of its own.
    @Test("the shelf's leaf stays Lua-reachable")
    func shelfLeafStaysLuaOnly() {
        #expect(
            SettingKey.kiwishelf(.liquidGlass).placement == .luaOnly
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
        // Flip AWAY from the shipped default rather than to a
        // literal, so a retuned default cannot make this a no-op.
        model.liquidGlassMaster.wrappedValue =
            !model.liquidGlassMaster.wrappedValue
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
        model.liquidGlassMaster.wrappedValue =
            !model.liquidGlassMaster.wrappedValue
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
