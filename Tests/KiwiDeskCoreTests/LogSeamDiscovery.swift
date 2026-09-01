import Foundation

@testable import KiwiDeskCore

/// Runtime discovery of `onLog` seams over the live `KiwiCore`
/// object graph, for `LogSeamProbeTests` (#625).
///
/// **Why the call goes through a protocol.** The obvious shape —
/// take `child.value` from a `Mirror` and cast it to
/// `@MainActor (String) -> Void` — compiles, and the cast even
/// succeeds. Calling the result does not work: `Mirror`'s box for
/// a **function-typed** stored property yields a value that
/// segfaults on call, or delivers a corrupted argument (a probe
/// sending `"plain probe"` observed
/// `"°㒫\u{01}\0\0\0obe"` arrive). Casting to the exact dynamic
/// type, `@Sendable` included, does not help, and it is not
/// `@MainActor`-specific. The same cast out of a plain `Any` that
/// never went through `Mirror` is correct, so the defect is the
/// reflection box, not the isolation. Measured on Swift 6.3.3 /
/// arm64.
///
/// A guard built the obvious way would therefore not merely be
/// broken — it could be **green while proving nothing**, since an
/// assertion phrased as "the sink received one line" is satisfied
/// by garbage. So `Mirror` is only ever asked for the **object**,
/// which it boxes soundly, and every call goes through
/// `LogSeamOwner.onLog`, a real typed accessor.
///
/// Precisely what the defect forces, because the over-broad
/// reading gets re-litigated: it is a property of a **bare
/// function-typed** stored property, not of reflection generally.
/// A closure wrapped in a struct round-trips through `Mirror`
/// intact and is callable, so a `LogSink` value type would be
/// discoverable **by type** with no protocol and no conformances.
/// That is a real alternative shape and it is not taken here only
/// because it would change nine public property types and every
/// test that assigns a seam — not because it cannot work. Note it
/// would fix none of the reachability holes below; the shape that
/// would dissolve this invariant rather than guard it is a
/// non-defaulted sink injected into each subsystem's initializer,
/// which makes a forgotten seam a compile error.
@MainActor
protocol LogSeamOwner: AnyObject {
    /// `get` only — the probe reads and calls, never assigns.
    ///
    /// `@MainActor` on the protocol means a **nonisolated** seam
    /// owner cannot conform. That fails shut (it lands in
    /// `unconformed`) but the remedy is then to give the walk an
    /// isolation-free path, not to add a conformance that will
    /// not compile.
    var onLog: @MainActor (String) -> Void { get }
}

extension AnimationEngine: LogSeamOwner {}
extension BorderManager: LogSeamOwner {}
extension CrashRecovery: LogSeamOwner {}
extension EventBus: LogSeamOwner {}
extension EventLoop: LogSeamOwner {}
extension ExecLauncher: LogSeamOwner {}
extension KeybindingManager: LogSeamOwner {}
extension ProfileManager: LogSeamOwner {}
extension SleepWakeManager: LogSeamOwner {}
extension SocketServer: LogSeamOwner {}
extension StrandDetector: LogSeamOwner {}
// `KiwiCore` deliberately does not conform. It is the sink these
// forward *into*, not a seam, and it is exempted by identity
// below rather than by name — see `SeamWalk.exempt`.

/// **Why this is its own file, on tests.md's two grounds.**
/// Divergence: a second copy of `SeamWalk` would let
/// `SeamWalkReachTests` pin the behaviour of a walk
/// `LogSeamProbeTests` does not run — harden one and not the
/// other and the looser copy misses the very seams the guard
/// exists to find. Omission: it clears that bar less clearly,
/// since a forgotten copy here is a compile error rather than a
/// silent re-enable. Stated both ways because tests.md asks for
/// both when weighing a shared helper.
///
/// One seam found on the live graph.
struct FoundSeam {
    /// `core.tiler.animation`, for a message that can be acted on.
    let path: String
    let owner: LogSeamOwner
}

/// A depth-first walk of the `KiwiCore` graph that collects seam
/// owners by **instance**.
///
/// Terminating by an `ObjectIdentifier` visited set rather than by
/// a depth cap: the graph holds back-references (`socket.bus`), so
/// identity is what actually stops it. `maxDepth` is a fail-shut
/// backstop only — reaching it is reported as a gap rather than
/// silently truncating the walk, because a truncated walk is a
/// guard that passes for the wrong reason.
@MainActor
struct SeamWalk {
    /// Deep enough for the shipped graph with room to spare, low
    /// enough that a cycle the visited set somehow missed is
    /// reported instead of hanging.
    static let maxDepth = 12

    private(set) var seams: [FoundSeam] = []
    /// Objects that declare an `onLog` but were not conformed to
    /// `LogSeamOwner` in this file — the one hand-written list
    /// here, kept honest by being checked rather than trusted.
    private(set) var unconformed: [String] = []
    private(set) var gaps: [String] = []

    private var visited: Set<ObjectIdentifier> = []
    /// Excluded by identity, not by type name: the sink object we
    /// started from. A second `KiwiCore` reachable from the graph
    /// would still be walked.
    private let exempt: ObjectIdentifier

    /// Private: a `SeamWalk` built and not descended is a
    /// permanently empty result, and `descend` is private.
    /// `over(_:)` is the only entry point.
    private init(root: AnyObject) {
        exempt = ObjectIdentifier(root)
    }

    static func over(_ root: AnyObject) -> SeamWalk {
        var walk = SeamWalk(root: root)
        walk.descend(root, path: "core", depth: 0)
        return walk
    }

    private mutating func descend(
        _ value: Any,
        path: String,
        depth: Int
    ) {
        guard depth <= Self.maxDepth else {
            gaps.append(
                "the walk hit its \(Self.maxDepth)-level depth "
                    + "backstop at \(path), so the graph below "
                    + "it was never searched"
            )
            return
        }
        let mirror = Mirror(reflecting: value)

        // `displayStyle` first: `as AnyObject?` bridges every
        // value type into a `__SwiftValue` box, so testing it
        // first allocates one per node only to discard it.
        if mirror.displayStyle == .class,
            let object = value as AnyObject?
        {
            let id = ObjectIdentifier(object)
            guard !visited.contains(id) else { return }
            visited.insert(id)
            record(object, mirror: mirror, path: path)
        }

        // Superclass storage, which `children` excludes: a seam
        // declared on a base class, or a seam owner held in a
        // base-class property, is otherwise invisible AND
        // ungapped — the walk's one silent miss that costs
        // nothing to close. ObjC bases reflect nothing, so this
        // adds no nodes for the AppKit subclasses in Core.
        var ancestor = mirror.superclassMirror
        while let level = ancestor {
            descendChildren(of: level, path: path, depth: depth)
            ancestor = level.superclassMirror
        }
        descendChildren(of: mirror, path: path, depth: depth)
    }

    private mutating func descendChildren(
        of mirror: Mirror,
        path: String,
        depth: Int
    ) {
        for child in mirror.children {
            // Array and Set elements are unlabelled and inherit
            // their parent's path. An Optional's payload is
            // labelled `some` and a Dictionary element's tuple
            // `key`/`value`, so those extend it.
            let childPath =
                child.label.map { "\(path).\($0)" } ?? path
            guard child.label != "onLog" else { continue }
            descend(child.value, path: childPath, depth: depth + 1)
        }
    }

    /// Classify one visited object: a seam owner to probe, a seam
    /// owner that was never conformed, or neither.
    private mutating func record(
        _ object: AnyObject,
        mirror: Mirror,
        path: String
    ) {
        // Superclass storage counts here too, or a subclass whose
        // `onLog` is inherited reads as "declares no seam" and is
        // dropped without landing in `unconformed`.
        var levels: [Mirror] = [mirror]
        while let next = levels.last?.superclassMirror {
            levels.append(next)
        }
        let declaresSeam = levels.contains { level in
            level.children.contains { $0.label == "onLog" }
        }
        guard declaresSeam, ObjectIdentifier(object) != exempt
        else { return }

        if let owner = object as? LogSeamOwner {
            seams.append(FoundSeam(path: path, owner: owner))
        } else {
            unconformed.append(
                "\(path) (\(type(of: object)))"
            )
        }
    }
}
