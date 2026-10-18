import Foundation
import Testing

@testable import KiwiDeskCore

/// `GuiConfig`'s own Space-keyed fields, hand-listed in its rename,
/// remove and restore (#68, #792): the fields are found by their
/// type, so a new one that the three doors miss reds here, as
/// `SpaceMapParityTests` does for the settings' maps. Two fields hold
/// a Space as a VALUE and stay out: `appRules`, global by ruling
/// (another profile may declare the Space; only the rename moves
/// it), and `desktopSpaces`, which the draft never holds
/// (`GuiConfig.undraftedFields`).
@Suite("GuiConfig Space field parity (#792)")
struct GuiConfigSpaceParityTests {
    private let probe = SpaceID("parityProbe")

    /// A config holding the probe in every Space-keyed field.
    private func populated() -> GuiConfig {
        var config = GuiConfig()
        config.spaces = [probe]
        config.spaceModes[probe] = .grid
        config.spacePins[probe] = "fp"
        config.mainSpaces = [probe]
        config.fallbackSpace = probe
        return config
    }

    /// Stored fields whose type names `SpaceID`, the settings and
    /// the global app rules aside.
    private func spaceFields(_ config: GuiConfig) -> [(String, String)] {
        Mirror(reflecting: config).children.compactMap { child in
            guard let label = child.label, label != "settings",
                label != "appRules", label != "desktopSpaces",
                String(describing: type(of: child.value))
                    .contains("SpaceID")
            else { return nil }
            return (label, String(describing: child.value))
        }
    }

    @Test("the population holds the probe in every Space field")
    func populationIsExhaustive() {
        let fields = spaceFields(populated())
        #expect(fields.count >= 5)
        for (label, value) in fields {
            #expect(
                value.contains(probe.raw),
                Comment(rawValue: "unpopulated: \(label)")
            )
        }
    }

    @Test("restoreSpace takes every Space field back")
    func restoreCoversEveryField() {
        var config = GuiConfig()
        config.restoreSpace(probe, from: populated())
        for (label, value) in spaceFields(config) {
            #expect(
                value.contains(probe.raw),
                Comment(rawValue: "not restored: \(label)")
            )
        }
    }

    @Test("removeSpace clears every Space field")
    func removeCoversEveryField() {
        var config = populated()
        config.removeSpace(probe)
        for (label, value) in spaceFields(config) {
            #expect(
                !value.contains(probe.raw),
                Comment(rawValue: "left behind: \(label)")
            )
        }
    }
}
