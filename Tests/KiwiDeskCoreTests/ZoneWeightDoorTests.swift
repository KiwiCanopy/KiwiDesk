import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Every weight door of a zone laid by floor and weight moves the
/// pressed window the way the press asks, or cues (#2967): seeded
/// `resize` presses through the real writers, whole-zone and run
/// alike, on a Stack zone and a fixed Grid's last row, read off the
/// frames the render draws. The display, gaps and floor are pinned
/// (#531, #660); a failure names its seed and step, so it replays.
@Suite(
    "Zone weight doors keep the press's sense (#2967)",
    .serialized,
    .enabled(if: NSScreen.main != nil)
)
@MainActor
struct ZoneWeightDoorTests {
    private struct Seeded {
        var state: UInt64
        mutating func next(_ bound: Int) -> Int {
            state =
                state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Int((state >> 33) % UInt64(bound))
        }
    }

    private struct Case {
        let mode: String
        let windows: UInt32
        let focusable: [UInt32]
        let axis: String
        let setup: (KiwiCore) -> Void
    }

    private let cases: [Case] = [
        Case(
            mode: "stack",
            windows: 4,
            focusable: [2, 3, 4],
            axis: "y",
            setup: { _ in }
        ),
        Case(
            mode: "grid",
            windows: 5,
            focusable: [4, 5],
            axis: "x",
            setup: {
                $0.execute("grid.set_type", args: [.string("rigid")])
                $0.execute(
                    "grid.set_dimensions",
                    args: [.number(3), .number(2)]
                )
                $0.execute("grid.set_auto_size", args: [.bool(false)])
            }
        ),
    ]

    private func makeSpace(
        _ spec: Case,
        width: CGFloat,
        height: CGFloat
    ) -> (KiwiCore, SpaceID) {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwi-zone-door-\(UUID().uuidString)"
                )
        )
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: width, height: height)
        }
        core.tiler.settings.gapsGlobal = Gaps.uniform(10)
        for verb in [
            "space_bar.set_visibility",
            "monocle.set_app_bar_visibility",
            "scroll.set_app_bar_visibility",
        ] {
            core.execute(verb, args: [.string("hidden")])
        }
        #expect(!core.tiler.settings.anyAppBarCanShow)
        #expect(
            core.tiler.settings.minWindowSizes == MinWindowSizes(all: 300)
        )
        core.tiler.animation.isEnabled = false
        spec.setup(core)
        for id in UInt32(1)...spec.windows {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(id),
                        pid: pid_t(900_000 + Int32(id)),
                        appName: "App\(id)"
                    )
                )
            )
        }
        let space = core.state.workspaces.space(of: WindowID(1))!
        core.execute(
            "set_mode",
            args: [.string(space.raw), .string(spec.mode)]
        )
        core.retile(animated: false)
        return (core, space)
    }

    @Test("A press never moves the window against its sense")
    func pressesKeepTheirSense() throws {
        for (offset, spec) in cases.enumerated() {
            for seed in 1...40 {
                var random = Seeded(state: UInt64(seed * 7 + offset))
                let (core, id) = makeSpace(
                    spec,
                    width: CGFloat(1200 + random.next(9) * 100),
                    height: CGFloat(900 + random.next(9) * 100)
                )
                var cues = 0
                core.borders.onResizeRefusal = { _ in cues += 1 }
                let weights = [0.3, 0.6, 1.4, 2.5, 4]
                core.state.workspaces.withSpace(id) {
                    for raw in spec.focusable where random.next(2) == 0 {
                        $0.stackWeights[WindowID(raw)] =
                            weights[random.next(weights.count)]
                    }
                }
                core.retile(animated: false)
                for step in 0..<25 {
                    let note = Comment(
                        rawValue: "\(spec.mode) seed \(seed) step \(step)"
                    )
                    let window = WindowID(
                        spec.focusable[random.next(spec.focusable.count)]
                    )
                    let shownBefore = shown(core, id)
                    guard shownBefore.contains(window) else { continue }
                    core.state.workspaces.focus(window, in: id)
                    let size =
                        random.next(2) == 0
                        ? Double(random.next(30) + 1) * 10
                        : Double(random.next(6) + 2)
                    let delta = random.next(2) == 0 ? size : -size
                    let before = length(core, window, spec.axis)
                    let cued = cues
                    core.execute(
                        "resize",
                        args: [.string(spec.axis), .number(delta)]
                    )
                    core.retile(animated: false)
                    // A push or a pull redraws the run; its sense is
                    // `RunZonePressPropertyTests`'.
                    guard shown(core, id) == shownBefore, cues == cued
                    else { continue }
                    let after = length(core, window, spec.axis)
                    if delta > 0 { #expect(after >= before - 1, note) }
                    if delta < 0 { #expect(after <= before + 1, note) }
                }
            }
        }
    }

    private func length(
        _ core: KiwiCore,
        _ window: WindowID,
        _ axis: String
    ) -> CGFloat {
        let frame = core.tiler.calculatedFrames(state: core.state)[window]
        return (axis == "x" ? frame?.width : frame?.height) ?? 0
    }

    private func shown(_ core: KiwiCore, _ id: SpaceID) -> Set<WindowID> {
        let behind = Set(
            core.tiler.runCovers[id]?.behind.keys.map { $0 } ?? []
        )
        let all = core.state.workspaces[id]?.windows ?? []
        return Set(all).subtracting(behind)
    }
}
