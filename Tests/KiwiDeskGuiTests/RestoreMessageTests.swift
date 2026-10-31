import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The restore confirm says what the restore does with init.lua,
/// picked from Core's reason rather than guessed (#2517, #2730).
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
        let choose = message(nil, withInitLua: true)
        #expect(choose.contains("The backup also includes an init.lua."))
        // Names the checkbox by its own label (#2730).
        #expect(choose.contains("“\(BackupInitLuaOption.label)” off"))
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
