import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// `explain_window` and `explain_app` (#1685 ▸ Ruling 6d): each
/// field is read from the door that decides it, and the float
/// cause is told apart from the verdict and the flag alone.
@Suite("Explain a window or an app (#1685)", .serialized)
@MainActor
struct ExplainCommandsTests {
    private let id = WindowID(7)
    private let bundle = "com.example.app"

    private func makeCore() -> KiwiCore {
        makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwi-explain-\(UUID().uuidString)"
                )
        )
    }

    /// Tracks the window the way the event loop would: the flag
    /// and the cached verdict agree unless `flag` says otherwise.
    private func track(
        _ core: KiwiCore,
        _ verdict: FloatVerdict = .tiles,
        flag: Bool? = nil
    ) {
        var window = ManagedWindow(
            id: id,
            pid: 4242,
            appName: "App",
            appBundleID: bundle,
            title: "Secret title"
        )
        window.isFloating = flag ?? verdict.floats
        core.eventLoop.detectedFloating[id] = verdict
        core.state.apply(.windowCreated(window))
    }

    private func explain(_ core: KiwiCore) -> [String: JSONValue] {
        let response = core.execute(
            "explain_window",
            args: [.number(Double(id.raw))]
        )
        guard case .object(let fields)? = response.data else {
            Issue.record("no answer: \(response.error ?? "")")
            return [:]
        }
        return fields
    }

    private func field(
        _ object: JSONValue?,
        _ key: String
    ) -> JSONValue? {
        if case .object(let fields)? = object { return fields[key] }
        return nil
    }

    @Test("a tiled window has no float cause")
    func tiledHasNoCause() {
        let core = makeCore()
        track(core)
        let floating = explain(core)["float"]
        #expect(field(floating, "floats") == .bool(false))
        #expect(field(floating, "cause") == .null)
        #expect(field(floating, "detection") == .null)
    }

    @Test(
        "detection's verdict is the cause, with its escapes",
        arguments: [
            AutoFloatReason.rule, .panel, .accessoryApp, .fixedSize,
        ]
    )
    func detectionIsTheCause(_ reason: AutoFloatReason) {
        let core = makeCore()
        track(core, .floats(reason))
        let floating = explain(core)["float"]
        #expect(field(floating, "cause") == .string("detection"))
        let detection = field(floating, "detection")
        #expect(field(detection, "reason") == .string(reason.wireName))
        #expect(field(detection, "is_guess") == .bool(reason.isGuess))
        #expect(
            field(detection, "escapes")
                == .array(reason.escapes.map(JSONValue.string))
        )
    }

    @Test("a guess escapes through a Tile rule, a panel through none")
    func escapesFollowTheReason() {
        #expect(
            AutoFloatReason.accessoryApp.escapes
                == ["set_float_automatically", "tile_rule"]
        )
        #expect(
            AutoFloatReason.fixedSize.escapes
                == ["set_float_automatically", "tile_rule"]
        )
        #expect(AutoFloatReason.panel.escapes.isEmpty)
        #expect(
            AutoFloatReason.rule.escapes == ["app_rule.remove_float"]
        )
        // An escape that names a verb names one that exists.
        let verbs = [AutoFloatReason.rule, .panel, .accessoryApp, .fixedSize]
            .flatMap(\.escapes).filter { $0 != "tile_rule" }
        for verb in verbs {
            #expect(APIReference.entry(named: verb) != nil, "\(verb)")
        }
    }

    /// The reasons' wire spellings are a machine contract.
    @Test("each reason keeps its wire spelling")
    func wireNamesAreFrozen() {
        #expect(AutoFloatReason.rule.wireName == "rule")
        #expect(AutoFloatReason.panel.wireName == "panel")
        #expect(AutoFloatReason.accessoryApp.wireName == "accessory_app")
        #expect(AutoFloatReason.fixedSize.wireName == "fixed_size")
    }

    @Test("a flag with no verdict is the user's float")
    func flagAloneIsTheUser() {
        let core = makeCore()
        track(core, .tiles, flag: true)
        let floating = explain(core)["float"]
        #expect(field(floating, "cause") == .string("user"))
        #expect(explain(core)["floating"] == .bool(true))
    }

    @Test("a floating-mode Space floats a window with no flag")
    func spaceModeIsTheCause() throws {
        let core = makeCore()
        track(core)
        let space = try #require(core.state.workspaces.space(of: id))
        core.state.workspaces.setMode(space, .floating)
        let answer = explain(core)
        let floating = answer["float"]
        #expect(field(floating, "cause") == .string("space_mode"))
        #expect(field(floating, "floats") == .bool(true))
        #expect(answer["floating"] == .bool(false))
        #expect(answer["mode"] == .string("floating"))
    }

    @Test("the app's rules are its own slice, and no title is told")
    func appRulesAndNoTitle() {
        let core = makeCore()
        track(core)
        core.state.appRules[bundle] = SpaceID("3")
        core.installFloatRules(
            FloatRules(
                ["\(bundle):Info", "\(bundle)s", "com.other.app"],
                guess: FloatGuess(tileRules: [bundle])
            )
        )
        let answer = explain(core)
        let rule = answer["app_rule"]
        #expect(field(rule, "space") == .string("3"))
        #expect(
            field(rule, "floats")
                == .array([.string("\(bundle):Info")])
        )
        #expect(field(rule, "tile_rule") == .bool(true))
        let text = String(describing: answer)
        #expect(!text.contains("Secret title"))
    }

    @Test("an unknown window is refused")
    func unknownWindowIsRefused() {
        let core = makeCore()
        let response = core.execute("explain_window", args: [.number(99)])
        #expect(!response.isSuccess)
    }

    @Test("an app answers its ignores, processes and windows")
    func explainApp() {
        let core = makeCore()
        track(core)
        core.eventLoop.ignoreRules = IgnoreRules([bundle])
        core.eventLoop.runningApplications = {
            [
                RunningApp(
                    pid: 4242,
                    activationPolicy: .accessory,
                    ref: AppRef(
                        bundleID: "COM.Example.App",
                        name: "App"
                    )
                )
            ]
        }
        core.eventLoop.visiblePIDs = { [] }
        core.eventLoop.appIsHidden = { _ in true }
        core.eventLoop.activationPolicy = { _ in .accessory }
        let response = core.execute(
            "explain_app",
            args: [.string("COM.Example.App")]
        )
        guard case .object(let answer)? = response.data else {
            Issue.record("no answer: \(response.error ?? "")")
            return
        }
        #expect(answer["bundle_id"] == .string(bundle))
        #expect(field(answer["ignored"], "by_rule") == .bool(true))
        #expect(field(answer["ignored"], "built_in") == .bool(false))
        #expect(answer["windows"] == .array([.number(Double(id.raw))]))
        guard case .array(let running)? = answer["running"],
            let process = running.first
        else {
            Issue.record("no process listed")
            return
        }
        #expect(field(process, "pid") == .number(4242))
        // An unobserved pid's policy is LaunchServices' answer,
        // read through `policy(of:)` over the pinned seam.
        #expect(field(process, "policy") == .string("accessory"))
        #expect(field(process, "observed") == .bool(false))
        #expect(field(process, "hidden") == .bool(true))
    }

    @Test("a raised-layer app is read off the built-in table")
    func raisedWindowsAreTheTable() {
        #expect(
            FloatDetection.ignoresRaisedWindows(
                bundleID: "com.mitchellh.ghostty"
            )
        )
        #expect(
            !FloatDetection.ignoresRaisedWindows(bundleID: "com.apple.finder")
        )
    }

    @Test("explain_app reports the built-in raised-window ignore")
    func explainAppReportsRaised() {
        let core = makeCore()
        core.eventLoop.runningApplications = { [] }
        core.eventLoop.visiblePIDs = { [] }
        let response = core.execute(
            "explain_app",
            args: [.string("com.mitchellh.ghostty")]
        )
        guard case .object(let answer)? = response.data else {
            Issue.record("no answer")
            return
        }
        #expect(
            field(answer["ignored"], "built_in_raised") == .bool(true)
        )
    }

    @Test("an app with no bundle id is refused")
    func emptyAppIsRefused() {
        let core = makeCore()
        #expect(!core.execute("explain_app", args: [.string(" ")]).isSuccess)
    }
}
