import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// An app with no bundle id is named by its process name (#3211): a
/// rule's key is `AppRef.listKey`, a bundle id always wins, and a
/// process with no usable name has no key at all.
@Suite("App Rules match a bundle-less app by name (#3211)")
@MainActor
struct AppRuleProcessNameTests {
    private let emulator = "qemu-system-aarch64"

    @Test("the key: a bundle id wins, else the lowercased name")
    func listKey() {
        #expect(
            AppRef(bundleID: "Com.Apple.Safari", name: "Safari").listKey
                == "com.apple.safari"
        )
        #expect(
            AppRef(bundleID: nil, name: "QEMU-System-AArch64").listKey
                == emulator
        )
        #expect(AppRef(bundleID: nil, name: "").listKey == nil)
        #expect(AppRef(bundleID: nil, name: AppRef.unnamed).listKey == nil)
    }

    @Test("float, ignore and Tile rules name it by its process name")
    func rulesMatchTheName() {
        let floats = FloatRules([emulator, "safari:Downloads"])
        #expect(floats.matches(app: emulator, title: "Pixel"))
        #expect(!floats.matches(app: nil, title: "Pixel"))
        // A name agreeing with a key never stands in for a bundle id.
        let safari = AppRef(bundleID: "com.apple.Safari", name: "Safari")
        #expect(!floats.matches(app: safari.listKey, title: "Downloads"))
        #expect(floats.hasTitleRule(app: "safari"))
        #expect(IgnoreRules([emulator]).matches(app: emulator))
        let guess = FloatGuess(tileRules: [emulator])
        #expect(!guess.applies(toApp: emulator))
        #expect(guess.applies(toApp: "com.apple.mail"))
    }

    @Test("the ignore doors take the name, the built-ins the bundle")
    func ignoreDoorsTakeTheName() {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("rule-name-\(UUID().uuidString)")
        )
        core.eventLoop.ignoreRules = IgnoreRules([emulator])
        let bare = AppRef(bundleID: nil, name: "qemu-system-aarch64")
        #expect(core.eventLoop.shouldIgnoreApp(bare))
        #expect(
            FloatDetection.shouldIgnore(
                app: bare,
                layer: 0,
                isAccessory: false,
                rules: IgnoreRules([emulator]),
                titlebarButton: false
            )
        )
        // A name equal to a rule never stands in for a bundle id.
        let named = AppRef(bundleID: "com.example.qemu", name: emulator)
        #expect(!core.eventLoop.shouldIgnoreApp(named))
    }

    @Test("a Space rule files the bundle-less window")
    func spaceRuleFiles() {
        var state = StateCoordinator()
        state.workspaces.ensureSpace("1")
        state.workspaces.ensureSpace("2")
        state.workspaces.activate("1")
        state.appRules[emulator] = "2"
        state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(1),
                    pid: 900_301,
                    appName: "qemu-system-aarch64",
                    appBundleID: nil
                )
            )
        )
        #expect(state.workspaces.space(of: WindowID(1)) == "2")
        // A rule keyed by the placeholder never files a nameless one.
        state.appRules[AppRef.unnamed] = "2"
        state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(2),
                    pid: 900_302,
                    appName: AppRef.unnamed,
                    appBundleID: nil
                )
            )
        )
        #expect(state.workspaces.space(of: WindowID(2)) == "1")
    }

    @Test("explain names the key the rule matched")
    func explainNamesTheKey() {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("rule-name-\(UUID().uuidString)")
        )
        core.state.appRules[emulator] = "1"
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(5),
                    pid: 900_303,
                    appName: emulator,
                    appBundleID: nil
                )
            )
        )
        let window = core.execute("explain_window", args: [.number(5)])
        guard case .object(let fields)? = window.data else {
            Issue.record("no answer: \(window.error ?? "")")
            return
        }
        #expect(fields["rule_key"] == .string(emulator))
        #expect(fields["bundle_id"] == .null)
        guard case .object(let rule)? = fields["app_rule"] else {
            Issue.record("no app_rule")
            return
        }
        #expect(rule["space"] == .string("1"))
        let app = core.execute("explain_app", args: [.string(emulator)])
        guard case .object(let known)? = app.data,
            case .array(let windows)? = known["windows"]
        else {
            Issue.record("no app answer: \(app.error ?? "")")
            return
        }
        #expect(known["bundle_id"] == .null)
        #expect(windows.count == 1)
    }

    @Test("a launch debt is owed and claimed by the process name")
    func launchDebtByName() {
        let intent = LaunchFollowIntent()
        let now = Date()
        let key = AppRef(bundleID: nil, name: "QEMU-System-AArch64").listKey
        #expect(key == emulator)
        intent.record(emulator, at: now)
        #expect(intent.claim(key ?? "", at: now) != nil)
    }
}
