import AppKit
import Foundation

/// The user's Apple Shortcuts, read and run through
/// `/usr/bin/shortcuts` as an argument list, never a shell
/// (#3526). Every child goes through `ExecLauncher`, so nothing
/// here blocks the main actor; Core hands plain names and the GUI
/// narrates them.
@MainActor
public final class AppleShortcuts {
    /// The tool the Shortcuts app ships; a test core pins another.
    var tool = "/usr/bin/shortcuts"
    /// Bounds a hung run, and how long dedup holds its name; a
    /// shortcut asking for input may wait on the user that long.
    static let runTimeout: TimeInterval = 120
    /// Bounds a hung `shortcuts list`, measured at 0.01 s.
    static let listTimeout: TimeInterval = 10
    /// The Shortcuts app, whose deactivation may follow an edit.
    static let appBundleID = "com.apple.shortcuts"

    private let exec: ExecLauncher
    /// The last list read, nil until one finished.
    public private(set) var names: Set<String>?
    /// Callers waiting on the list read in flight.
    private var waiting: [@MainActor ([String]?) -> Void] = []
    private var observer: NSObjectProtocol?

    init(exec: ExecLauncher) {
        self.exec = exec
    }

    isolated deinit {
        if let observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    /// Reads the list now and again each time the Shortcuts app
    /// leaves the front, where a shortcut may have been renamed,
    /// added or deleted.
    func watch() {
        guard observer == nil else { return }
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didDeactivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let app =
                note.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication
            let id = app?.bundleIdentifier
            MainActor.assumeIsolated {
                if id?.lowercased() == Self.appBundleID {
                    self?.refresh()
                }
            }
        }
        refresh()
    }

    /// Re-reads the list; `done` gets it sorted, nil where the
    /// read failed. Concurrent calls share one child.
    public func refresh(
        _ done: (@MainActor ([String]?) -> Void)? = nil
    ) {
        if let done { waiting.append(done) }
        let pid = exec.launch(
            argv: tool,
            ["list"],
            timeout: Self.listTimeout,
            dedup: true
        ) { [weak self] code, out, _ in
            self?.listed(code == 0 ? Self.parse(out) : nil)
        }
        // A read already in flight answers every waiter.
        if pid == nil, !exec.isRunning(argv: tool, ["list"]) {
            listed(nil)
        }
    }

    /// The list, read fresh; nil where it could not be read.
    public func list() async -> [String]? {
        await withCheckedContinuation { continuation in
            refresh { continuation.resume(returning: $0) }
        }
    }

    /// Runs `name`; the list is re-read once the run ends, so a
    /// rename the run itself made is seen.
    @discardableResult
    func run(_ name: String) -> Bool {
        exec.launch(
            argv: tool,
            ["run", name],
            timeout: Self.runTimeout,
            dedup: true
        ) { [weak self] _, _, _ in
            self?.refresh()
        } != nil
    }

    private func listed(_ list: [String]?) {
        if let list { names = Set(list) }
        let callers = waiting
        waiting = []
        callers.forEach { $0(list) }
    }

    /// One name per line; blank lines dropped, order by name.
    static func parse(_ output: String) -> [String] {
        let names = output.split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return Array(Set(names)).sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        }
    }

    #if DEBUG
        /// Tests only: stands a list in as read.
        func setNamesForTesting(_ list: [String]?) {
            names = list.map(Set.init)
        }
    #endif
}
