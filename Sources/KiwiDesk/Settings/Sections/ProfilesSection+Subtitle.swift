import KiwiDeskCore
import SwiftUI

/// A saved profile's counts as one sentence — the counters'
/// tooltip and the name's VoiceOver value (#1624).
extension ProfilesSection {
    func subtitle(_ summary: ProfileSummary) -> String {
        ProfileCounters.sentence(
            screens: summary.count,
            spaces: summary.spaceCount,
            overrides: summary.shortcutOverrideCount
        )
    }
}
