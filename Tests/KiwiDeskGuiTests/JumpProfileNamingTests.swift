import AppKit
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
    final class Spoken { var lines: [String] = [] }

    private func model(
        profiles: [String] = ["Laptop", "Studio"],
        inert: String? = nil
    ) -> (JumpModel, Spoken) {
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
        // Core's rule, over a fixed list of taken names.
        let taken = Set(profiles.map { $0.lowercased() })
        model.newProfileName = { typed in
            let name = typed.trimmingCharacters(in: .whitespacesAndNewlines)
            guard ProfileManager.isValidName(name) else { return nil }
            return taken.contains(name.lowercased()) ? name + "_1" : name
        }
        let spoken = Spoken()
        model.onAnnounce = { spoken.lines.append($0) }
        return (model, spoken)
    }

    private func startNaming(_ model: JumpModel) {
        model.setScope(.view)
        model.view?.select(.newProfile)
        model.handle(.pick(moveHere: false))
    }

    @Test("↩ on the chip names a profile, applying nothing")
    func pickStartsNaming() {
        LocalizationManager.shared.select("en")
        let (model, spoken) = model(profiles: ["Laptop", "New Profile"])
        var applied: [ViewPickList.Pick] = []
        model.onApplyView = { applied.append($0) }
        let selects = model.fieldSelectAllRequests
        startNaming(model)
        #expect(applied.isEmpty)
        // Pre-filled with a free name, selected for typing over.
        #expect(model.naming?.text == "New Profile_1")
        #expect(model.query == "New Profile_1")
        #expect(model.fieldSelectAllRequests == selects + 1)
        #expect(
            spoken.lines.last == ViewPickText.namingSpoken("New Profile_1")
        )
    }

    @Test("↩ saves the name shown, made free; Esc returns to picking")
    func saveAndCancel() {
        let (model, _) = model()
        var saved: [String] = []
        model.onSaveProfile = {
            saved.append($0)
            return true
        }
        startNaming(model)
        model.query = "Studio"
        // A taken name saves beside it, never over it.
        #expect(model.namingTarget == "Studio_1")
        model.handle(.pick(moveHere: false))
        #expect(saved == ["Studio_1"])
        model.handle(.escape)
        #expect(model.naming == nil)
        #expect(model.view != nil)
    }

    @Test("a name no profile can carry saves nothing, and says so")
    func invalidNameIsSpoken() {
        LocalizationManager.shared.select("en")
        let (model, spoken) = model()
        var saved: [String] = []
        model.onSaveProfile = {
            saved.append($0)
            return true
        }
        startNaming(model)
        // Trimmed before it is judged: " .x" is a dot-file.
        model.query = " .hidden"
        #expect(model.namingTarget == nil)
        model.handle(.pick(moveHere: false))
        #expect(saved.isEmpty)
        #expect(spoken.lines.last == ViewPickText.invalidName)
    }

    @Test("a save that does not land keeps the field, saying so")
    func failedSaveStays() {
        LocalizationManager.shared.select("en")
        let (model, spoken) = model()
        model.onSaveProfile = { _ in false }
        startNaming(model)
        model.handle(.pick(moveHere: false))
        #expect(model.naming?.failed == true)
        #expect(spoken.lines.last == ViewPickText.saveFailed)
        // Typing clears the failure; so does a fresh naming.
        model.query = "Home"
        #expect(model.naming?.failed == false)
        model.handle(.pick(moveHere: false))
        model.handle(.escape)
        startNaming(model)
        #expect(model.naming?.failed == false)
    }

    @Test("⇥ ends the naming with the side")
    func scopeEndsNaming() {
        let (model, _) = model()
        startNaming(model)
        model.handle(.stepScope(forward: true))
        #expect(model.naming == nil)
        #expect(!model.isNaming)
    }

    @Test("a click while naming: the chip keeps it, another applies")
    func clicksWhileNaming() {
        let (model, _) = model()
        var applied: [ViewPickList.Pick] = []
        model.onApplyView = { applied.append($0) }
        startNaming(model)
        model.query = "Home"
        if let chip = model.view?.items(.profile).last {
            model.applyView(chip)
        }
        #expect(model.naming?.text == "Home")
        if let studio = model.view?.items(.profile)[1] {
            model.applyView(studio)
        }
        #expect(model.naming == nil)
        #expect(applied == [.profile("Studio")])
    }

    @Test("while naming the field keeps every key but ↩, Esc and ⇥")
    func keysReachTheField() {
        let left: UInt16 = 123
        let sKey: UInt16 = 1
        let one = UInt16(JumpKey.digitRows[0])
        let cases: [(UInt16, NSEvent.ModifierFlags)] = [
            (left, []), (left, [.shift]), (sKey, [.command]),
            (one, [.command]),
        ]
        for (code, flags) in cases {
            let key = JumpKey.of(
                keyCode: code,
                modifiers: flags,
                scope: .view,
                naming: true
            )
            #expect(key == nil)
        }
        #expect(
            JumpKey.of(
                keyCode: left,
                modifiers: [],
                scope: .view,
                naming: false
            )
                == .side(-1)
        )
        let save = JumpKey.of(
            keyCode: JumpKey.returnKey,
            modifiers: [],
            scope: .view,
            naming: true
        )
        #expect(save == .pick(moveHere: false))
    }

    @Test("the chip is last, no digit reaches it, and boot greys it")
    func chipPlacement() {
        let (model, _) = model()
        model.setScope(.view)
        let list = model.view
        let profiles = list?.items(.profile) ?? []
        #expect(profiles.last?.pick == .newProfile)
        #expect(list?.number(.profile, profiles.count - 1) == nil)
        let (booting, _) = self.model(inert: "KiwiDesk is starting")
        startNaming(booting)
        #expect(booting.naming == nil)
    }

    @Test("the panel saves through save_profile under Core's name rule")
    func wiring() throws {
        // Comments stripped, literals kept: the verb is a literal.
        func squashed(_ path: String) throws -> String {
            let url = SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(path)
            return SourceScan.stripComments(
                try String(contentsOf: url, encoding: .utf8)
            ).split(whereSeparator: \.isWhitespace).joined()
        }
        let core = try squashed(
            "Sources/KiwiDeskCore/App/KiwiCore+LayoutPicker.swift"
        )
        #expect(
            core.contains(
                "withUserMotion{execute(\"save_profile\","
                    + "args:[.string(name)]).isSuccess}"
            )
        )
        let hub = try squashed(
            "Sources/KiwiDesk/Jump/JumpPanelController+View.swift"
        )
        #expect(
            hub.contains("guardletself,self.core.saveProfileAsUser(name)")
        )
        #expect(
            hub.contains("self?.core.profiles.newProfileName(typed:typed)")
        )
        // Settings asks the same rule.
        let settings = try squashed(
            "Sources/KiwiDesk/Settings/SettingsModel+Profiles.swift"
        )
        #expect(settings.contains("core.profiles.newProfileName(typed:name)"))
        let panel = try squashed(
            "Sources/KiwiDesk/Jump/JumpPanelController.swift"
        )
        #expect(
            panel.contains(
                "panel.naming={[weakmodel]inmodel?.isNaming??false}"
            )
        )
        let field = try squashed("Sources/KiwiDesk/Jump/JumpPanelView.swift")
        #expect(field.contains("namingCaption"))
        #expect(field.contains(".accessibilityHint(namingLine??\"\")"))
        #expect(
            field.contains(
                ".onChange(of:model.fieldSelectAllRequests)"
                    + "{selectFieldText()}"
            )
        )
    }
}
