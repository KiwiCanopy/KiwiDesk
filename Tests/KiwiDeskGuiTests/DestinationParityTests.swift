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

    // `showsProfileContext` deliberately does NOT match
    // `visibleWhileEditingStoredProfile` (#68 header rework):
    // General is the only profile-agnostic surface, while App
    // Rules is edit-hidden yet context-shown (its rules target
    // profile spaces). Pin the invariant so a new case can't
    // silently land in the wrong bucket.
    @Test("only General omits the profile-context header")
    func profileContextExcludesOnlyGeneral() {
        for dest in SettingsDestination.allCases {
            #expect(
                dest.showsProfileContext == (dest != .general)
            )
        }
        // The intentional divergence: shown, but edit-hidden.
        #expect(SettingsDestination.appRules.showsProfileContext)
        #expect(
            !SettingsDestination.appRules
                .visibleWhileEditingStoredProfile
        )
    }
}
