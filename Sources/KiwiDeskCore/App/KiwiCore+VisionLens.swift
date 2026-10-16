import Foundation

/// KiwiVision lenses (#2103 v3): turning one on, defining and
/// deleting one, and which windows a lens keeps clear.
extension KiwiCore {
    /// `kiwivision.toggle(lens?)`. Bare, it turns KiwiVision on or
    /// off. Named, it turns that lens on — from off, plain or
    /// another lens — and the active lens's own toggle turns
    /// KiwiVision off (ruling 11). A lens with no apps refuses
    /// (ruling 37).
    func toggleCommand(_ name: String?) -> CommandResponse {
        guard let name else {
            setVision(vision.isOn ? .off : .plain)
            return toggleAnswer()
        }
        guard let lens = appWide.lens(named: name) else {
            return .fail("no lens named \(name)")
        }
        guard !lens.apps.isEmpty else {
            return .fail("\(lens.name) has no apps yet")
        }
        let active = vision.active.lensName.map {
            $0.caseInsensitiveCompare(lens.name) == .orderedSame
        }
        setVision(active == true ? .off : .lens(lens.name))
        return toggleAnswer()
    }

    private func toggleAnswer() -> CommandResponse {
        var answer: [String: JSONValue] = ["on": .bool(vision.isOn)]
        if let lens = visionLensName { answer["lens"] = .string(lens) }
        return .ok(.object(answer))
    }

    /// `kiwivision.define_lens{…}` adds a lens or replaces the one
    /// of its name; `kiwivision.delete_lens(name)` removes one. A
    /// session value, as every app-wide verb's (ruling 40): a
    /// Lua-owned setup defines its lenses on every load.
    func lensCommand(
        _ command: String,
        _ args: [JSONValue]
    ) -> CommandResponse {
        if command == "kiwivision.delete_lens" {
            guard let name = args.first?.stringValue,
                appWide.lens(named: name) != nil
            else { return .fail("expected a lens name") }
            setAppWide(persisting: false) {
                $0.visionLenses.removeAll {
                    $0.name.caseInsensitiveCompare(
                        AppWideSettings.lensName(name)
                    ) == .orderedSame
                }
            }
            return .ok()
        }
        // A Lua table arrives as an object, the CLI's as its JSON.
        let data: Data?
        switch args.first {
        case .object?: data = try? JSONEncoder().encode(args[0])
        case .string(let json)?: data = Data(json.utf8)
        default: data = nil
        }
        guard let data,
            var lens = try? JSONDecoder().decode(
                VisionLens.self,
                from: data
            )
        else { return .fail("expected a lens table with a name") }
        lens.name = AppWideSettings.lensName(lens.name)
        guard !lens.name.isEmpty else {
            return .fail("expected a lens table with a name")
        }
        setAppWide(persisting: false) { settings in
            var lenses = settings.visionLenses
            if let index = lenses.firstIndex(where: {
                $0.name.caseInsensitiveCompare(lens.name) == .orderedSame
            }) {
                lenses[index] = lens
            } else {
                lenses.append(lens)
            }
            settings.visionLenses = AppWideSettings.lensEntries(lenses)
        }
        return .ok()
    }

    /// What the active lens keeps clear of `app`'s windows: all of
    /// them, those whose title holds one of the patterns, or none
    /// (ruling 32).
    func visionLensClear(_ app: AppRef) -> VisionLensClear {
        guard let lens = visionLook.lens,
            lens.apps.contains(app.listKey)
        else { return .none }
        guard let patterns = lens.titles[app.listKey], !patterns.isEmpty
        else { return .all }
        return .titled(patterns)
    }
}

/// A lens member's clear windows (ruling 32).
enum VisionLensClear: Equatable {
    case none
    case all
    /// The windows whose title holds one of these, ignoring case.
    case titled([String])

    /// Whether a window titled `title` stays clear: a title the
    /// read did not carry matches no pattern.
    func clears(title: String?) -> Bool {
        switch self {
        case .none: return false
        case .all: return true
        case .titled(let patterns):
            guard let title else { return false }
            return patterns.contains {
                title.localizedCaseInsensitiveContains($0)
            }
        }
    }
}
