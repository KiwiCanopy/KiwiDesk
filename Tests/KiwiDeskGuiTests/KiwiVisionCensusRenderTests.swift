import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The KiwiVision page against the census (#2103). Both cards walk
/// their order lists; Dim and Blur sit under a Reduce-transparency
/// container gate that exempts the dim, read from the environment
/// at the card (gui.md ▸ accessibility greys are container gates).
@Suite("KiwiVision render ↔ census parity")
struct KiwiVisionCensusRenderTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    private static func squashed(_ path: String) throws -> String {
        let source = try SourceScan.blankedSource(
            at: root.appendingPathComponent(path)
        )
        return source.split(whereSeparator: \.isWhitespace).joined()
    }

    private func censusRows(
        _ container: SettingsContainer
    ) -> Set<SettingKey> {
        Set(
            SettingKey.allCases.filter {
                $0.placement.area == .kiwiVision
                    && $0.placement.container == container
            }
        )
    }

    @Test("each container lists exactly its census rows")
    func listsMatchCensus() {
        for (container, order) in KiwiVisionRowOrder.byContainer {
            #expect(Set(order) == censusRows(container))
            #expect(order.count == Set(order).count)
        }
        let declared = Set(
            SettingKey.allCases
                .filter { $0.placement.area == .kiwiVision }
                .compactMap { $0.placement.container }
        )
        #expect(declared == Set(KiwiVisionRowOrder.byContainer.keys))
    }

    /// Dim, then Blur; the appearance on its own card.
    @Test("the rows keep their order")
    func rowOrder() {
        #expect(
            KiwiVisionRowOrder.levels
                == [.kiwiVision(.dim), .kiwiVision(.blur)]
        )
        #expect(
            KiwiVisionRowOrder.appearance == [.kiwiVision(.appearance)]
        )
        #expect(
            KiwiVisionRowOrder.clear
                == [.kiwiVision(.clearApp), .kiwiVision(.clearWallpaper)]
        )
    }

    /// Stays clear sits between Dim and blur and System appearance
    /// (#2103 ruling 18), and its card walks its list.
    @Test("the Stays clear card walks its list between the others")
    func clearCardWiring() throws {
        let section = try Self.squashed(
            "Sources/KiwiDesk/Settings/Sections/KiwiVisionSection.swift"
        )
        let levels = try #require(section.range(of: "KiwiVisionLevelsCard("))
        let clear = try #require(section.range(of: "KiwiVisionClearCard("))
        let look = try #require(
            section.range(of: "KiwiVisionAppearanceCard(")
        )
        #expect(levels.lowerBound < clear.lowerBound)
        #expect(clear.lowerBound < look.lowerBound)
        let card = try Self.squashed(
            "Sources/KiwiDesk/Settings/Components/KiwiVision/"
                + "KiwiVisionClearCard.swift"
        )
        #expect(
            card.contains("ForEach(KiwiVisionRowOrder.clear,id:\\.id){keyin")
        )
        #expect(
            card.contains("case.kiwiVision(.clearWallpaper):wallpaperRow")
        )
        #expect(card.contains("case.kiwiVision(.clearApp):appRow"))
    }

    /// With the wallpaper clear the caption and the spoken label
    /// say so, and the picture veils each hazed window instead.
    @Test("the caption names a clear wallpaper")
    @MainActor func captionNamesTheWallpaper() throws {
        try captionNamesTheApp()
        LocalizationManager.shared.select("en")
        let both = KiwiVisionEffect(dims: true, blurs: true, windowsOnly: true)
        #expect(both.caption.contains("wallpaper stays clear"))
        #expect(both.caption.contains("dimmed and blurred"))
        #expect(both.spoken(dimPercent: 60).hasSuffix("60%"))
        #expect(
            KiwiVisionEffect(dims: true, blurs: false, windowsOnly: true)
                .caption.contains("are dimmed;")
        )
        #expect(
            KiwiVisionEffect(dims: false, blurs: true, windowsOnly: true)
                .caption.contains("are blurred;")
        )
        let none = KiwiVisionEffect(
            dims: false,
            blurs: false,
            windowsOnly: true
        )
        #expect(none.caption.contains("changes nothing"))
        let scene = try Self.squashed(
            "Sources/KiwiDesk/Settings/Components/KiwiVision/"
                + "KiwiVisionScene.swift"
        )
        #expect(scene.contains("visionVeil.opacity(windowsOnly?0:veil)"))
        #expect(scene.contains("ifhazed,windowsOnly{"))
    }

    /// Reduce transparency greys the levels card as a unit, the
    /// dim exempt: the blur stands down there and the dim stays.
    @Test("the levels card is a Reduce-transparency container gate")
    func accessibilityGreysAreContainerGates() {
        #expect(
            SettingsContainer.kiwiVisionLevels.gate
                == .runtime(.reduceTransparency)
        )
        #expect(SettingsContainer.kiwiVisionAppearance.gate == nil)
        #expect(
            SettingKey.kiwiVision(.dim).placement
                .exemptFromContainerGate
        )
        #expect(
            !SettingKey.kiwiVision(.blur).placement
                .exemptFromContainerGate
        )
    }

    /// Every row is app-wide, so it greys only where `init.lua`
    /// owns the config, as the resolver answers.
    @Test("every row's gate is the Lua-owned one, resolved here")
    @MainActor func rowGates() {
        for key in KiwiVisionKey.allCases {
            #expect(
                SettingKey.kiwiVision(key).placement.gate
                    == .runtime(.luaOwnsConfig)
            )
        }
        #expect(
            KiwiVisionGates.resolved
                == Set(KiwiVisionKey.allCases.map(SettingKey.kiwiVision))
        )
        let owned = KiwiVisionGates(guiManaged: false)
        let managed = KiwiVisionGates(guiManaged: true)
        for key in KiwiVisionGates.resolved {
            #expect(owned.inertReason(for: key) == .appWideLuaOwned)
            #expect(managed.inertReason(for: key) == nil)
        }
    }

    /// The card walks its list, reads Reduce transparency from the
    /// environment, and greys each row through the census's
    /// exemption rather than a predicate of its own.
    @Test("the levels card walks its list under the gate")
    func levelsCardWiring() throws {
        let card = try Self.squashed(
            "Sources/KiwiDesk/Settings/Components/KiwiVision/"
                + "KiwiVisionLevelsCard.swift"
        )
        #expect(
            card.contains("ForEach(KiwiVisionRowOrder.levels,id:\\.id)")
        )
        #expect(
            card.contains(
                "@Environment(\\.accessibilityReduceTransparency)"
            )
        )
        #expect(
            card.contains(
                "reduceTransparency&&!key.placement"
                    + ".exemptFromContainerGate"
            )
        )
        #expect(card.occurrences(of: "GreyOut(active:greyed(key))") == 1)
        let appearance = try Self.squashed(
            "Sources/KiwiDesk/Settings/Components/KiwiVision/"
                + "KiwiVisionAppearanceCard.swift"
        )
        #expect(
            appearance.contains(
                "ForEach(KiwiVisionRowOrder.appearance,id:\\.id){keyin"
            )
        )
        #expect(
            appearance.occurrences(of: "appearanceRow") == 2,
            "the row draws once, from its key's case"
        )
        #expect(
            appearance.contains("case.kiwiVision(.appearance):appearanceRow")
        )
        #expect(
            card.contains("in:Self.dimRange")
                && card.contains("AppWideSettings.visionDimRange")
        )
    }

    /// The picture takes every verdict from Core: the blur through
    /// the plate's door, the veil through the plate's own dim
    /// mapping, the windows' appearance through the mode's ask —
    /// never the stored blur, nor Settings' own Appearance pick.
    @Test("the picture reads the plate's doors")
    func pictureReadsTheDoors() throws {
        let dir = "Sources/KiwiDesk/Settings/Components/KiwiVision/"
        let panel = try Self.squashed(dir + "KiwiVisionPanelPreview.swift")
        #expect(
            panel.occurrences(of: "model.core.kiwiVisionDrawsBlur") == 1
        )
        #expect(
            panel.contains("darkWindows=model.core.kiwiVisionShowsDark")
        )
        #expect(panel.contains("VisionPlateDim.opacity(forDim:"))
        #expect(!panel.contains("visionBlur"))
        let scene = try Self.squashed(dir + "KiwiVisionScene.swift")
        #expect(scene.contains("VisionPlateDim.opacity(forDim:"))
        #expect(scene.contains("SettingsTheme.visionVeil.opacity(veil)"))
        let plate = try Self.squashed(
            "Sources/KiwiDeskCore/Vision/VisionPlate.swift"
        )
        #expect(plate.contains("Float(VisionPlateDim.opacity(forDim:dim))"))
    }

    /// The veil goes between the hazed windows and the focused
    /// one, as the plate sits under the focused window's ring.
    @Test("the focused window draws above the veil")
    func focusedAboveVeil() throws {
        let scene = try Self.squashed(
            "Sources/KiwiDesk/Settings/Components/KiwiVision/"
                + "KiwiVisionScene.swift"
        )
        let hazed = try #require(scene.range(of: "grid(focusedLayer:false)"))
        let veil = try #require(
            scene.range(of: "visionVeil.opacity(windowsOnly?0:veil)")
        )
        let clear = try #require(scene.range(of: "grid(focusedLayer:true)"))
        #expect(hazed.lowerBound < veil.lowerBound)
        #expect(veil.lowerBound < clear.lowerBound)
    }

    /// Both pointer sentences place the Shortcuts link, and the
    /// bound one names the chord.
    @Test("the pointer places its link")
    @MainActor func pointerPlacesItsLink() {
        LocalizationManager.shared.select("en")
        let slot = CrossReferenceRow.linkSlot
        #expect(KiwiVisionPointer.prose(chord: nil).contains(slot))
        let bound = KiwiVisionPointer.prose(chord: "⌃⌥V")
        #expect(bound.contains(slot))
        #expect(bound.contains("⌃⌥V"))
    }

    /// The caption follows the two facts the picture draws.
    @Test("the caption says what the settings do")
    @MainActor func captionFollowsTheEffect() {
        LocalizationManager.shared.select("en")
        let none = KiwiVisionEffect(dims: false, blurs: false)
        #expect(none.caption.contains("changes nothing"))
        #expect(!none.caption.contains("Focus another window"))
        let both = KiwiVisionEffect(dims: true, blurs: true)
        #expect(both.caption.contains("dimmed and blurred"))
        #expect(both.caption.contains("Focus another window"))
        #expect(
            KiwiVisionEffect(dims: true, blurs: false).caption
                .contains("is dimmed.")
        )
        #expect(
            KiwiVisionEffect(dims: false, blurs: true).caption
                .contains("is blurred.")
        )
        #expect(both.spoken(dimPercent: 60).hasSuffix("60%"))
    }

    /// With the focused app's other windows clear, both sentences
    /// say so, and the picture's second document leaves the haze.
    @MainActor private func captionNamesTheApp() throws {
        LocalizationManager.shared.select("en")
        let app = KiwiVisionEffect(
            dims: true,
            blurs: true,
            windowsOnly: false,
            clearApp: true
        )
        #expect(app.caption.contains("focused app's windows"))
        #expect(app.caption.contains("its windows become the clear ones"))
        let both = KiwiVisionEffect(
            dims: true,
            blurs: false,
            windowsOnly: true,
            clearApp: true
        )
        #expect(both.caption.contains("Other apps' windows are dimmed;"))
        let scene = try Self.squashed(
            "Sources/KiwiDesk/Settings/Components/KiwiVision/"
                + "KiwiVisionScene.swift"
        )
        #expect(scene.contains("lethazed=!focused&&!clear"))
        let panel = try Self.squashed(
            "Sources/KiwiDesk/Settings/Components/KiwiVision/"
                + "KiwiVisionPanelPreview.swift"
        )
        #expect(panel.contains("letclearApp=model.appWide.visionClearApp"))
        #expect(panel.occurrences(of: "clearApp:clearApp") == 2)
        #expect(scene.contains("clear:clearApp,"))
    }
}
