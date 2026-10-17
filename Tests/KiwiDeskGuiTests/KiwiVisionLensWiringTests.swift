import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The lens page's wiring (#2103 PR 7, rulings 29, 41, 46): the
/// sites a unit test of the decision cannot see. Source scans over
/// whitespace-squashed, comment-blanked source.
@Suite("KiwiVision lens page wiring")
struct KiwiVisionLensWiringTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
    private static let dir =
        "Sources/KiwiDesk/Settings/Components/KiwiVision/"

    private static func squashed(_ path: String) throws -> String {
        let source = try SourceScan.blankedSource(
            at: root.appendingPathComponent(path)
        )
        return source.split(whereSeparator: \.isWhitespace).joined()
    }

    /// The lens container draws a page per live lens rather than
    /// walking its list, as Profiles' containers do: the section
    /// mounts the selected lens's page, the strip a chip per lens.
    @Test("the lens container is bespoke, a page per live lens")
    func lensContainerIsBespoke() throws {
        let section = try Self.squashed(
            "Sources/KiwiDesk/Settings/Sections/KiwiVisionSection.swift"
        )
        #expect(section.contains("KiwiVisionLensPage(model:model,lens:lens)"))
        #expect(!section.contains("KiwiVisionRowOrder.lenses"))
        let strip = try Self.squashed(Self.dir + "KiwiVisionLensStrip.swift")
        #expect(strip.contains("ForEach(lenses,id:\\.name)"))
    }

    /// The selection parks on `nav`, read through its one coalesced
    /// reading by the section and the panel, its SIBLING (#1127).
    @Test("section, strip and panel read the one selection")
    func selectionIsCoalesced() throws {
        let read = "model.nav.kiwiVisionLensSelection(in:"
        let panel = try Self.squashed(
            Self.dir + "KiwiVisionPanelPreview.swift"
        )
        #expect(
            panel.contains(
                "lens:model.nav.kiwiVisionLensSelection(in:model.draftLenses)"
            )
        )
        for file in [
            "Sources/KiwiDesk/Settings/Sections/KiwiVisionSection.swift",
            Self.dir + "KiwiVisionLensStrip.swift",
        ] {
            #expect(try Self.squashed(file).contains(read), "\(file)")
        }
    }

    /// A landing names no lens: every KiwiVision anchor but the
    /// strip's lives on the Focused window page.
    @Test("a reveal into KiwiVision lands on Focused window")
    func revealClearsTheLens() throws {
        let reveal = try Self.squashed(
            "Sources/KiwiDesk/Settings/SettingsView+Reveal.swift"
        )
        #expect(
            reveal.contains(
                "ifresolved.destination==.kiwiVision{"
                    + "model.nav.kiwiVisionLens=nil}"
            )
        )
    }

    /// The add chip greys under a Lua-owned setup through the
    /// census row's resolver; the chips stay live.
    @Test("the add chip asks the lenses row's gate")
    func addChipIsGated() throws {
        let strip = try Self.squashed(Self.dir + "KiwiVisionLensStrip.swift")
        #expect(strip.contains(".inertReason(for:.kiwiVision(.lenses))"))
        #expect(strip.contains(".disabled(addReason!=nil)"))
    }

    /// The header's recorder needs the coordinator Shortcuts holds
    /// for its own rows, and suspends the hotkeys while armed.
    @Test("the lens page provides a recorder coordinator")
    func pageProvidesTheCoordinator() throws {
        let page = try Self.squashed(Self.dir + "KiwiVisionLensPage.swift")
        #expect(page.contains(".environmentObject(coordinator)"))
        #expect(page.contains("model.setRecorderArmed(armed)"))
    }

    /// New Lens… is offered where Settings can save a lens.
    @Test("KiwiHub offers New Lens… only to a GUI-managed setup")
    func newLensOfferIsWired() throws {
        let view = try Self.squashed(
            "Sources/KiwiDesk/Jump/JumpPanelController+View.swift"
        )
        #expect(view.contains("offersNewLens:core.isGuiManaged"))
    }

    /// The live blur and dark doors hand their `(for:)` twin the
    /// live look, so the plate and the Settings picture of the
    /// lens on read one door (borders.md ▸ the blur door).
    @Test("the live doors hand the one door the live look")
    func liveDoorsDelegate() throws {
        let core = try Self.squashed(
            "Sources/KiwiDeskCore/App/KiwiCore+Vision.swift"
        )
        #expect(core.contains("kiwiVisionDrawsBlur(for:visionLook)"))
        #expect(core.contains("kiwiVisionShowsDark(for:visionLook)"))
    }

    /// Clear after and the Reminder grey through `GreyOut`, which
    /// dims the row: a bare `.disabled` leaves a field showing only
    /// its placeholder looking live.
    @Test("Other apps' gated rows dim, not only disable")
    func gatedRowsDim() throws {
        let card = try Self.squashed(
            Self.dir + "KiwiVisionLensOtherAppsCard.swift"
        )
        #expect(
            card.contains("delayRow.modifier(GreyOut(active:!lens.keepFocus))")
        )
        #expect(
            card.contains(
                "reminderRow.modifier(GreyOut(active:!remindsAtAll))"
            )
        )
    }

    /// Every lens override has a row: a field added to
    /// `VisionLens.Overrides` resolves and saves, and without this
    /// would have no row on the page.
    @Test("every lens override field has a row")
    func overridesHaveRows() throws {
        let fields = Mirror(reflecting: VisionLens.Overrides()).children
            .compactMap(\.label)
        #expect(!fields.isEmpty)
        let page = try Self.squashed(
            Self.dir + "KiwiVisionLensOverrides.swift"
        )
        for field in fields {
            #expect(page.contains("\\.\(field)"), "\(field) has no row")
        }
    }
}
