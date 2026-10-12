import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The live page's custom-Lua banner tells a Save that mints
/// gui.json apart from one that writes an existing sidecar
/// (#2183 ▸ Ruling): only the first moves shortcuts and rules
/// out of init.lua's reach.
@Suite("Custom Lua banner state (#2183)", .serialized)
@MainActor
struct CustomLuaBannerStateTests {
    private func makeModel(sidecar: Bool) throws -> SettingsModel {
        let core = makeTestCore()
        if sidecar { try core.guiConfigStore.save(GuiConfig()) }
        try FileManager.default.createDirectory(
            at: core.configURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try "KiwiDesk.set_gap_global(10)".write(
            to: core.configURL,
            atomically: true,
            encoding: .utf8
        )
        let model = makeTestModel(core: core)
        model.reload()
        return model
    }

    @Test("Without gui.json the banner says a Save adopts")
    func noSidecarAdopts() throws {
        let model = try makeModel(sidecar: false)
        #expect(model.hasCustomLua)
        #expect(!model.sidecarExists)
    }

    @Test("With gui.json the banner keeps the coexistence line")
    func sidecarCoexists() throws {
        let model = try makeModel(sidecar: true)
        #expect(model.hasCustomLua)
        #expect(model.sidecarExists)
    }

    /// The shell draws the banner off that state, and the banner
    /// picks its sentence off the flag — a surfacing branch every
    /// state test above stays green without (gui.md ▸ Home).
    @Test("the banner is wired to the sidecar state")
    func bannerIsWired() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
        let sites = [
            "SettingsView+Detail.swift":
                "ifmodel.hasCustomLua{"
                + "CustomLuaBanner(savingAdopts:!model.sidecarExists)",
            "Components/Lua/CustomLuaBanner.swift":
                "savingAdopts?L(\"custom_lua_banner.adopts\"",
        ]
        for (path, needle) in sites {
            let raw = try String(
                contentsOf: root.appendingPathComponent(path),
                encoding: .utf8
            )
            #expect(!raw.isEmpty)
            let squashed = SourceScan.stripComments(raw)
                .split(whereSeparator: \.isWhitespace).joined()
            #expect(
                squashed.contains(needle),
                Comment(rawValue: "\(path) lost: \(needle)")
            )
        }
    }
}
