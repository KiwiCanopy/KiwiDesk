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
    ) -> Outcome {
        guard
            let listing = host.run(
                ["property", "--get", "UserKeyMapping"]
            )
        else { return .failed }
        let current = pairs(inHidutilOutput: listing)
        let plan = plan(
            current: current,
            written: host.readWritten(),
            want: want
        )
        if plan == .refuse {
            // A record of ours the mapping no longer holds is
            // stale: someone else replaced it.
            host.writeWritten(nil)
            return .refused
        }
        if let argument = setArgument(for: plan) {
            guard host.run(["property", "--set", argument]) != nil
            else { return .failed }
        }
        if case .set(let pair) = plan { host.writeWritten(pair) }
        if plan == .clear { host.writeWritten(nil) }
        return want == nil ? .off : .on
    }

    /// What `apply` did, as structure for the GUI (#96).
    enum Outcome: Equatable {
        case on, off
        /// A mapping KiwiDesk did not write is in place.
        case refused
        /// `hidutil` did not answer.
        case failed
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
            guard (try? process.run()) != nil else { return nil }
            let data = out.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            return String(decoding: data, as: UTF8.self)
        },
        readWritten: {
            let raw = UserDefaults.standard.array(forKey: recordKey)
            guard let values = raw as? [UInt64], values.count == 2
            else { return nil }
            return HyperKeyRemap.Pair(
                source: values[0],
                destination: values[1]
            )
        },
        writeWritten: { pair in
            guard let pair else {
                UserDefaults.standard.removeObject(forKey: recordKey)
                return
            }
            UserDefaults.standard.set(
                [pair.source, pair.destination],
                forKey: recordKey
            )
        }
    )
}
