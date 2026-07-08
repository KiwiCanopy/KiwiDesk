import Foundation
import Testing

@testable import KiwiDeskCore

/// Pins the `gui.json` language field (issue #9): `nil` ("System
/// default") is absent from the encoded sidecar — a hand-edited
/// file without the key decodes back to `nil` — and an explicit
/// pick round-trips.
@Suite("GuiConfig language field")
struct GuiConfigLanguageTests {
    private func decodedKeys(_ config: GuiConfig) throws -> Set<
        String
    > {
        let data = try JSONEncoder().encode(config)
        let object = try JSONSerialization.jsonObject(with: data)
        let dict = try #require(object as? [String: Any])
        return Set(dict.keys)
    }

    @Test("nil language encodes with no language key")
    func nilLanguageOmitsKey() throws {
        var config = GuiConfig()
        config.language = nil
        let keys = try decodedKeys(config)
        #expect(!keys.contains("language"))
    }

    @Test("an explicit language encodes its code")
    func explicitLanguageEncodes() throws {
        var config = GuiConfig()
        config.language = "de"
        let data = try JSONEncoder().encode(config)
        let object = try JSONSerialization.jsonObject(with: data)
        let dict = try #require(object as? [String: Any])
        #expect(dict["language"] as? String == "de")
    }

    @Test("round-trip preserves an explicit language")
    func roundTripPreservesLanguage() throws {
        var config = GuiConfig()
        config.language = "de"
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(
            GuiConfig.self,
            from: data
        )
        #expect(decoded.language == "de")
    }

    @Test("a sidecar without the language key decodes to nil")
    func missingKeyDecodesToNil() throws {
        let json = #"{"spaces":[]}"#
        let decoded = try JSONDecoder().decode(
            GuiConfig.self,
            from: Data(json.utf8)
        )
        #expect(decoded.language == nil)
    }
}
