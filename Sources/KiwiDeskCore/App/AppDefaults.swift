import Foundation

/// The defaults store every KiwiDesk setting reads and writes:
/// `.standard`, or `TestDesk.defaultsSuite` on a test desk.
/// Reads of another domain (`NSGlobalDomain`) and records of
/// machine-wide state stay on `.standard`
/// (`AppDefaultsRoutingTests`).
public enum AppDefaults {
    /// Immutable once read; `UserDefaults` is documented
    /// thread-safe, which the SDK does not yet declare.
    nonisolated(unsafe) public static let store: UserDefaults =
        TestDesk.isActive
        ? testDeskSuite()
        : .standard

    /// Never the owner's domain: a suite that cannot open stops
    /// the test desk rather than writing `.standard`.
    private static func testDeskSuite() -> UserDefaults {
        guard let suite = UserDefaults(suiteName: TestDesk.defaultsSuite)
        else { preconditionFailure("no \(TestDesk.defaultsSuite) suite") }
        return suite
    }
}
