import Foundation
import Testing

/// `RetilePass` (#1488) is a choice every non-event retile
/// spells at its call site: `.apply` re-issues every frame AND
/// probes past corroborated bounds (#1055), `.reissue` re-issues
/// alone. The probe used to ride the re-issue flag, and a Space
/// switch that needed only the re-issue probed too — under which
/// the automatic track count and every heal stand down, so each
/// return redrew the overlap the heal had removed. Nothing about
/// the wrong case LOOKS wrong: it compiles, the frames go out,
/// and the damage is a count one track too wide on a real
/// screen. So the map below is the control: a file that spells
/// either case fails here until its author says which it is and
/// why — per file, per case, with today's exact counts, so an
/// unlisted site fails on arrival and a listed one that lost
/// its spelling (a switch quietly back on a bare `retile()`, or
/// on `.apply`) fails too.
///
/// The `BatchSizingRoutingTests` shape; `RetilePass`'s doc
/// comment and state-and-layout.md point here rather than
/// keeping a second copy of the list.
@Suite("Retile pass routing (#1488)")
struct RetilePassRoutingTests {
    private struct Site: Equatable {
        let applies: Int
        let reissues: Int
    }

    private var sourcesRoot: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources")
    }

    /// Every file that may spell a pass, by path under `Sources`,
    /// with today's exact counts and its reason. Anything absent
    /// must spell neither.
    private let allowed: [String: Site] = [
        // `.apply` — an explicit apply (§5): a `set_*` verb, a
        // profile or config apply, a restore, a reset.
        "KiwiDeskCore/App/KiwiCore+BackupRestore.swift":
            Site(applies: 1, reissues: 0),
        "KiwiDeskCore/App/KiwiCore+GuiConfig.swift":
            Site(applies: 1, reissues: 0),
        "KiwiDeskCore/App/KiwiCore+Reset.swift":
            Site(applies: 1, reissues: 0),
        "KiwiDeskCore/Commands/KiwiCore+Commands.swift":
            Site(applies: 1, reissues: 0),
        "KiwiDeskCore/Commands/KiwiCore+GapCommands.swift":
            Site(applies: 2, reissues: 0),
        "KiwiDeskCore/Commands/KiwiCore+LayoutCommands.swift":
            Site(applies: 1, reissues: 0),
        "KiwiDeskCore/Commands/KiwiCore+SpaceDisplayCommands.swift":
            Site(applies: 1, reissues: 0),
        "KiwiDeskCore/Commands/KiwiCore+SpaceLifecycleCommands.swift":
            Site(applies: 2, reissues: 0),
        // Profile applies classify themselves through
        // `forceRetile` (profiles.md); both spellings are the
        // one ternary each.
        "KiwiDeskCore/Profiles/KiwiCore+ProfileResolution.swift":
            Site(applies: 2, reissues: 0),

        // `.reissue` — a Space or Desktop activation, whose
        // lagging echoes would strand windows behind the
        // "already there" check, and which asks for no probe.
        "KiwiDeskCore/Commands/KiwiCore+SpaceTransition.swift":
            Site(applies: 0, reissues: 1),
        // The switch's 300 ms settle re-issue (#207).
        "KiwiDeskCore/Commands/KiwiCore+SpaceFocusHandoff.swift":
            Site(applies: 0, reissues: 1),
        // The native Desktop switch and the secondary-display
        // switch it drives (#888).
        "KiwiDeskCore/Profiles/KiwiCore+Desktops.swift":
            Site(applies: 0, reissues: 2),
        // The Desktop switch's settle.
        "KiwiDeskCore/Profiles/KiwiCore+DesktopSettle.swift":
            Site(applies: 0, reissues: 1),
        // A drag across displays activates the destination Space
        // (and its revert the origin's); a membership move must
        // apply exactly, and neither is an apply.
        "KiwiDeskCore/Tiling/KiwiCore+DragCrossing.swift":
            Site(applies: 0, reissues: 2),
        // The Space Bar drop activates the target.
        "KiwiDeskCore/Bar/KiwiCore+SpaceBarDrop.swift":
            Site(applies: 0, reissues: 1),
    ]

    private static let applyPattern = "pass: \\.apply\\b|\\? \\.apply\\b"
    private static let reissuePattern = "pass: \\.reissue\\b"
    /// The retired spelling: a `retile(force:` would not compile
    /// today, but a re-added `force` parameter would.
    private static let retiredPattern = "retile\\([^)]*force:"

    @Test("Every spelled pass is a listed one, and the list is exact")
    func passesStayInsideTheAllowlist() throws {
        var found: [String: Site] = [:]
        let root = sourcesRoot
        let prefix = root.path + "/"
        for file in try SourceScan.swiftSources(under: root) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            let site = Site(
                applies: Self.matches(Self.applyPattern, in: source),
                reissues: Self.matches(
                    Self.reissuePattern,
                    in: source
                )
            )
            let retired =
                "\(file.lastPathComponent) spells retile(force:)"
            #expect(
                Self.matches(Self.retiredPattern, in: source) == 0,
                Comment(rawValue: retired)
            )
            guard site != Site(applies: 0, reissues: 0)
            else { continue }
            let key =
                file.path.hasPrefix(prefix)
                ? String(file.path.dropFirst(prefix.count))
                : file.path
            found[key] = site
        }
        #expect(!found.isEmpty, "the scan reached no site at all")
        for (file, site) in found.sorted(by: { $0.key < $1.key }) {
            let unlisted =
                "\(file) spells .apply \(site.applies) time(s) and "
                + ".reissue \(site.reissues) — classify it (#1488) "
                + "and re-pin the counts here"
            #expect(
                allowed[file] == site,
                Comment(rawValue: unlisted)
            )
        }
        for (file, expected) in allowed {
            let vanished =
                "\(file) no longer matches its entry "
                + "(\(expected.applies) applies, "
                + "\(expected.reissues) reissues) — drop or re-pin it"
            #expect(
                found[file] == expected,
                Comment(rawValue: vanished)
            )
        }
    }

    private static func matches(
        _ pattern: String,
        in source: String
    ) -> Int {
        guard let regex = try? NSRegularExpression(pattern: pattern)
        else { return 0 }
        return regex.numberOfMatches(
            in: source,
            range: NSRange(source.startIndex..., in: source)
        )
    }
}
