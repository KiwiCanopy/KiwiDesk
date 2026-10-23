import Foundation
import Testing

@testable import KiwiDeskCore

/// The unknown-symbol issue names the file that holds its row
/// (#2544): the profile a structured install resolved over, by its
/// own name and never the adopted one, followed through a rename;
/// else the sidecar.
@Suite("A shortcut symbol issue names its file (#2544)", .serialized)
@MainActor
struct ShortcutIssueSourceTests {
    private func loaded(_ lua: String) throws -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-isrc-\(UUID().uuidString)")
        )
        try FileManager.default.createDirectory(
            at: core.configDirectory,
            withIntermediateDirectories: true
        )
        try lua.write(to: core.configURL, atomically: true, encoding: .utf8)
        core.loadConfig()
        return core
    }

    private func symbolIssues(_ core: KiwiCore) -> [ConfigIssue] {
        core.configIssues.filter {
            if case .unknownShortcutSymbol = $0.kind { return true }
            return false
        }
    }

    private func profile(
        _ name: String,
        layers: KeyLayerOverride? = nil
    ) -> Profile {
        Profile(
            name: name,
            monitorSets: [MonitorSet(monitors: ["A:100x100"])],
            spaceModes: [:],
            settings: TilingSettings(),
            layers: layers
        )
    }

    private static let badRow = KeyLayer(
        name: KeyLayer.defaultName,
        bindings: [
            KeyBinding(
                combo: "alt+h",
                lua: "KiwiDesk.focus(\"left\")",
                symbol: "kiwidesk.no.such.symbol"
            )
        ]
    )

    /// Loading a profile whose override holds the row names that
    /// profile's file; a sidecar row names the sidecar.
    @Test("A profile's row files its issue against the profile")
    func loadedProfileSourcesTheIssue() throws {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-src-\(UUID().uuidString)")
        )
        var base = GuiConfig()
        base.layers = [Self.badRow]
        try core.guiConfigStore.save(GuiConfig())
        try core.saveGuiConfig(base)
        #expect(symbolIssues(core).map(\.source) == ["gui.json"])
        try core.saveGuiConfig(GuiConfig())
        try core.profiles.save(
            profile("Work", layers: KeyLayerOverride(layers: [Self.badRow]))
        )
        #expect(
            core.execute("load_profile", args: [.string("Work")]).isSuccess
        )
        #expect(symbolIssues(core).map(\.source) == ["Work.json"])
    }

    /// The install names the profile it resolved over, never the
    /// adopted name, which an apply moves only after installing.
    @Test("The install names its own profile, not the adopted one")
    func installNamesItsOwnProfile() throws {
        let core = try loaded("")
        try core.profiles.save(profile("Home"))
        #expect(
            core.execute("load_profile", args: [.string("Home")]).isSuccess
        )
        let lua = try #require(core.keys.lua)
        core.applyStructuredKeybindings(
            layers: [],
            profile: profile(
                "Work",
                layers: KeyLayerOverride(layers: [Self.badRow])
            ),
            lua: lua
        )
        #expect(core.profiles.currentName == "Home")
        #expect(symbolIssues(core).map(\.source) == ["Work.json"])
    }

    @Test("A rename of the installed profile follows to its file")
    func renameFollows() throws {
        let core = try loaded("")
        try core.profiles.save(
            profile("Work", layers: KeyLayerOverride(layers: [Self.badRow]))
        )
        let lua = try #require(core.keys.lua)
        core.applyStructuredKeybindings(
            layers: [],
            profile: try core.profiles.read(name: "Work"),
            lua: lua
        )
        #expect(symbolIssues(core).map(\.source) == ["Work.json"])
        try core.renameProfile(from: "Work", to: "Office")
        #expect(symbolIssues(core).map(\.source) == ["Office.json"])
    }
}
