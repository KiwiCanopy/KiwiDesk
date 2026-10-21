import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The restore confirm says what each offered button does with
/// init.lua, picked from Core's reason rather than guessed (#2517).
@Suite("Restore confirm message (#2517)")
@MainActor
struct RestoreMessageTests {
    private func message(
        _ refusal: SetupBundleError?,
        withInitLua: Bool
    ) -> String {
        SetupBackupText.restoreMessage(
            RestoreChoices(plainRefusal: refusal, withInitLua: withInitLua)
        )
    }

    @Test("each shape of choices takes its own sentence")
    func shapes() {
        LocalizationManager.shared.select("en")
        #expect(
            message(nil, withInitLua: false)
                .hasSuffix("init.lua isn't touched.")
        )
        #expect(
            message(nil, withInitLua: true)
                .contains("The backup also includes an init.lua.")
        )
        #expect(
            message(.luaOwnsThisMac, withInitLua: true)
                .contains("Your settings here come from init.lua")
        )
        // The lead names everything replaced, here with none.
        let only = message(.empty, withInitLua: true)
        #expect(only.contains("every profile"))
        #expect(only.hasSuffix("and KiwiDesk runs it."))
        #expect(only.contains("This backup holds only an init.lua."))
    }
}
