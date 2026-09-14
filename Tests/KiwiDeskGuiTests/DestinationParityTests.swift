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

    // General and the Mac Checklist are the profile-agnostic
    // surfaces: they alone omit the profile-context header AND
    // hide while a stored profile is edited (#1365 joined the
    // checklist — it reads macOS, never a profile). The two
    // predicates coincide since #109 (App Rules joined the
    // edit-visible set with its per-profile Space facet) but
    // stay separate concepts — header presence vs edit
    // reachability. Pin both so a new case can't silently land
    // in the wrong bucket.
    @Test("only the profileless pair omits the profile context")
    func profileContextExcludesOnlyProfileless() {
        let profileless: Set<SettingsDestination> = [
            .general, .macChecklist,
        ]
        for dest in SettingsDestination.allCases {
            let global = profileless.contains(dest)
            #expect(dest.showsProfileContext == !global)
            #expect(
                dest.visibleWhileEditingStoredProfile == !global
            )
        }
    }
}
