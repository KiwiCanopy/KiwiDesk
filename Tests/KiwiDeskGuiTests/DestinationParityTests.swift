import Testing

@testable import KiwiDesk

// Forget-proof guard for the sidebar's destination lists
// (#68 review): the enum is CaseIterable but the sidebar
// renders only the two static group arrays — a new case
// missing from both would compile (the detail switch is
// exhaustive) yet be unreachable in the UI.

@Suite("Sidebar destination parity")
struct DestinationParityTests {
    @Test("every destination lives in exactly one group")
    func groupsCoverAllCases() {
        let grouped =
            SettingsDestination.thisProfile
            + SettingsDestination.wholeApp
        #expect(
            Set(grouped)
                == Set(SettingsDestination.allCases)
        )
        // No destination in both groups.
        #expect(
            grouped.count
                == SettingsDestination.allCases.count
        )
    }
}
