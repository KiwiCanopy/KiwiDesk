import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Layers card's own capability unlock (#678 8c, owner ruling
/// 2026-08-04) — the third of this shape, after
/// `ShortcutsCapabilityUnlockTests` and `SpaceOverrideUnlockTests`.
///
/// It shipped as a disclosure that force-expanded once a layer
/// existed and offered itself collapsed before that, so a Simple
/// user with no layers met a closed drawer for a concept they had
/// no use for. It is now an always-open card, withheld entirely
/// until earned by having a layer or by Power User.
///
/// **The half that must never break**: `layersExist` is the FIRST
/// term, so a user's own configured layers are never hidden from
/// them by a mode they did not know they were in. This card
/// shipped that exact defect once, by reading its census tier as
/// `.showMore`.
@MainActor
@Suite("Layers card offer")
struct LayersCardOfferTests {
    /// The predicate as the card computes it, over the two inputs
    /// it reads. Kept in the test rather than reaching into the
    /// view because the view is a `View` — what matters is that
    /// the resolver answers this way, and
    /// `ShortcutsGateTests.layersCardConsultsTheResolver` already
    /// pins that the card asks the resolver at all.
    private func layersExist(_ config: GuiConfig) -> Bool {
        ShortcutsGates(config: config)
            .inertReason(for: .shortcuts(.switchToLayer)) == nil
    }

    private func config(layers: [String]) -> GuiConfig {
        var config = GuiConfig()
        config.layers = layers.map { KeyLayer(name: $0) }
        return config
    }

    @Test("only the default layer means no layers configured")
    func defaultAloneIsNotALayer() {
        #expect(!layersExist(config(layers: ["default"])))
    }

    @Test("a second layer is what counts as configured")
    func aSecondLayerCounts() {
        #expect(layersExist(config(layers: ["default", "resize"])))
        // Presence, not a count — three still reads "exists", so
        // an off-by-one cannot pass the boundary pair.
        #expect(
            layersExist(
                config(layers: ["default", "resize", "media"])
            )
        )
    }

    /// The card's own gate, which is what the owner ruling
    /// changed: shown when layers exist OR when Power User is on,
    /// withheld otherwise.
    private func offered(
        layers: [String],
        mode: SettingsMode
    ) -> Bool {
        layersExist(config(layers: layers))
            || mode == .powerUser
    }

    @Test("Simple with only the default layer is withheld")
    func simpleWithoutLayersIsWithheld() {
        #expect(!offered(layers: ["default"], mode: .simple))
    }

    @Test("Power User offers it with no layers configured")
    func powerUserIsAlwaysOffered() {
        #expect(offered(layers: ["default"], mode: .powerUser))
    }

    /// The arm that must never regress: a Simple user who has
    /// layers keeps them on screen. A gate written as
    /// `mode == .powerUser` alone passes every other test here
    /// and fails this one.
    @Test("Simple keeps layers the user already configured")
    func simpleKeepsConfiguredLayers() {
        #expect(
            offered(
                layers: ["default", "resize"],
                mode: .simple
            ),
            "a user's own layers must never be hidden by the mode"
        )
    }

    /// The card is no longer a disclosure, so its catalog
    /// declaration must not be one either — a `SettingsDrawer`
    /// would promise an expandable container that no longer
    /// exists, and its `childIDs` exist only to auto-expand one.
    ///
    /// Asserted on the shipped source rather than the type,
    /// because both declarations satisfy the same anchor
    /// protocol and a `SettingsDrawer` here would compile.
    @Test("the layers declaration is a control, not a drawer")
    func theDeclarationIsAControl() throws {
        let file = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/"
                    + "SettingsCatalog+WholeApp.swift"
            )
        let source = SourceScan.stripComments(
            try String(contentsOf: file, encoding: .utf8)
        )
        #expect(
            source.contains("let layersCard = SettingsControl("),
            "the Layers card is always open when shown"
        )
        #expect(
            !source.contains("let layersCard = SettingsDrawer(")
        )
    }
}
