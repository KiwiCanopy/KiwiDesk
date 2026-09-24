import Foundation
import Testing

@testable import KiwiDeskCore

/// The verbs #1517 retired fail LOUDLY and name what replaces
/// them — no alias (AGENTS.md §5) and no silent success, since a
/// user's init.lua is never rewritten and the failure is its
/// migration path.
@Suite("KiwiShelf retired verbs (#1517)")
@MainActor
struct KiwiShelfRetiredVerbTests {
    private func makeCore() -> KiwiCore {
        makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("kiwidesk-\(UUID())")
        )
    }

    @Test("every bar's shared setter names its shelf verb")
    func sharedSettersNameTheShelf() {
        let core = makeCore()
        for verb in [
            "space_bar.set_edge", "app_bar.set_thickness",
            "monocle.set_app_bar_outer_margin",
            "scroll.set_app_bar_liquid_glass",
        ] {
            let field = verb.components(separatedBy: "set_").last!
                .replacingOccurrences(of: "app_bar_", with: "")
            let response = core.execute(verb, args: [.number(1)])
            #expect(!response.isSuccess, "\(verb)")
            #expect(
                response.error?.contains("kiwishelf.set_\(field)")
                    == true,
                "\(verb): \(response.error ?? "")"
            )
        }
    }

    /// The App Bar's slots are as wide as their titles allow,
    /// so its item size points at the title length; a Space
    /// item fits its content and has nothing to point at.
    @Test("item size points at the title length, or says why not")
    func itemSizeReplacements() {
        let core = makeCore()
        let app = core.execute(
            "monocle.set_app_bar_item_size",
            args: [.number(80)]
        )
        #expect(!app.isSuccess)
        #expect(
            app.error?.contains("monocle.set_app_bar_title_cap")
                == true
        )
        let space = core.execute(
            "space_bar.set_item_size",
            args: [.number(80)]
        )
        #expect(!space.isSuccess)
        #expect(space.error?.contains("follows its content") == true)
        #expect(
            APIReference.suggestion(for: "space_bar.set_item_size")
                == nil
        )
    }

    @Test("the front-app title length names its new verb")
    func titleCapRenamed() {
        let core = makeCore()
        let response = core.execute(
            "space_bar.set_title_cap",
            args: [.number(20)]
        )
        #expect(!response.isSuccess)
        #expect(
            response.error?.contains(
                "space_bar.set_front_app_title_cap"
            ) == true
        )
        #expect(
            core.execute(
                "space_bar.set_front_app_title_cap",
                args: [.number(20)]
            ).isSuccess
        )
        #expect(core.tiler.settings.spaceBarStyle.frontAppTitleCap == 20)
    }

    /// The Lua channel: the typo guard's did-you-mean reads the
    /// same table, so a retired name suggests its replacement
    /// rather than whatever is spelled closest.
    @Test("the did-you-mean names the replacement")
    func suggestionNamesTheReplacement() {
        #expect(
            APIReference.suggestion(for: "space_bar.set_edge")
                == "kiwishelf.set_edge"
        )
        #expect(
            APIReference.suggestion(for: "monocle.set_app_bar_font_size")
                == "kiwishelf.set_font_size"
        )
    }

    /// A retired name is never still registered: the typo guard
    /// only fires for a key the namespace table does not hold.
    @Test("no retired verb is still registered")
    func retiredAreUnregistered() {
        for verb in APIReference.retired.keys {
            let parts = verb.split(separator: ".", maxSplits: 1)
            let table = APIReference.namespaces[String(parts[0])] ?? []
            #expect(!table.contains(String(parts[1])), "\(verb)")
        }
    }
}
