import Foundation
import Testing

@testable import KiwiDeskCore

/// A Desktop binding's profile is read through ONE gate, which
/// refuses a profile saved for another screen count (#1394), so
/// a bound load always fits by count and no door marks clean or
/// dirty beside its apply (#1332). `DesktopBindingFitTests`
/// holds the behaviour; these clauses hold that every reader
/// still reaches the gate, and that the count judgement has one
/// home the GUI narrates rather than re-decides.
@Suite("A binding's profile has one gate (#1394)")
struct DesktopBindingFitSeamTests {
    private var repoRoot: URL {
        SourceScan.repoRoot(from: #filePath)
    }

    private let gateHome = "Profiles/KiwiCore+DesktopBindingFit.swift"

    /// Where the resolver is DECLARED; the one Core file that
    /// spells `mainDesktopBinding(` without loading anything.
    private let resolverHome = "Profiles/KiwiCore+DesktopBindings.swift"

    /// The count judgement's callers: the gate itself and the
    /// Desktops row's badge, which narrates its verdict.
    private let judgementCallers: [String: Int] = [
        "Sources/KiwiDeskCore/Profiles/KiwiCore+DesktopBindingFit.swift": 1,
        "Sources/KiwiDesk/Settings/Components/Profiles/DesktopsGroup.swift":
            1,
    ]

    private func sources(
        under subpath: String
    ) throws -> [(key: String, text: String)] {
        let root = repoRoot.appendingPathComponent(subpath)
        let prefix = root.path + "/"
        return try SourceScan.swiftSources(under: root).map { file in
            let text = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            let key =
                file.path.hasPrefix(prefix)
                ? String(file.path.dropFirst(prefix.count))
                : file.path
            return (key, text)
        }
    }

    @Test("The gate and the count judgement are declared once")
    func gateHasOneHome() throws {
        var gates: [String: Int] = [:]
        var judgements: [String: Int] = [:]
        for (key, text) in try sources(under: "Sources/KiwiDeskCore") {
            let gate = text.occurrences(of: "func boundProfile(")
            if gate > 0 { gates[key] = gate }
            let judgement = text.occurrences(
                of: "static func of(\n        profileCount:"
            )
            if judgement > 0 { judgements[key] = judgement }
        }
        #expect(
            gates == [gateHome: 1],
            Comment(
                rawValue:
                    "boundProfile(of:) is the one gate a binding's "
                    + "profile passes (#1394); it moved or gained "
                    + "a twin"
            )
        )
        #expect(
            judgements == [gateHome: 1],
            Comment(
                rawValue:
                    "DesktopBindingRefusal.of is the one count "
                    + "judgement (#1394); it moved or gained a twin"
            )
        )
    }

    /// A Core site that resolves the main Desktop's binding takes
    /// the gate before trusting its profile. Anchored on the
    /// RESOLVER rather than on a file list, so a fourth resolver
    /// in a new file is judged the same day it lands. The verdict
    /// takes its binding injected and is pinned by name below.
    @Test("Every resolver of a binding takes the gate")
    func resolversTakeTheGate() throws {
        var verdictTakesTheGate = false
        for (key, text) in try sources(under: "Sources/KiwiDeskCore") {
            if key == "Profiles/KiwiCore+ProfileVerdict.swift" {
                verdictTakesTheGate =
                    text.occurrences(of: "boundProfile(of: ") == 1
                continue
            }
            guard key != resolverHome,
                text.occurrences(of: "mainDesktopBinding(") > 0
            else { continue }
            #expect(
                text.occurrences(of: "boundProfile(of: ") > 0,
                Comment(
                    rawValue:
                        "\(key) resolves a binding but never asks "
                        + "boundProfile(of:) before trusting its "
                        + "profile (#1394)"
                )
            )
        }
        #expect(
            verdictTakesTheGate,
            Comment(
                rawValue:
                    "the verdict names a bound profile without "
                    + "asking the gate the live doors take (#1394)"
            )
        )
    }

    /// No profile file is read beside the gate — a bare read is
    /// how a misfit got loaded. Scoped to the BODY of each door
    /// that resolves a binding, since their files also host the
    /// explicit loads that must read; the verdict and the
    /// monitor-change ladder are read-free as whole files.
    private let readFreeBodies: [String: [String]] = [
        "Profiles/KiwiCore+Desktops.swift": [
            "func applyDesktopBinding("
        ],
        "Profiles/KiwiCore+Profiles.swift": [
            "func isProfileInEffect("
        ],
    ]
    private let readFreeFiles = [
        "Profiles/KiwiCore+ProfileVerdict.swift",
        "Profiles/KiwiCore+MonitorChange.swift",
    ]

    @Test("No reader of a binding reads a profile file itself")
    func noReadBesideTheGate() throws {
        for (key, text) in try sources(under: "Sources/KiwiDeskCore") {
            if readFreeFiles.contains(key) {
                #expect(
                    text.occurrences(of: "profiles.read(") == 0,
                    Comment(
                        rawValue:
                            "\(key) reads a profile file beside "
                            + "the binding gate (#1394)"
                    )
                )
            }
            for door in readFreeBodies[key] ?? [] {
                let body = SourceScan.declarationBody(
                    after: door,
                    in: text
                )
                #expect(
                    body != nil,
                    Comment(
                        rawValue:
                            "cannot find the body of '\(door)' — "
                            + "if it was re-signed, re-pin it here"
                    )
                )
                #expect(
                    (body?.occurrences(of: "profiles.read(") ?? 0)
                        == 0,
                    Comment(
                        rawValue:
                            "'\(door)' reads a profile file beside "
                            + "the binding gate (#1394)"
                    )
                )
            }
        }
    }

    @Test("The count judgement has its two known callers")
    func judgementCallersAreCounted() throws {
        var callers: [String: Int] = [:]
        for subpath in ["Sources/KiwiDeskCore", "Sources/KiwiDesk"] {
            for (key, text) in try sources(under: subpath) {
                let hits = text.occurrences(
                    of: "DesktopBindingRefusal.of("
                )
                if hits > 0 { callers["\(subpath)/\(key)"] = hits }
            }
        }
        #expect(
            callers == judgementCallers,
            Comment(
                rawValue:
                    "a caller of the count judgement joined or "
                    + "left; the GUI narrates the verdict through "
                    + "it and never re-derives it (#1394)"
            )
        )
    }

    /// The binding door marks nothing: the apply judges the #36
    /// fit, and a bound load fits by count (#1332). Scoped to the
    /// door's BODY, since its file hosts the whole Desktop-switch
    /// path.
    @Test("The binding door marks nothing clean or dirty")
    func bindingDoorMarksNothing() throws {
        let file = repoRoot.appendingPathComponent(
            "Sources/KiwiDeskCore/Profiles/KiwiCore+Desktops.swift"
        )
        let source = SourceScan.stripComments(
            try String(contentsOf: file, encoding: .utf8)
        )
        let door = "func applyDesktopBinding("
        let body = SourceScan.declarationBody(after: door, in: source)
        #expect(
            body != nil,
            Comment(
                rawValue:
                    "cannot find the body of '\(door)' — if the "
                    + "door was re-signed, re-pin it here"
            )
        )
        for verb in ["markClean(", "markDirty("] {
            #expect(
                (body?.occurrences(of: verb) ?? 0) == 0,
                Comment(
                    rawValue:
                        "\(verb) overrules the apply's fit verdict "
                        + "inside the binding door (#1332)"
                )
            )
        }
    }
}
