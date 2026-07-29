import Foundation
import Testing

@testable import KiwiDeskCore

/// Which property shapes `SeamWalk` reaches, and which it
/// provably cannot (#625).
///
/// `LogSeamProbeTests` asserts the walk reaches the eight seam
/// owners a real `KiwiCore` holds. That tells you nothing about
/// *why* it reaches them, so a refactor that moves one behind a
/// shape the walk cannot see reds there with no clue what
/// changed. This pins the shapes themselves, over synthetic
/// owners rather than the live graph.
///
/// It is the map for `SeamRegister`'s argument. Each miss below
/// is a way a live seam owner leaves the graph with no gap and no
/// `unconformed` entry — measured, not reasoned about — and the
/// register is the only thing standing under them.
@Suite("Seam walk reach")
@MainActor
struct SeamWalkReachTests {
    // MARK: - Synthetic owners

    private final class Owner: LogSeamOwner {
        var onLog: @MainActor (String) -> Void = { _ in }
    }

    private class SeamBase: LogSeamOwner {
        var onLog: @MainActor (String) -> Void = { _ in }
    }
    /// Declares no seam of its own — its `onLog` is inherited,
    /// which `Mirror.children` does not report.
    private final class SeamDerived: SeamBase {
        var unrelated = 0
    }

    private struct Box { var held = Owner() }

    /// Holds a seam owner in a property declared on the **base**.
    /// Distinct from `SeamDerived`, where the seam itself is
    /// inherited: here the seam is ordinary and the *edge to it*
    /// is what `Mirror.children` omits.
    private class HolderBase { let fromBase = Owner() }
    private final class HolderDerived: HolderBase {
        let fromDerived = Owner()
    }

    private final class Reachable {
        let plain = Owner()
        let optional: Owner? = Owner()
        let array = [Owner()]
        let dictionary = ["k": Owner()]
        let box = Box()
        let inherited = SeamDerived()
        let viaBaseProperty = HolderDerived()
        weak var weakly: Owner?
        private let weakKeeper: Owner

        init() {
            let held = Owner()
            weakKeeper = held
            weakly = held
        }
    }

    private final class BehindComputed {
        private static let shared = Owner()
        var owner: Owner { BehindComputed.shared }
    }

    private final class BehindLazy {
        lazy var owner = Owner()
    }

    private func reached(_ root: AnyObject) -> Set<String> {
        Set(SeamWalk.over(root).seams.map(\.path))
    }

    // MARK: - What it reaches

    @Test("Every stored shape a seam owner can sit in is reached")
    func storedShapesAreReached() {
        let paths = reached(Reachable())

        // Named individually rather than by count: a count says
        // "six of something" and a regression that swapped one
        // miss for one hit would keep it.
        #expect(paths.contains("core.plain"))
        #expect(paths.contains("core.optional.some"))
        #expect(paths.contains("core.array"))
        #expect(paths.contains("core.dictionary.value"))
        #expect(paths.contains("core.box.held"))
        // The `superclassMirror` traversal. Without it this owner
        // declares no seam as far as `Mirror.children` is
        // concerned, and is dropped without landing in
        // `unconformed` — silent, which is the whole objection.
        #expect(paths.contains("core.inherited"))
        // The other half of that traversal, and a genuinely
        // separate one: here the seam is ordinary but the
        // property *holding* it is declared on a base class, so
        // the walk has to descend superclass storage as well as
        // consult it. Reverting either half alone leaves the
        // other's assertion green.
        #expect(paths.contains("core.viaBaseProperty.fromDerived"))
        #expect(paths.contains("core.viaBaseProperty.fromBase"))
        // A weak reference is a real edge; identity dedup means
        // the same object behind two of them is probed once.
        #expect(paths.contains("core.weakly.some"))
    }

    @Test("A base-class seam is not double-counted")
    func inheritedSeamIsProbedOnce() {
        // Held by a root rather than being one: `SeamWalk` exempts
        // the object it starts from, because in production that is
        // `KiwiCore`, the sink.
        final class Root { let child = SeamDerived() }

        let walk = SeamWalk.over(Root())
        // Walking the levels must not enter the same object
        // twice, or every inherited seam would be probed once per
        // level and the routing assertion would see duplicates.
        #expect(walk.seams.count == 1)
        #expect(walk.unconformed.isEmpty)
        #expect(walk.gaps.isEmpty)
    }

    // MARK: - What it provably cannot reach

    @Test("A computed accessor hides its owner, with no gap")
    func computedAccessorIsInvisible() {
        // A root that is not itself a seam owner, so nothing here
        // is hidden by the sink exemption.
        let walk = SeamWalk.over(BehindComputed())
        #expect(walk.seams.isEmpty)
        // The point of the test: it is not merely missed, it is
        // missed *quietly*. Nothing here would tell an author the
        // walk stopped covering a seam, which is why
        // `SeamRegister` is an equality and not a floor.
        #expect(walk.gaps.isEmpty)
        #expect(walk.unconformed.isEmpty)
    }

    @Test("An unforced lazy var hides its owner, with no gap")
    func unforcedLazyIsInvisible() {
        let walk = SeamWalk.over(BehindLazy())
        #expect(walk.seams.isEmpty)
        #expect(walk.gaps.isEmpty)
        #expect(walk.unconformed.isEmpty)

        // Forcing it puts the owner back in the graph, which is
        // what makes this a reachability property rather than a
        // property of the type.
        let forced = BehindLazy()
        _ = forced.owner
        #expect(!SeamWalk.over(forced).seams.isEmpty)
    }

    // MARK: - What fails shut

    @Test("An unconformed seam owner is named, not skipped")
    func unconformedOwnerIsNamed() {
        final class Unconformed {
            var onLog: @MainActor (String) -> Void = { _ in }
        }
        final class Root { let child = Unconformed() }

        let walk = SeamWalk.over(Root())
        #expect(walk.seams.isEmpty)
        #expect(walk.unconformed.count == 1)
        #expect(
            walk.unconformed.first?.contains("Unconformed") == true,
            "\(walk.unconformed)"
        )
    }
}
