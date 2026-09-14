import Foundation
import Testing

/// Every read of a window's float FLAG in Core is classified, or
/// it reds (#1286). `EffectiveFloat.applies` — flag OR
/// floating-mode space — is what a float net asks, and each verb
/// or reader is ruled onto it one at a time; a bare `isFloating`
/// read that nobody classified is how the bar clamp (#1178), the
/// resize (#1184) and the ring and raise (#1286) each shipped a
/// floating-mode member treated as tiled. The roster of RULINGS
/// stays prose on `EffectiveFloat`; this is the census of
/// READERS, which prose cannot hold.
///
/// The lens, not the list: the scan finds every dotted
/// `.isFloating` spelling under `Sources/KiwiDeskCore` and pins a
/// per-file count with the class each file's reads belong to, so
/// a new reader in an unlisted file reds on arrival and a
/// vanished one reds too. It reads the SHAPE — that a file spells
/// the flag N times — never which answer it takes. Two blind
/// spots, stated: the needle counts the init's own assignment as
/// a read, and misses a dotless self-read inside a
/// `ManagedWindow` extension; and the classes are pinned by COUNT,
/// so a routed site that drops its `EffectiveFloat.applies(` call
/// stays green here — the consumer suites are that net, this one
/// is not.
@Suite("Float flag reader census")
struct FloatFlagReaderCensusTests {
    /// Why a site may read the flag. Not consulted by the scan —
    /// it is the classification the register carries, per site
    /// summed per file, so a new read in a mixed file has to say
    /// which class it joins rather than bump a number.
    enum Class {
        /// Defines, writes, detects or reports the flag itself.
        case identity
        /// A net or verb passing the flag INTO
        /// `EffectiveFloat.applies`.
        case routed
        /// "Is this a TILED member" — the negation the predicate's
        /// docstring refuses, since `!applies` calls an unknown
        /// window tiled.
        case tiledMember
        /// Ruled to stay on the flag (the docstring roster).
        case ruledToStay
    }

    /// Files reading `.isFloating`, each site classified.
    private let allowed: [String: [Class: Int]] = [
        "Models/WindowModel.swift": [.identity: 1],
        "State/WindowManager.swift": [.identity: 1],
        "State/StateCoordinator.swift": [.identity: 2],
        "Events/EventLoop+Tracking.swift": [.identity: 2],
        "Commands/KiwiCore+Commands.swift": [.identity: 2],
        "Commands/KiwiCore+Diagnostics.swift": [.identity: 1],
        "App/KiwiCore+FloatClamp.swift": [.routed: 1],
        "App/KiwiCore+FloatRecovery.swift": [.routed: 1],
        "App/KiwiCore+TravelerRehome.swift": [.routed: 1],
        // The delivery choice inside the net asks which ARM
        // floats the window (#498) — the flag's identity.
        "App/KiwiCore+FloatReanchor.swift": [.routed: 1, .identity: 1],
        "Tiling/TilingEngine+Stash.swift": [.routed: 1],
        // The one active-space door (#1286).
        "Tiling/KiwiCore+EffectiveFloat.swift": [.routed: 1],
        "Tiling/KiwiCore+Drag.swift": [.tiledMember: 1],
        "Commands/KiwiCore+Resize.swift": [.routed: 1],
        // The floor is routed; the targets stay the flag's.
        "Commands/KiwiCore+ZOrderFloatLayer.swift":
            [.routed: 1, .ruledToStay: 2],
        "State/StateCoordinator+EffectiveMembers.swift":
            [.tiledMember: 5],
        "State/StateCoordinator+WindowCreated.swift":
            [.tiledMember: 2],
        // Ruled to stay (#1362): an arrival on another display
        // follows the screen, since a floating-mode home assigns
        // no frame that could bring it over.
        "State/StateCoordinator+ScreenHome.swift": [.ruledToStay: 1],
        "Commands/KiwiCore+SpaceCommands.swift": [.tiledMember: 2],
        "Commands/KiwiCore+TrackNavigate.swift": [.tiledMember: 2],
        "Commands/KiwiCore+TrackSwap.swift": [.tiledMember: 2],
        "Commands/KiwiCore+ZOrder.swift": [.tiledMember: 1],
        "Tiling/KiwiCore+DragCrossing.swift": [.tiledMember: 1],
        "Tiling/KiwiCore+DragMove.swift": [.tiledMember: 1],
        // The float tier of directional focus: the tiled tier
        // already reaches a floating-mode space by live frame.
        "State/StateCoordinator+FloatFocus.swift": [.ruledToStay: 1],
        // The badge and its group-breaking (owner, 2026-09-13).
        "App/KiwiCore+SpaceBarItems.swift": [.ruledToStay: 2],
    ]

    private func pinned(_ file: String) -> Int? {
        allowed[file].map { $0.values.reduce(0, +) }
    }

    @Test("every .isFloating read in Core is classified")
    func everyReaderIsClassified() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
        let prefix = root.path + "/"
        var counts: [String: Int] = [:]
        for file in try SourceScan.swiftSources(under: root) {
            let key = String(file.path.dropFirst(prefix.count))
            let source = try SourceScan.strippedSource(at: file)
            let hits = source.occurrences(of: ".isFloating")
            guard hits > 0 else { continue }
            counts[key] = hits
        }
        // Non-vacuity: the scan saw the member derivations.
        #expect(
            counts["State/StateCoordinator+EffectiveMembers.swift"]
                != nil
        )
        for (file, count) in counts.sorted(by: { $0.key < $1.key }) {
            let unlisted =
                "\(file) reads the float flag \(count)× — ask "
                + "EffectiveFloat.applies (state-and-layout.md) or "
                + "classify and pin it here (#1286)"
            #expect(
                pinned(file) == count,
                Comment(rawValue: unlisted)
            )
        }
        for file in allowed.keys {
            let vanished =
                "\(file) no longer reads the flag \(pinned(file)!)× "
                + "— re-pin or drop its entry"
            #expect(
                counts[file] == pinned(file),
                Comment(rawValue: vanished)
            )
        }
    }
}
