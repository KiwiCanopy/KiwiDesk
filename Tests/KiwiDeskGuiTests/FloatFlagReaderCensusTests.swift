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
/// The lens, not the list: the scan finds every `.isFloating`
/// read under `Sources/KiwiDeskCore` and pins a per-file count
/// with the class each file's reads belong to, so a new reader in
/// an unlisted file reds on arrival and a vanished one reds too.
/// It reads the SHAPE — that a file asks the flag N times — never
/// which answer it takes; the consumer suites hold the answers.
@Suite("Float flag reader census")
struct FloatFlagReaderCensusTests {
    /// Why a file may read the flag. Not consulted by the scan —
    /// it is the classification the register carries so a new
    /// entry has to state one.
    enum Class {
        /// Defines, writes, detects or reports the flag itself.
        case identity
        /// A net or verb already passing the flag INTO
        /// `EffectiveFloat.applies`.
        case routed
        /// "Is this a TILED member" — the negation the predicate's
        /// docstring refuses, since `!applies` calls an unknown
        /// window tiled.
        case tiledMember
        /// Ruled to stay on the flag (the docstring roster).
        case ruledToStay
    }

    /// Files reading `.isFloating`, with today's count and class.
    private let allowed: [String: (Int, Class)] = [
        "Models/WindowModel.swift": (1, .identity),
        "State/WindowManager.swift": (1, .identity),
        "State/StateCoordinator.swift": (2, .identity),
        "Events/EventLoop+Tracking.swift": (2, .identity),
        "Commands/KiwiCore+Commands.swift": (2, .identity),
        "Commands/KiwiCore+Diagnostics.swift": (1, .identity),
        "App/KiwiCore+FloatClamp.swift": (1, .routed),
        "App/KiwiCore+FloatRecovery.swift": (1, .routed),
        "App/KiwiCore+TravelerRehome.swift": (1, .routed),
        // One routed, one choosing the delivery inside it (#498).
        "App/KiwiCore+FloatReanchor.swift": (2, .routed),
        "Tiling/TilingEngine+Stash.swift": (1, .routed),
        // The drop's routed read and the drag's membership chain.
        "Tiling/KiwiCore+Drag.swift": (2, .routed),
        "Commands/KiwiCore+Resize.swift": (1, .routed),
        "App/KiwiCore+Borders.swift": (1, .routed),
        "Commands/KiwiCore+ZOrderFloats.swift": (1, .routed),
        // The floor is routed; the targets stay the flag's.
        "Commands/KiwiCore+ZOrderFloatLayer.swift": (3, .routed),
        "State/StateCoordinator+EffectiveMembers.swift":
            (5, .tiledMember),
        "State/StateCoordinator+WindowCreated.swift":
            (2, .tiledMember),
        // Deferred to #1362 (arrival on another display).
        "State/StateCoordinator+ScreenHome.swift": (1, .tiledMember),
        "Commands/KiwiCore+SpaceCommands.swift": (2, .tiledMember),
        "Commands/KiwiCore+TrackNavigate.swift": (2, .tiledMember),
        "Commands/KiwiCore+TrackSwap.swift": (2, .tiledMember),
        "Commands/KiwiCore+ZOrder.swift": (1, .tiledMember),
        "Tiling/KiwiCore+DragCrossing.swift": (1, .tiledMember),
        "Tiling/KiwiCore+DragMove.swift": (1, .tiledMember),
        // The float tier of directional focus: the tiled tier
        // already reaches a floating-mode space by live frame.
        "State/StateCoordinator+FloatFocus.swift": (1, .ruledToStay),
        // The badge and its group-breaking (owner, 2026-09-13).
        "App/KiwiCore+SpaceBarItems.swift": (2, .ruledToStay),
    ]

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
        // Non-vacuity: the scan saw the readers the roster names.
        #expect(counts["Tiling/KiwiCore+Drag.swift"] != nil)
        for (file, count) in counts.sorted(by: { $0.key < $1.key }) {
            let unlisted =
                "\(file) reads the float flag \(count)× — ask "
                + "EffectiveFloat.applies (state-and-layout.md) or "
                + "classify and pin it here (#1286)"
            #expect(
                allowed[file]?.0 == count,
                Comment(rawValue: unlisted)
            )
        }
        for (file, entry) in allowed {
            let vanished =
                "\(file) no longer reads the flag \(entry.0)× — "
                + "re-pin or drop its entry"
            #expect(
                counts[file] == entry.0,
                Comment(rawValue: vanished)
            )
        }
    }
}
