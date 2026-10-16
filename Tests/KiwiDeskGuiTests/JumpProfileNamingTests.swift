import CoreGraphics
import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// KiwiHub's Save as New Profile… (#2359 ruling 3): the Profile
/// line's last chip turns the field into a name field, pre-filled
/// with a free name; ↩ saves the live arrangement under the name
/// shown, made free so it never overwrites; Esc returns to picking.
@Suite("KiwiHub save as new profile")
@MainActor
struct JumpProfileNamingTests {
    private func model(
        profiles: [String] = ["Laptop", "Studio"],
        inert: String? = nil
    ) -> JumpModel {
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
        model.loadView = {
            ViewPickList(
                layout: nil,
                kiwiVisionOn: false,
                items: JumpPanelController.items(
                    layout: nil,
                    profiles: (profiles.first, profiles, []),
                    vision: (.off, []),
                    visionChord: nil,
                    lensChord: { _ in nil },
                    offersNewLens: true,
                    inert: inert
                )
            )
        }
        let taken = Set(profiles.map { $0.lowercased() })
        model.freeProfileName = { base in
            taken.contains(base.lowercased()) ? base + "_1" : base
        }
        return model
    }

    @Test("↩ on the chip names a profile, applying nothing")
    func pickStartsNaming() {
        LocalizationManager.shared.select("en")
        let model = model(profiles: ["Laptop", "New Profile"])
        var applied: [ViewPickList.Pick] = []
        model.onApplyView = { applied.append($0) }
        model.setScope(.view)
        let selects = model.fieldSelectAllRequests
        model.view?.select(.newProfile)
        model.handle(.pick(moveHere: false))
        #expect(applied.isEmpty)
        // Pre-filled with a free name, selected for typing over.
        #expect(model.profileNaming == "New Profile_1")
        #expect(model.query == "New Profile_1")
        #expect(model.fieldSelectAllRequests == selects + 1)
    }

    @Test("↩ saves the name shown, made free; Esc returns to picking")
    func saveAndCancel() {
        let model = model()
        var saved: [String] = []
        model.onSaveProfile = {
            saved.append($0)
            return true
        }
        model.setScope(.view)
        model.view?.select(.newProfile)
        model.handle(.pick(moveHere: false))
        model.query = "Studio"
        // A taken name saves beside it, never over it.
        #expect(model.namingTarget == "Studio_1")
        model.handle(.pick(moveHere: false))
        #expect(saved == ["Studio_1"])
        // A name no profile can carry saves nothing.
        model.query = ".hidden"
        #expect(model.namingTarget == nil)
        model.handle(.pick(moveHere: false))
        #expect(saved == ["Studio_1"])
        model.handle(.escape)
        #expect(model.profileNaming == nil)
        #expect(model.view != nil)
    }

    @Test("a save that does not land keeps the field, saying so")
    func failedSaveStays() {
        let model = model()
        model.onSaveProfile = { _ in false }
        model.setScope(.view)
        model.view?.select(.newProfile)
        model.handle(.pick(moveHere: false))
        model.handle(.pick(moveHere: false))
        #expect(model.namingFailed)
        #expect(model.profileNaming != nil)
        // Typing again clears the failure.
        model.query = "Home"
        #expect(!model.namingFailed)
    }

    @Test("⇥ ends the naming with the side")
    func scopeEndsNaming() {
        let model = model()
        model.setScope(.view)
        model.view?.select(.newProfile)
        model.handle(.pick(moveHere: false))
        model.handle(.stepScope(forward: true))
        #expect(model.profileNaming == nil)
    }

    @Test("the chip is last, no digit reaches it, and boot greys it")
    func chipPlacement() {
        let model = model()
        model.setScope(.view)
        let list = model.view
        let profiles = list?.items(.profile) ?? []
        #expect(profiles.last?.pick == .newProfile)
        #expect(list?.number(.profile, profiles.count - 1) == nil)
        let booting = self.model(inert: "KiwiDesk is starting")
        booting.setScope(.view)
        booting.view?.select(.newProfile)
        booting.handle(.pick(moveHere: false))
        #expect(booting.profileNaming == nil)
    }

    @Test("the panel saves through save_profile and names a free name")
    func controllerWiring() throws {
        // Comments stripped, literals kept: the verb is a literal.
        func squashed(_ path: String) throws -> String {
            let url = SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(path)
            return SourceScan.stripComments(
                try String(contentsOf: url, encoding: .utf8)
            ).split(whereSeparator: \.isWhitespace).joined()
        }
        let hub = try squashed(
            "Sources/KiwiDesk/Jump/JumpPanelController+View.swift"
        )
        #expect(
            hub.contains("guardletself,self.core.saveProfileAsUser(name)")
        )
        #expect(hub.contains("self?.core.profiles.freeName(base:base)"))
        #expect(hub.contains("guardpick!=.newProfile"))
        let model = try squashed("Sources/KiwiDesk/Jump/JumpModel+View.swift")
        #expect(
            model.contains(
                "guardaction!=.newProfileelse{returnbeginNaming()}"
            )
        )
        let field = try squashed("Sources/KiwiDesk/Jump/JumpPanelView.swift")
        #expect(field.contains("namingCaption"))
        #expect(
            field.contains(
                ".onChange(of:model.fieldSelectAllRequests){selectFieldText()}"
            )
        )
        #expect(field.contains("#selector(NSText.selectAll(_:))"))
    }

    @Test("the caption names what ↩ writes, or why it cannot")
    func captionWords() {
        LocalizationManager.shared.select("en")
        #expect(ViewPickText.savesAs("Home").contains("“Home”"))
        #expect(!ViewPickText.invalidName.isEmpty)
        let model = model()
        model.setScope(.view)
        model.view?.select(.newProfile)
        model.handle(.pick(moveHere: false))
        #expect(model.namingTarget == "New Profile")
    }
}
