import Foundation

/// This test process's private temp root (#2518), removed at its
/// exit; a root whose process died first is swept by the next
/// run. Twinned like `TestCore.swift`, and both test modules load
/// into one process, so each claim mints its own root.
/// `TestScratchCensusTests` holds every temp-dir and scratch
/// defaults spelling in `Tests/` to this file.
let testTemporaryDirectory: URL = TestScratch.claimRoot()

/// A scratch `UserDefaults` domain this process removes at exit,
/// its plist included (#2518). A suite that wants it gone sooner
/// calls `TestScratch.remove(_:)`.
func makeScratchDefaults() -> (defaults: UserDefaults, name: String) {
    TestScratch.start()
    let name =
        "\(TestScratch.defaultsPrefix)\(getpid())-\(UUID().uuidString)"
    // A fresh name holds nothing; clearing it would write an
    // empty plist for a domain the test may never touch.
    return (UserDefaults(suiteName: name)!, name)
}

/// The sweep behind `testTemporaryDirectory` and
/// `makeScratchDefaults`. Every name carries its owner's pid, so
/// a run removes its own entries at exit and a dead process's
/// at the next claim, never a live sibling run's.
enum TestScratch {
    static let rootPrefix = "kiwi-run-"
    static let defaultsPrefix = "kiwi-test-defaults-"

    static let systemTemp = URL(
        fileURLWithPath: NSTemporaryDirectory(),
        isDirectory: true
    )
    static let preferences = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Preferences", isDirectory: true)

    static func claimRoot() -> URL {
        start()
        let root = systemTemp.appendingPathComponent(
            // Short: a socket under it must fit `sun_path`.
            "\(rootPrefix)\(getpid())-\(UUID().uuidString.prefix(8))",
            isDirectory: true
        )
        try! FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        return root
    }

    /// Once per process: sweeps dead runs' entries and arms the
    /// exit sweep of this run's own.
    static func start() { _ = started }

    private static let started: Void = {
        sweep(temp: systemTemp, preferences: preferences) {
            !isAlive($0)
        }
        atexit {
            let own = getpid()
            TestScratch.sweep(
                temp: TestScratch.systemTemp,
                preferences: TestScratch.preferences
            ) { $0 == own }
        }
    }()

    /// Removes one scratch defaults domain and its plist now. The
    /// synchronize lets cfprefsd write the emptied domain before
    /// the plist goes; a write it still lands after the delete is
    /// a dead pid's plist the next run's claim sweeps.
    static func remove(_ name: String, preferences: URL = preferences) {
        UserDefaults.standard.removePersistentDomain(forName: name)
        CFPreferencesAppSynchronize(name as CFString)
        try? FileManager.default.removeItem(
            at: preferences.appendingPathComponent("\(name).plist")
        )
    }

    /// Removes every temp root under `temp` and every scratch
    /// plist under `preferences` whose owner pid `doomed` names.
    static func sweep(
        temp: URL,
        preferences: URL,
        doomed: (pid_t) -> Bool
    ) {
        let files = FileManager.default
        for entry in (try? files.contentsOfDirectory(atPath: temp.path)) ?? []
        {
            guard let pid = owner(of: entry, prefix: rootPrefix),
                doomed(pid)
            else { continue }
            try? files.removeItem(at: temp.appendingPathComponent(entry))
        }
        let plists =
            (try? files.contentsOfDirectory(atPath: preferences.path)) ?? []
        for entry in plists where entry.hasSuffix(".plist") {
            let name = String(entry.dropLast(".plist".count))
            guard let pid = owner(of: name, prefix: defaultsPrefix),
                doomed(pid)
            else { continue }
            if pid == getpid() {
                remove(name, preferences: preferences)
            } else {
                // Another process's domain: touching it through
                // cfprefsd would write it back, so the file alone.
                try? files.removeItem(
                    at: preferences.appendingPathComponent(entry)
                )
            }
        }
    }

    /// The pid `name` was minted under: the digits after
    /// `prefix`, ending the name or a `-`.
    static func owner(of name: String, prefix: String) -> pid_t? {
        guard name.hasPrefix(prefix) else { return nil }
        let digits = name.dropFirst(prefix.count)
            .prefix { $0 != "-" }
        guard !digits.isEmpty, digits.allSatisfy(\.isNumber) else {
            return nil
        }
        return pid_t(digits)
    }

    static func isAlive(_ pid: pid_t) -> Bool {
        kill(pid, 0) == 0 || errno == EPERM
    }
}
