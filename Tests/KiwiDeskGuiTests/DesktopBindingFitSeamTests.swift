import Foundation
import Testing

@testable import KiwiDeskCore

/// A Desktop binding's profile is read through ONE gate, which
/// refuses a profile saved for another screen count (#1394), so
/// a bound load always fits by count and no door marks clean or
/// dirty beside its apply (#1332). `DesktopBindingFitTests`
/// holds the behaviour; these clauses hold that every reader
/// still reaches the gate.
@Suite("A binding's profile has one gate (#1394)")
struct DesktopBindingFitSeamTests {
    private var coreRoot: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
    }

    private let gateHome = "Profiles/KiwiCore+DesktopBindingFit.swift"

    /// The three readers of a binding's profile: the two doors
    /// that LOAD it and the verdict that NAMES it. Spelled as the
    /// call, with its space, so the multi-line declaration never
    /// counts as a site.
    private let readers: [String: Int] = [
        "Profiles/KiwiCore+Desktops.swift": 1,
        "Profiles/KiwiCore+MonitorChange.swift": 1,
        "Profiles/KiwiCore+ProfileVerdict.swift": 1,
    ]

    private func sources() throws -> [(key: String, text: String)] {
        let root = coreRoot
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

    @Test("The gate is declared once, in its own home")
    func gateHasOneHome() throws {
        var homes: [String: Int] = [:]
        for (key, text) in try sources() {
            let hits = text.occurrences(of: "func boundProfile(")
            if hits > 0 { homes[key] = hits }
        }
        #expect(
            homes == [gateHome: 1],
            Comment(
                rawValue:
                    "boundProfile(of:) is the one gate a binding's "
                    + "profile passes (#1394); it moved or gained "
                    + "a twin"
            )
        )
    }

    @Test("Every reader of a binding's profile takes the gate")
    func readersTakeTheGate() throws {
        var callers: [String: Int] = [:]
        for (key, text) in try sources() {
            let hits = text.occurrences(of: "boundProfile(of: ")
            if hits > 0 { callers[key] = hits }
        }
        #expect(
            callers == readers,
            Comment(
                rawValue:
                    "a reader of a binding's profile joined or "
                    + "left; a new one takes boundProfile(of:) "
                    + "and joins this register (#1394)"
            )
        )
    }

    /// A file that resolves a binding does not read its profile
    /// beside the gate — a bare read is how a misfit got loaded
    /// — and the two doors mark nothing clean or dirty, since
    /// the apply judges the fit and a bound load fits by count
    /// (#1332). The monitor-change file keeps its marks: they
    /// belong to the MATCHING arms below the bound one.
    private let forbidden: [String: [String]] = [
        "Profiles/KiwiCore+Desktops.swift": [
            "profiles.read(", "markClean(", "markDirty(",
        ],
        "Profiles/KiwiCore+MonitorChange.swift": [
            "profiles.read("
        ],
        "Profiles/KiwiCore+ProfileVerdict.swift": [
            "profiles.read(", "markClean(", "markDirty(",
        ],
    ]

    @Test("No reader bypasses the gate or overrules the apply")
    func noBypassBesideTheGate() throws {
        for (key, text) in try sources() {
            guard let needles = forbidden[key] else { continue }
            for needle in needles {
                #expect(
                    text.occurrences(of: needle) == 0,
                    Comment(
                        rawValue:
                            "\(key) spells \(needle) beside the "
                            + "binding gate (#1394/#1332)"
                    )
                )
            }
        }
    }
}
