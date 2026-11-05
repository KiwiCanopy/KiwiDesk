import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The bundled looks are built once per set of screen sizes (#2993),
/// and a change of screens still reaches Glass (#1739).
@MainActor
@Suite("Bundled looks memo")
struct BundledLooksMemoTests {
    private static let laptop = CGSize(width: 1512, height: 982)
    private static let desktop = CGSize(width: 2560, height: 1440)

    private func core(on size: CGSize) -> (KiwiCore, DisplayID) {
        let core = makeTestCore()
        let id = DisplayID(UInt32(7))
        seat(core, id, size)
        return (core, id)
    }

    private func seat(_ core: KiwiCore, _ id: DisplayID, _ size: CGSize) {
        core.state.workspaces.upsertDisplay(
            Display(
                id: id,
                name: "Main",
                frame: CGRect(origin: .zero, size: size)
            )
        )
    }

    @Test("repeated reads build once")
    func readsBuildOnce() {
        let (core, _) = core(on: Self.desktop)
        let first = core.bundledLooks
        #expect(!first.isEmpty)
        #expect(core.bundledLooks == first)
        #expect(core.bundledLooksMemo.builds == 1)
    }

    @Test("new screens build again, for those screens")
    func newScreensRebuild() {
        let (core, id) = core(on: Self.desktop)
        _ = core.bundledLooks
        seat(core, id, Self.laptop)
        #expect(
            core.bundledLooks
                == LookCatalog.bundled(sizes: core.starterSizes())
        )
        #expect(core.bundledLooksMemo.builds == 2)
        _ = core.bundledLooks
        #expect(core.bundledLooksMemo.builds == 2)
    }

    @Test("the memo answers what the build answered, per sizes")
    func memoKeysOnSizes() {
        var memo = BundledLooksMemo()
        let build: ([CGSize]) -> [ShelfLook] = { sizes in
            [ShelfLook(name: "\(sizes.count)", style: [:], colors: [:])]
        }
        let one = memo.looks(for: [Self.laptop], build: build)
        let two = memo.looks(
            for: [Self.laptop, Self.desktop],
            build: build
        )
        #expect(one.map(\.name) == ["1"])
        #expect(two.map(\.name) == ["2"])
        #expect(memo.builds == 2)
    }
}
