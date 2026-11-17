import Foundation
import KiwiDeskCore

/// An app rule's open windows (#3373): the one reading of which
/// tracked windows a rule key names, through `AppRef.listKey`, for
/// the title popover's list and both match previews alike.
@MainActor
enum AppRuleWindows {
    /// The windows `app` names. A lens stores its members lowercased
    /// (#2103 ruling 31), so the key compares without case.
    static func of(_ app: String, in core: KiwiCore) -> [ManagedWindow] {
        core.state.windows.all.filter {
            AppRef(bundleID: $0.appBundleID, name: $0.appName).listKey?
                .caseInsensitiveCompare(app) == .orderedSame
        }
    }
}
