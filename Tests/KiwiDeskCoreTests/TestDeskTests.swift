import Foundation
import Testing

@testable import KiwiDeskCore

/// `KIWIDESK_HOME` names a root, and both folders hang off it
/// (#3121); unset or empty, a launch is a normal one. The live
/// process's own root is read once at load and stays unset under
/// the test runner, so the default folders keep their meaning.
@Suite("Test desk root (#3121)")
struct TestDeskTests {
    @Test("an unset or empty variable is a normal launch")
    func unsetIsNormal() {
        #expect(TestDesk.root(in: [:]) == nil)
        #expect(TestDesk.root(in: [TestDesk.variable: ""]) == nil)
    }

    @Test("a root puts the config and machine folders under it")
    func rootHoldsBoth() throws {
        let root = try #require(
            TestDesk.root(in: [TestDesk.variable: "/tmp/kd//desk/"])
        )
        #expect(root.path == "/tmp/kd/desk")
        #expect(
            TestDesk.configDirectory(under: root).path
                == "/tmp/kd/desk/config"
        )
        #expect(
            TestDesk.machineDirectory(under: root).path
                == "/tmp/kd/desk/machine"
        )
    }

    @Test("the runner is no test desk, so defaults are today's")
    func runnerIsNormal() {
        #expect(!TestDesk.isActive)
        #expect(TestDesk.refusal("service") == nil)
        #expect(AppDefaults.store === UserDefaults.standard)
        #expect(MachineLocation.directory == MachineLocation.defaultDirectory)
    }

    @Test("a test desk takes its own suite, never the owner's")
    func testDeskTakesItsSuite() {
        let store = AppDefaults.store(active: true)
        #expect(store !== UserDefaults.standard)
        #expect(AppDefaults.store(active: false) === UserDefaults.standard)
    }

    @Test("a test desk refuses the service and the login item")
    func refusesLaunchers() {
        #expect(TestDesk.refusal("service", active: true) != nil)
        var wrote = false
        let state = LoginItemManager.guardedWrite(
            true,
            at: URL(fileURLWithPath: "/Applications/KiwiDesk.app"),
            write: { _ in wrote = true },
            read: { .notRegistered },
            testDesk: true
        )
        #expect(!wrote)
        #expect(state == .notRegistered)
    }

    @Test("a test desk follows no sync folder")
    func followsNoSyncFolder() {
        let (defaults, _) = makeScratchDefaults()
        let folder = URL(fileURLWithPath: "/tmp/kd-sync", isDirectory: true)
        SyncFolderLocation.store(folder, in: defaults)
        SyncFolderLocation.storeFollows(true, in: defaults)
        #expect(SyncFolderLocation.followed(in: defaults) != nil)
        #expect(
            SyncFolderLocation.followed(in: defaults, testDesk: true) == nil
        )
    }
}
