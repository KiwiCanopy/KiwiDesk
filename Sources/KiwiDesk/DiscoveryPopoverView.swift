import KiwiDeskCore
import SwiftUI

/// The discovery popover's single line (#331): no buttons —
/// dismissal is ambient (click away, open the menu, or time out).
/// Deliberately jargon-free for a first-run, non-power user.
struct DiscoveryPopoverView: View {
    var body: some View {
        Text(
            L(
                "onboarding.discovery.popover",
                "KiwiDesk lives here. Click anytime for layouts "
                    + "and settings."
            )
        )
        .font(.callout)
        .fixedSize(horizontal: false, vertical: true)
        .frame(width: 220)
        .padding(14)
    }
}
