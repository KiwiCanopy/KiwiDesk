import Foundation

/// The `hidutil` key remap behind the Hyper key (#1870): the
/// source key becomes F18 for every keyboard, per user, with no
/// permission, until it is cleared or the Mac restarts.
///
/// KiwiDesk owns the mapping only while it is exactly the entry
/// KiwiDesk RECORDED writing — never judged by its shape, since
/// Caps Lock → F18 is a common Hammerspoon setup. A mapping
/// another tool or the user set is never overwritten or cleared:
/// the remap is refused and the Hyper key stays off.
enum HyperKeyRemap {
    /// One `UserKeyMapping` entry, as HID usage codes.
    struct Pair: Hashable {
        var source: UInt64
        var destination: UInt64
    }

    /// What applying `want` over the current mapping does.
    enum Plan: Equatable {
        /// Already as wanted.
        case none
        /// Write exactly KiwiDesk's one entry.
        case set(Pair)
        /// Remove KiwiDesk's own entries.
        case clear
        /// A mapping KiwiDesk did not write is present.
        case refuse
    }

    /// Full HID usage of a keyboard-page (0x07) key.
    static func usage(_ code: UInt64) -> UInt64 {
        0x7_0000_0000 | code
    }

    /// `written` is the entry KiwiDesk last wrote and has not
    /// cleared, persisted across a crash (`HyperRemapRecord`).
    static func plan(
        current: Set<Pair>,
        written: Pair?,
        want: HyperSourceKey?
    ) -> Plan {
        let ours =
            current.isEmpty || written.map { current == [$0] } == true
        guard ours else { return .refuse }
        guard let want, want != .f18 else {
            return current.isEmpty ? .none : .clear
        }
        let pair = pair(for: want)
        return current == [pair] ? .none : .set(pair)
    }

    /// The key a full HID usage names, through `usage(_:)` alone;
    /// nil for a key that cannot be Hyper.
    static func key(atUsage full: UInt64) -> HyperSourceKey? {
        HyperSourceKey.allCases.first { usage($0.hidUsage) == full }
    }

    /// The one foreign entry as keys the GUI can name (#2470); nil
    /// for several entries or a key outside `HyperSourceKey`, so a
    /// reader falls back to the unnamed sentence.
    static func foreign(in current: Set<Pair>) -> HyperForeignRemap? {
        guard current.count == 1, let pair = current.first,
            let source = key(atUsage: pair.source),
            let destination = key(atUsage: pair.destination)
        else { return nil }
        return HyperForeignRemap(source: source, destination: destination)
    }

    static func pair(for key: HyperSourceKey) -> Pair {
        Pair(
            source: usage(key.hidUsage),
            destination: usage(HyperSourceKey.triggerUsage)
        )
    }

    /// Reads every entry `hidutil property --get UserKeyMapping`
    /// lists. The output is one block per keyboard service, so
    /// the same entry repeats; a `(null)` service lists none, and
    /// an entry's two keys come in either order (`Dst` first on
    /// macOS 27).
    static func pairs(inHidutilOutput text: String) -> Set<Pair> {
        var pairs = Set<Pair>()
        var source: UInt64?
        var destination: UInt64?
        for line in text.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("}") {
                if let source, let destination {
                    pairs.insert(
                        Pair(source: source, destination: destination)
                    )
                }
                (source, destination) = (nil, nil)
                continue
            }
            let junk = CharacterSet.whitespaces.union(
                CharacterSet(charactersIn: ";")
            )
            let parts = trimmed.split(separator: "=").map {
                $0.trimmingCharacters(in: junk)
            }
            guard parts.count == 2, let value = UInt64(parts[1])
            else { continue }
            switch parts[0] {
            case "HIDKeyboardModifierMappingSrc": source = value
            case "HIDKeyboardModifierMappingDst": destination = value
            default: continue
            }
        }
        return pairs
    }

    /// The `--set` argument for `plan`, nil where nothing runs.
    static func setArgument(for plan: Plan) -> String? {
        switch plan {
        case .none, .refuse:
            return nil
        case .clear:
            return #"{"UserKeyMapping":[]}"#
        case .set(let pair):
            return #"{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":"#
                + "\(pair.source)"
                + #","HIDKeyboardModifierMappingDst":"#
                + "\(pair.destination)}]}"
        }
    }
}

extension HyperKeyRemap {
    /// The host the remap runs on: `hidutil` and the record of
    /// what KiwiDesk wrote, which outlives a crash. A production
    /// default that changes live per-user state, so both
    /// `makeTestCore` twins pin it inert (tests.md, machine
    /// touch).
    struct Host {
        /// Runs `hidutil` with the arguments; its output, or nil
        /// where it failed.
        var run: ([String]) -> String?
        var readWritten: () -> Pair?
        var writeWritten: (Pair?) -> Void
    }

    /// Applies `want` and answers the outcome. Synchronous: a
    /// `hidutil` call takes milliseconds, and `stop()` must see
    /// the mapping cleared before the process exits.
    @MainActor
    static func apply(
        _ want: HyperSourceKey?,
        on host: Host
    ) -> HyperKeyStatus {
        guard
            let listing = host.run(
                ["property", "--get", "UserKeyMapping"]
            )
        else { return .failed }
        let current = pairs(inHidutilOutput: listing)
        // An empty mapping holds nothing of ours: a record beside
        // it would later claim another tool's identical entry.
        if current.isEmpty { host.writeWritten(nil) }
        let plan = plan(
            current: current,
            written: host.readWritten(),
            want: want
        )
        if plan == .refuse {
            // A record of ours the mapping no longer holds is
            // stale: someone else replaced it.
            host.writeWritten(nil)
            return .refused(foreign(in: current))
        }
        let before = host.readWritten()
        // Recorded ahead of the set: a timed-out set may still
        // land, and an unrecorded mapping of ours would be refused
        // as another tool's for good.
        if case .set(let pair) = plan { host.writeWritten(pair) }
        if let argument = setArgument(for: plan),
            host.run(["property", "--set", argument]) == nil
        {
            settleRecord(after: plan, previous: before, on: host)
            return .failed
        }
        if plan == .clear { host.writeWritten(nil) }
        return want == nil ? .off : .on
    }

    /// After a set that did not answer, the record names what the
    /// mapping now holds of ours: the new entry, the previous one,
    /// or nothing.
    @MainActor
    private static func settleRecord(
        after plan: Plan,
        previous: Pair?,
        on host: Host
    ) {
        let now = host.run(["property", "--get", "UserKeyMapping"])
            .map { pairs(inHidutilOutput: $0) }
        if case .set(let pair) = plan, now == [pair] { return }
        if let previous, now == [previous] {
            host.writeWritten(previous)
        } else {
            host.writeWritten(nil)
        }
    }

}

extension HyperKeyRemap {
    /// The stored record: the entry and the boot session it was
    /// written in. A `hidutil` mapping dies at a restart and the
    /// record does not, so a record from another boot names a
    /// mapping that is gone — and a mapping with its shape now is
    /// another tool's, never KiwiDesk's. The boot is
    /// `kern.bootsessionuuid`, never `kern.boottime`, which a
    /// clock step moves: a live record read as foreign would leave
    /// the key remapped after quit.
    static func record(_ pair: Pair, boot: String) -> [String: Any] {
        [
            "source": NSNumber(value: pair.source),
            "destination": NSNumber(value: pair.destination),
            "boot": boot,
        ]
    }

    /// The entry a stored record names, nil where it is from
    /// another boot, the boot is unreadable, or the record is.
    static func recorded(_ raw: [String: Any]?, boot: String?) -> Pair? {
        guard let raw, let boot, raw["boot"] as? String == boot,
            let source = raw["source"] as? NSNumber,
            let destination = raw["destination"] as? NSNumber
        else { return nil }
        return Pair(
            source: source.uint64Value,
            destination: destination.uint64Value
        )
    }

    /// This boot's session id, nil where the sysctl fails.
    static func bootSession() -> String? {
        let name = "kern.bootsessionuuid"
        var size = 0
        let probed = sysctlbyname(name, nil, &size, nil, 0)
        guard probed == 0, size > 1 else { return nil }
        var bytes = [UInt8](repeating: 0, count: size)
        let read = sysctlbyname(name, &bytes, &size, nil, 0)
        guard read == 0 else { return nil }
        return String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
    }
}

extension HyperKeyRemap.Host {
    private static let recordKey = "HyperKeyRemapWritten"

    @MainActor static let live = Self(
        run: { arguments in
            let process = Process()
            process.executableURL = URL(
                fileURLWithPath: "/usr/bin/hidutil"
            )
            process.arguments = arguments
            let out = Pipe()
            process.standardOutput = out
            process.standardError = FileHandle.nullDevice
            let exited = DispatchSemaphore(value: 0)
            process.terminationHandler = { _ in exited.signal() }
            guard (try? process.run()) != nil else { return nil }
            // Drained beside the wait, so a long listing cannot
            // fill the pipe and stall the exit.
            nonisolated(unsafe) var data = Data()
            let drained = DispatchGroup()
            drained.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                data = out.fileHandleForReading.readDataToEndOfFile()
                drained.leave()
            }
            // A wedged hidd must not freeze boot or quit.
            guard exited.wait(timeout: .now() + 2) == .success else {
                process.terminate()
                return nil
            }
            drained.wait()
            guard process.terminationStatus == 0 else { return nil }
            return String(decoding: data, as: UTF8.self)
        },
        readWritten: {
            HyperKeyRemap.recorded(
                UserDefaults.standard.dictionary(forKey: recordKey),
                boot: HyperKeyRemap.bootSession()
            )
        },
        writeWritten: { pair in
            guard let pair else {
                UserDefaults.standard.removeObject(forKey: recordKey)
                return
            }
            // No boot to stamp: write nothing a later read would
            // have to trust.
            guard let boot = HyperKeyRemap.bootSession() else {
                UserDefaults.standard.removeObject(forKey: recordKey)
                return
            }
            UserDefaults.standard.set(
                HyperKeyRemap.record(pair, boot: boot),
                forKey: recordKey
            )
        }
    )
}
