import CoreGraphics
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// An open Profiles draft follows a forget (#3324 ▸ main risk):
/// Core's write tells the draft through `onCapturedLive`, and the
/// draft and its baseline drop what the forget dropped — or the
/// next Save writes the setup's bindings and edges straight back.
/// Spends one test core and model per test on the main actor.
@MainActor
@Suite("A forget reaches the open draft (#3324)", .serialized)
struct ForgetSetupDraftTests {
    private static let ab = ["A:100x100", "B:100x100"]
    private static let ac = ["A:100x100", "C:100x100"]

    private func connect(_ core: KiwiCore, _ names: [String]) {
        for display in core.state.workspaces.allDisplays {
            core.state.workspaces.removeDisplay(display.id)
        }
        for (index, name) in names.enumerated() {
            let frame = CGRect(
                x: CGFloat(index) * 100,
                y: 0,
                width: 100,
                height: 100
            )
            core.state.workspaces.upsertDisplay(
                Display(
                    id: DisplayID(UInt32(index + 1)),
                    name: name,
                    frame: frame,
                    visibleFrame: frame
                )
            )
        }
    }

    /// "Desk" on A+B and A+C (connected), a bar edge of its own on
    /// B and a Desktop bound for A+B, then an open draft wired the
    /// way `AppDelegate` wires it.
    private func seeded() throws -> (SettingsModel, KiwiCore) {
        let core = makeTestCore()
        try core.guiConfigStore.save(GuiConfig())
        core.tiler.settings.spaceBarStyle.edgeOverride = [
            "B:100x100": .right
        ]
        connect(core, ["A", "B"])
        try core.persistProfile(named: "Desk", modes: nil)
        connect(core, ["A", "C"])
        try core.persistProfile(named: "Desk", modes: nil)
        _ = core.execute("load_profile", args: [.string("Desk")])
        try core.rewriteSidecarBindings { map in
            map[.number(1)] = DesktopBinding(
                entries: [core.bindingEntry(named: "Desk", setup: Self.ab)],
                desktop: 1
            )
        }
        let model = makeTestModel(core: core)
        model.reload()
        core.profiles.onCapturedLive = { name, write in
            guard case .forgottenSetup(let monitors) = write else { return }
            model.adoptForgottenSetup(monitors, from: name)
        }
        return (model, core)
    }

    @Test("the draft and its baseline drop the forgotten setup's leftovers")
    func draftFollows() throws {
        let (model, core) = try seeded()
        #expect(model.cleanConfig.profileBindings[.number(1)] != nil)
        #expect(!model.config.settings.spaceBarStyle.edgeOverride.isEmpty)
        // An unrelated edit stays the draft's own, and a staged
        // binding edit keeps the record the draft's, so only the
        // draft's own prune can drop the setup's entry from it.
        model.config.settings.minWindowSizes = MinWindowSizes(all: 321)
        model.config.profileBindings[.number(1)] = DesktopBinding(
            entries: [
                core.bindingEntry(named: "Desk", setup: Self.ab),
                core.bindingEntry(named: "Desk"),
            ],
            desktop: 1
        )
        #expect(model.isDirty)
        let reply = core.execute(
            "forget_monitor_set",
            args: Self.ab.map { .string($0) }
        )
        #expect(reply.isSuccess, "\(reply.error ?? "")")
        #expect(
            model.config.profileBindings[.number(1)]?.entries.map(\.setup)
                == [nil]
        )
        #expect(model.cleanConfig.profileBindings[.number(1)] == nil)
        for config in [model.config, model.cleanConfig] {
            #expect(config.settings.spaceBarStyle.edgeOverride.isEmpty)
        }
        #expect(model.isDirty)
        #expect(model.knownSetups.map(\.monitors) == [Self.ac])
        #expect(model.draftMonitorSets.map(\.monitors) == [Self.ac])
    }

    @Test("a stored-profile draft of the holder follows too")
    func storedTargetFollows() throws {
        let (model, core) = try seeded()
        try core.persistProfile(named: "Other", modes: nil)
        _ = core.execute("load_profile", args: [.string("Other")])
        model.target = .storedProfile("Desk")
        model.reload()
        #expect(!model.config.settings.spaceBarStyle.edgeOverride.isEmpty)
        let reply = core.execute(
            "forget_monitor_set",
            args: Self.ab.map { .string($0) }
        )
        #expect(reply.isSuccess, "\(reply.error ?? "")")
        for config in [model.config, model.cleanConfig] {
            #expect(config.settings.spaceBarStyle.edgeOverride.isEmpty)
            #expect(config.profileBindings[.number(1)] == nil)
        }
        #expect(!model.isDirty)
    }

    /// Z is on no setup and no connected screen, so only the
    /// holder gate keeps its edge.
    @Test("a draft of another profile keeps its edges")
    func otherDraftKeepsEdges() throws {
        let (model, core) = try seeded()
        model.config.settings.appBarStyle.edgeOverride = [
            "Z:100x100": .left
        ]
        model.cleanConfig.settings.appBarStyle.edgeOverride = [
            "Z:100x100": .left
        ]
        model.adoptForgottenSetup(Self.ab, from: "Elsewhere")
        #expect(
            model.config.settings.appBarStyle.edgeOverride
                == ["Z:100x100": .left]
        )
        #expect(model.cleanConfig.profileBindings[.number(1)] == nil)
        _ = core
    }

    @Test("a refusal is narrated from its case, never Core's English")
    func refusalIsLocalized() throws {
        LocalizationManager.shared.select("en")
        defer { LocalizationManager.shared.select(nil) }
        let (model, _) = try seeded()
        let connected = try #require(
            model.knownSetups.first { $0.isConnected }
        )
        model.forgetSetup(connected)
        #expect(
            model.profileWarning
                == SettingsModel.forgetRefusal(.connected)
        )
        #expect(
            model.profileWarning
                != MonitorSetForgetError.connected.description
        )
    }

    @Test("the confirm adds the dormant sentence only for a last setup")
    func confirmCopy() throws {
        LocalizationManager.shared.select("en")
        defer { LocalizationManager.shared.select(nil) }
        let (model, _) = try seeded()
        let other = try #require(
            model.knownSetups.first { !$0.isConnected }
        )
        model.confirmingSetupForget(other)
        let pending = try #require(model.pendingDiscard)
        #expect(pending.cancelIsDefault)
        #expect(!pending.message.contains("load it by hand"))
        #expect(pending.message.hasSuffix("You can't undo this."))
        let last = KnownMonitorSet(
            monitors: Self.ab,
            profile: "Desk",
            isConnected: false,
            isProfilesLast: true
        )
        #expect(model.forgetMessage(last).contains("load it by hand"))
    }

    /// The production wiring the suite above stands in for: the
    /// app hands every captured write, and its profile, to the
    /// window controller, which routes a forget to the model.
    @Test("the app routes a forget write to the draft")
    func wiring() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        let app = try SourceScan.strippedSource(
            at: root.appendingPathComponent(
                "Sources/KiwiDesk/AppDelegate.swift"
            )
        )
        // The whole closure body, so a guard beside the call reds.
        #expect(
            Self.compact(app).contains(
                "core.profiles.onCapturedLive={[weakself]name,writein"
                    + "self?.dashboardIfCreated?.adoptCapturedWrite("
                    + "write,of:name)}"
            )
        )
        let controller = try SourceScan.strippedSource(
            at: root.appendingPathComponent(
                "Sources/KiwiDesk/Settings/SettingsWindowController.swift"
            )
        )
        #expect(
            Self.compact(controller).contains(
                "funcadoptCapturedWrite(_write:CapturedWrite,ofname:String){"
                    + "ifcase.forgottenSetup(letmonitors)=write{"
                    + "model.adoptForgottenSetup(monitors,from:name)"
                    + "return}"
            )
        )
    }

    private static func compact(_ source: String) -> String {
        source.filter { !$0.isWhitespace }
    }
}
