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
        let active = vision.active.lensName.map {
            $0.caseInsensitiveCompare(lens.name) == .orderedSame
        }
        // The lens on always turns off; a refusal binds only on the
        // way in.
        if active != true, let refusal = lensRefusal(lens) {
            switch refusal {
            case .noApps: return .fail("\(lens.name) has no apps yet")
            }
        }
        setVision(active == true ? .off : .lens(lens.name))
        return toggleAnswer()
    }

    /// Why `lens` cannot turn on, nil where it can: the one verdict
    /// every gate and picker reads.
    public func lensRefusal(_ lens: VisionLens) -> LensRefusal? {
        lens.apps.isEmpty ? .noApps : nil
    }

    /// Every lens in stored order, with its verdict.
    public var kiwiVisionLensChoices: [VisionLensChoice] {
        appWide.visionLenses.map {
            VisionLensChoice(name: $0.name, refusal: lensRefusal($0))
        }
    }

    /// Sets what KiwiVision draws — a pick, never a toggle, so the
    /// lens on stays on. A lens that is gone or refused changes
    /// nothing; KiwiHub greys it first.
    public func setKiwiVision(_ next: VisionActive) {
        guard case .lens(let name) = next else {
            setVision(next)
            return
        }
        guard let lens = appWide.lens(named: name), lensRefusal(lens) == nil
        else { return }
        setVision(.lens(lens.name))
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
            guard let name = args.first?.stringValue else {
                return .fail("expected a lens name")
            }
            guard appWide.lens(named: name) != nil else {
                return .fail("no lens named \(name)")
            }
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
        guard let data else {
            return .fail("expected a lens table with a name")
        }
        var lens: VisionLens
        do {
            lens = try JSONDecoder().decode(VisionLens.self, from: data)
        } catch {
            return .fail("not a lens: \(Self.decodeProblem(error))")
        }
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

    /// The field a lens table got wrong, in English for the CLI.
    private static func decodeProblem(_ error: Error) -> String {
        switch error as? DecodingError {
        case .keyNotFound(let key, _)?:
            return "missing \(key.stringValue)"
        case .typeMismatch(_, let context)?, .dataCorrupted(let context)?:
            let path = context.codingPath.map(\.stringValue)
            return path.isEmpty
                ? "unreadable" : "bad \(path.joined(separator: "."))"
        case .valueNotFound(_, let context)?:
            return "missing \(context.codingPath.map(\.stringValue))"
        default:
            return "unreadable"
        }
    }

    /// A title change of a window a lens judges by title re-masks
    /// the plates (#2103 ruling 32): a browser's title follows its
    /// tab.
    func noteVisionTitleChanged(_ id: WindowID) {
        guard vision.isOn, let window = state.windows[id] else { return }
        let app = AppRef(bundleID: window.appBundleID, name: window.appName)
        guard case .titled = visionLensClear(app) else { return }
        oweVisionReshape(list: false)
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
    /// The windows whose title holds one of these, as a Float rule
    /// matches (`WindowTitleMatch`).
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
                WindowTitleMatch.matches(title, $0)
            }
        }
    }
}
