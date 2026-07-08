import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    KiwiCore(
        configDirectory: FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                "kiwi-rename-\(UUID().uuidString)"
            )
    )
}

@MainActor
private func save(_ core: KiwiCore, _ name: String) {
    core.execute("save_profile", args: [.string(name)])
}

/// Pins `ProfileManager.rename` + the `KiwiCore` facade. The
/// case tests assume a case-insensitive volume (default APFS —
/// dev machines and CI); on a case-sensitive volume the
/// collision check naturally relaxes with the filesystem.
@Suite("Profile rename", .serialized)
@MainActor
struct ProfileRenameTests {
    @Test("rename moves the file and carries the adopted name")
    func basicRename() throws {
        let core = makeCore()
        save(core, "desk")
        try core.renameProfile(from: "desk", to: "studio")
        #expect(core.profiles.list() == ["studio"])
        #expect(core.profiles.currentName == "studio")
    }

    @Test("case-only rename keeps the profile")
    func caseOnly() throws {
        let core = makeCore()
        save(core, "work")
        try core.renameProfile(from: "work", to: "Work")
        #expect(core.profiles.list() == ["Work"])
        let renamed = try core.profiles.read(name: "Work")
        #expect(renamed.name == "Work")
    }

    @Test("rename onto an existing profile is rejected")
    func collision() throws {
        let core = makeCore()
        save(core, "a")
        save(core, "b")
        #expect(throws: ProfileError.self) {
            try core.renameProfile(from: "a", to: "b")
        }
        #expect(core.profiles.list() == ["a", "b"])
    }

    @Test("case-variant collision is rejected, not clobbered")
    func caseVariantCollision() throws {
        let core = makeCore()
        save(core, "A")
        save(core, "B")
        #expect(throws: ProfileError.self) {
            try core.renameProfile(from: "A", to: "b")
        }
        #expect(core.profiles.list() == ["A", "B"])
    }

    @Test("same-name rename is a no-op")
    func sameName() throws {
        let core = makeCore()
        save(core, "desk")
        try core.renameProfile(from: "desk", to: "desk")
        #expect(core.profiles.list() == ["desk"])
        #expect(core.profiles.currentName == "desk")
    }

    @Test("rename chases native-Space bindings")
    func bindingChase() throws {
        let core = makeCore()
        save(core, "desk")
        core.nativeSpaceBindings = [2: "desk", 3: "other"]
        try core.renameProfile(from: "desk", to: "studio")
        #expect(
            core.nativeSpaceBindings
                == [2: "studio", 3: "other"]
        )
    }

    @Test("rename follows the sidecar's binding lines")
    func sidecarFollow() throws {
        let core = makeCore()
        save(core, "desk")
        var config = GuiConfig()
        config.profileBindings = [2: "desk"]
        try core.guiConfigStore.save(config)
        core.nativeSpaceBindings = [2: "desk"]
        try core.renameProfile(from: "desk", to: "studio")
        #expect(
            core.guiConfigStore.load()?.profileBindings
                == [2: "studio"]
        )
    }

    @Test("rename never creates a sidecar")
    func noSidecarCreated() throws {
        let core = makeCore()
        save(core, "desk")
        core.nativeSpaceBindings = [2: "desk"]
        try core.renameProfile(from: "desk", to: "studio")
        #expect(!core.guiConfigStore.exists)
    }
}
