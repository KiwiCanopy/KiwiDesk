import Foundation
import Testing

@testable import KiwiDeskCore

/// `hyper.key` in `gui.json` (#1870): app-wide, round-tripped, Off
/// written as `"off"` so the group always carries its leaf, a file
/// written before it reading off, and an unknown name refused.
@Suite("Hyper key stored shape (#1870)")
struct HyperKeyStoredShapeTests {
    private func root(_ value: AppWideSettings) throws -> [String: Any] {
        var config = GuiConfig()
        config.appWide = value
        let data = try JSONEncoder().encode(config)
        return try #require(
            try JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        )
    }

    private func decoded(_ root: [String: Any]) throws -> AppWideSettings? {
        try JSONDecoder().decode(
            GuiConfig.self,
            from: JSONSerialization.data(withJSONObject: root)
        ).appWide
    }

    @Test("gui.json carries hyper.key and reads it back")
    func roundTrips() throws {
        var value = AppWideSettings()
        value.hyperKey = .rightCommand
        let stored = try root(value)
        let group = try #require(stored["hyper"] as? [String: Any])
        #expect(group["key"] as? String == "right_command")
        #expect(try decoded(stored)?.hyperKey == .rightCommand)
    }

    @Test("off is written, and a file without the group reads off")
    func offAndAbsence() throws {
        var stored = try root(AppWideSettings())
        let group = try #require(stored["hyper"] as? [String: Any])
        #expect(group["key"] as? String == "off")
        #expect(try decoded(stored)?.hyperKey == nil)
        stored["hyper"] = nil
        #expect(try decoded(stored)?.hyperKey == nil)
    }

    /// Strict, as every stored value (§5): a renamed key owes a
    /// `ConfigMigration` step, never a silent fall to off.
    @Test("a key name this build does not know fails the decode")
    func unknownIsRefused() throws {
        var stored = try root(AppWideSettings())
        stored["hyper"] = ["key": "caps_lock_2"]
        #expect(throws: DecodingError.self) { try decoded(stored) }
    }
}
