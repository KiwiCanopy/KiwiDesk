import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The replace alert's lead sentence picks its key by the desk's
/// Space count and by whether a preset is named (#3294): a
/// one-Space desk never reads "1 Spaces". `.serialized` because
/// `LocalizationManager` is a process-wide singleton.
@Suite("Tour replace wording (#3294)", .serialized)
@MainActor
struct TourReplaceTextTests {
    private func message(_ current: Int, _ preset: String?) -> String {
        LocalizationManager.shared.select("en")
        defer { LocalizationManager.shared.select(nil) }
        return TourReplaceText.message(
            current: current,
            preset: preset,
            spaces: 4,
            leftBehind: [:]
        )
    }

    @Test("a one-Space desk takes the .one sentence")
    func oneSpace() {
        #expect(message(1, "Developer").hasPrefix("Your Space and its"))
        #expect(message(1, nil).hasPrefix("Your Space and its"))
        #expect(message(1, nil).contains("the 4 suggested"))
        #expect(message(1, "Developer").contains("Developer's 4"))
    }

    @Test("a larger desk counts its Spaces")
    func severalSpaces() {
        #expect(message(2, "Developer").hasPrefix("Your 2 Spaces"))
        #expect(message(2, nil).hasPrefix("Your 2 Spaces"))
        #expect(message(2, nil).contains("the 4 suggested"))
    }
}
