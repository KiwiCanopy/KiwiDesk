import CoreGraphics
import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// KiwiHub's KiwiVision line after #2103 rulings 55–57 and #2359:
/// no Off chip — ↩, a click or a ⌘ digit on the CURRENT KiwiVision
/// chip turns KiwiVision off, which the footer, the chip's hint and
/// the line's spoken title say — and New Lens… last, which no ⌘
/// digit reaches.
@Suite("View picker KiwiVision line")
@MainActor
struct ViewPickVisionLineTests {
    private typealias Item = ViewPickList.Item

    private func list(
        vision: VisionActive = .plain,
        lenses: [String] = ["Writing"],
        selected pick: ViewPickList.Pick? = nil
    ) -> ViewPickList {
        let items = JumpPanelController.items(
            layout: nil,
            profiles: ("Laptop", ["Laptop", "Studio"], []),
            vision: (vision, lenses.map { VisionLensChoice(name: $0) }),
            visionChord: nil,
            lensChord: { _ in nil },
            offersNewLens: true,
            inert: nil
        )
        var list = ViewPickList(
            layout: nil,
            kiwiVisionOn: vision != .off,
            items: items
        )
        if let pick { list.select(pick) }
        return list
    }

    @Test("the current KiwiVision chip turns it off; others apply")
    func currentChipTurnsOff() {
        let on = list(vision: .lens("Writing"))
        let vision = on.items(.vision)
        let writing = vision[1]
        #expect(writing.isCurrent)
        #expect(ViewPickList.action(of: writing) == .visionOff)
        // A chip that is not on applies itself.
        #expect(
            ViewPickList.action(of: vision[0])
                == .vision(lens: nil)
        )
        // The current profile re-applies: only KiwiVision is off-able.
        let laptop = on.items(.profile)[0]
        #expect(laptop.isCurrent)
        #expect(
            ViewPickList.action(of: laptop)
                == .profile("Laptop")
        )
    }

    @Test("↩ and ⌘ digits route through the turn-off action")
    func keysTurnOff() {
        let model = JumpModel(
            snapshot: JumpSnapshot(
                entries: [JumpListTests.row(1, "Mail", "Inbox")],
                here: "1",
                hereIcon: nil
            ),
            icons: [:],
            rowCap: 8,
            pointer: .zero
        )
        model.currentPointer = { .zero }
        var applied: [ViewPickList.Pick] = []
        model.onApplyView = { applied.append($0) }
        model.loadView = { self.list(vision: .plain) }
        model.setScope(.view)
        model.view?.select(.vision(lens: nil))
        model.handle(.pick(moveHere: false), repeated: false)
        model.handle(.quick(0, moveHere: false), repeated: false)
        #expect(applied == [.visionOff, .visionOff])
    }

    /// Every View pick takes the model's one door, so a new door
    /// cannot re-apply the item already on instead of turning
    /// KiwiVision off.
    @Test("clicks and keys share the one apply door")
    func oneApplyDoor() throws {
        func squashed(_ path: String) throws -> String {
            try SourceScan.blankedSource(
                at: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent("Sources/KiwiDesk/Jump/" + path)
            ).split(whereSeparator: \.isWhitespace).joined()
        }
        let side = try squashed("JumpViewSide.swift")
        #expect(side.occurrences(of: "onActivate:{onApply(item)}") == 2)
        #expect(!side.contains("action(of:"))
        let panel = try squashed("JumpPanelView.swift")
        // A click selects, then takes the door (#2365).
        #expect(panel.contains("onApply:{model.clickItem($0)}"))
        let model = try squashed("JumpModel+View.swift")
        #expect(model.occurrences(of: "applyView(item)") == 3)
        #expect(model.contains("letaction=ViewPickList.action(of:item)"))
        #expect(model.contains("onApplyView(action)"))
        #expect(model.occurrences(of: "onApplyView(") == 1)
        // Nowhere else in KiwiHub calls past the door.
        let jump = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Jump")
        var calls = 0
        for file in try SourceScan.swiftSources(under: jump) {
            calls += try SourceScan.blankedSource(at: file)
                .split(whereSeparator: \.isWhitespace).joined()
                .occurrences(of: "onApplyView(")
        }
        #expect(calls == 1)
    }

    @Test("New Lens… is last and no ⌘ digit reaches it")
    func digitsSkipTheCreateChip() {
        LocalizationManager.shared.select("en")
        var list = list()
        let vision = list.items(.vision)
        #expect(vision.last?.pick == .newLens)
        let create = vision.count - 1
        #expect(list.number(.vision, create) == nil)
        #expect(list.digitOrder(.vision).count == vision.count - 1)
        list.select(.newLens)
        #expect(list.quick(create) == nil)
        // The filter still finds it by its label.
        list.setQuery("new lens")
        #expect(list.selected?.pick == .newLens)
    }

    /// ↓ keeps the column but never lands on a create chip while
    /// the line holds anything else (#2359 ruling 1).
    @Test("↓ never lands on New Lens…")
    func downSkipsTheCreateChip() {
        var list = list(lenses: [], selected: .profile("Studio"))
        #expect(
            list.items(.vision).map(\.pick) == [
                .vision(lens: nil), .newLens,
            ]
        )
        list.moveLine(1)
        #expect(list.selected?.pick == .vision(lens: nil))
    }

    @Test("the footer, the hint and the title say what ↩ does")
    func safeguardsSpeak() {
        LocalizationManager.shared.select("en")
        let on = list(vision: .plain, selected: .vision(lens: nil))
        #expect(on.selectionTurnsOff)
        #expect(!on.visionIsOff)
        let footer = JumpFooter(scope: .view, overflows: false, turnsOff: true)
        #expect(footer.hints.first == "↩ Turn Off")
        let plain = JumpFooter(scope: .view, overflows: false)
        #expect(plain.hints.first == "↩ Apply")
        let off = list(vision: .off, selected: .vision(lens: nil))
        #expect(!off.selectionTurnsOff)
        #expect(off.visionIsOff)
        // The turn-off hint comes ahead of the ⌘ hint (ruling 56).
        let current = on.items(.vision)[0]
        let chord = LayoutPickText.chordHint("⌘1")
        #expect(
            ViewPickText.hint(for: current, number: 1)
                == "\(ViewPickText.turnsOffHint), \(chord)"
        )
        #expect(
            ViewPickText.hint(for: current, number: nil)
                == ViewPickText.turnsOffHint
        )
        #expect(
            ViewPickText.hint(for: off.items(.vision)[0], number: 1) == chord
        )
        #expect(
            ViewPickText.spoken(
                off.items(.vision)[0],
                on: .vision,
                visionOff: off.visionIsOff
            ) == "KiwiVision, off: Default"
        )
    }

    @Test("New Lens… lands on the add popover")
    func newLensLanding() throws {
        let anchor = SettingsAnchor(landing: .newLens)
        #expect(anchor.destination == .kiwiVision)
        #expect(anchor.surface == .newLens)
        func squashed(_ path: String) throws -> String {
            try SourceScan.blankedSource(
                at: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent(path)
            ).split(whereSeparator: \.isWhitespace).joined()
        }
        let hub = try squashed(
            "Sources/KiwiDesk/Jump/JumpPanelController+View.swift"
        )
        #expect(
            hub.contains(
                "case.newLens:"
                    + "core.barMenuHooks.openSettings(.newLens)"
            )
        )
        let reveal = try squashed(
            "Sources/KiwiDesk/Settings/SettingsView+Reveal.swift"
        )
        #expect(
            reveal.contains(
                "case.newLens:model.nav.kiwiVisionAddRequested=true"
            )
        )
        let strip = try squashed(
            "Sources/KiwiDesk/Settings/Components/KiwiVision/"
                + "KiwiVisionLensStrip.swift"
        )
        #expect(strip.contains(".onAppear(perform:takeAddRequest)"))
        #expect(
            strip.contains(
                ".onChange(of:model.nav.kiwiVisionAddRequested)"
                    + "{takeAddRequest()}"
            )
        )
        // A landing opens the one add door, a turn later.
        #expect(strip.contains("DispatchQueue.main.async{openAdd()}"))
        #expect(strip.contains("Button(action:openAdd)"))
        #expect(
            strip.contains(
                "adding=NameEditRequest(seed:\"\",subject:\"\")"
            )
        )
    }

    @Test("the chip speaks its turn-off hint, and the line its state")
    func chipWiring() throws {
        let chip = try SourceScan.blankedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent("Sources/KiwiDesk/Jump/ViewChip.swift")
        ).split(whereSeparator: \.isWhitespace).joined()
        #expect(
            chip.contains(
                "privatevarhint:String{"
                    + "ViewPickText.hint(for:item,number:number)}"
            )
        )
        #expect(chip.contains(".accessibilityHint(hint)"))
        #expect(chip.contains("visionOff:visionOff"))
        let side = try SourceScan.blankedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(
                    "Sources/KiwiDesk/Jump/JumpViewSide.swift"
                )
        ).split(whereSeparator: \.isWhitespace).joined()
        #expect(side.contains("visionOff:list.visionIsOff"))
        let footer = try SourceScan.blankedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(
                    "Sources/KiwiDesk/Jump/JumpPanelView+Footer.swift"
                )
        ).split(whereSeparator: \.isWhitespace).joined()
        #expect(
            footer.contains("turnsOff:model.view?.selectionTurnsOff??false")
        )
    }
}
