import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// Every bundled look carries its description (#1684): the names
/// are restated in `LookDescriptions`, so a rename in
/// `Resources/Looks/bundled.json` would otherwise drop a caption.
@Suite("Look descriptions")
@MainActor
struct LookDescriptionsTests {
    @Test("every bundled look has a caption")
    func everyBundledLookIsDescribed() {
        LocalizationManager.shared.select("en")
        defer { LocalizationManager.shared.select(nil) }
        for look in LookCatalog.bundled() {
            #expect(
                LookDescriptions.caption(for: look.name) != nil,
                "\(look.name) has no description"
            )
        }
        #expect(
            LookDescriptions.caption(for: "Taskbar")
                == "In the style of Windows 11"
        )
    }
}
