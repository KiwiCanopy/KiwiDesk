import CoreFoundation
import Foundation

/// Lets this process set the cursor while another app is frontmost
/// (#1517): the window server keeps the frontmost app's cursor, so
/// the shelf divider's resize cursor — set from a panel that never
/// activates — showed only while KiwiDesk itself was active. The
/// connection property is private; absent, the divider's hover ink
/// is the fallback and nothing is faked.
extension SkyLight {
    public typealias SetConnectionPropertyFn =
        @convention(c) (
            ConnectionID, ConnectionID, CFString, CFTypeRef
        ) -> Int32

    static let setConnectionProperty: SetConnectionPropertyFn? =
        symbol(
            "SLSSetConnectionProperty",
            as: SetConnectionPropertyFn.self
        )

    /// Whether the window server accepted the property; false where
    /// either symbol is absent.
    @discardableResult
    static func allowBackgroundCursor() -> Bool {
        guard let main = mainConnection, let set = setConnectionProperty
        else { return false }
        let connection = main()
        return set(
            connection,
            connection,
            "SetsCursorInBackground" as CFString,
            kCFBooleanTrue
        ) == 0
    }
}
