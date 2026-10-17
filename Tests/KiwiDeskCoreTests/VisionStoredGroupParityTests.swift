import Foundation
import Testing

@testable import KiwiDeskCore

/// `VisionLook.storedGroup` hand-copies `AppWideSettings.Vision`'s
/// fields, every one optional, so a field it forgets encodes as
/// absent rather than failing to compile (parity-tests.md).
@Suite("KiwiVision stored group parity")
struct VisionStoredGroupParityTests {
    /// Every flat field off its default, so a dropped field cannot
    /// match by coincidence. Two of the three switches land on the
    /// same value, so a swap between those two passes the equality.
    private static var settings: AppWideSettings {
        var settings = AppWideSettings()
        settings.visionDim = 35
        settings.visionBlur.toggle()
        settings.visionAppearance = .light
        settings.visionClearWallpaper.toggle()
        settings.visionClearApp.toggle()
        settings.visionNeverDimmed = ["sketchybar"]
        settings.visionLenses = [VisionLens(name: "Writing")]
        return settings
    }

    @Test("the plain look's group is the stored group without lenses")
    func groupMatchesTheStore() {
        var stored = Self.settings.vision
        stored.lenses = nil
        #expect(Self.settings.look(lens: nil).storedGroup == stored)
    }

    /// Read by reflection and by the encoder, so a field `Vision`
    /// gains is checked without this suite naming it.
    @Test("every stored key but the lens list is carried")
    func everyKeyIsCarried() throws {
        let group = Self.settings.look(lens: nil).storedGroup
        let fields = Mirror(reflecting: group).children
        #expect(fields.count > 1)
        for field in fields where field.label != "lenses" {
            let value = Mirror(reflecting: field.value)
            #expect(
                value.displayStyle != .optional || !value.children.isEmpty,
                "\(field.label ?? "?") is not carried"
            )
        }
        let carried = try keys(of: group)
        let stored = try keys(of: Self.settings.vision)
        #expect(carried == stored.subtracting(["lenses"]))
    }

    private func keys(of value: some Encodable) throws -> Set<String> {
        let data = try JSONEncoder().encode(value)
        let object = try JSONSerialization.jsonObject(with: data)
        return Set(((object as? [String: Any]) ?? [:]).keys)
    }
}
