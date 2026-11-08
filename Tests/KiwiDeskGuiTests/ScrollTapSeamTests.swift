import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The one scroll-wheel event tap stays one, scroll-only, off the
/// main actor and out of the test run (#1656, #1519).
///
/// What each clause keeps, because a behavioural suite over the
/// `FakeTap` sees none of it:
/// - ONE `tapCreate(` per tap file, the scroll tap's and #2601's
///   keyboard tap's: a third tap, or a mask widened past its
///   constant, asks macOS for more than these do (measured
///   2026-09-28 and 2026-10-25).
/// - the install runs inside `start`'s own `Thread`: every scroll
///   on the Mac waits on the callback, and a tap on the main run
///   loop stalls them behind a slow app's AX reply.
/// - ONE live factory, in `ScrollGestures`, pinned inert in both
///   `makeTestCore` twins — the #565 class: a suite that binds a
///   gesture would otherwise take a session-wide tap.
///
/// Residue: the thread clause pins where `install()` is CALLED —
/// inside the closure `start` hands its `Thread` — not what thread
/// `CFRunLoopRun` then serves; and the pin clause reads the twins'
/// text, not that `makeTestCore` reaches the line.
@Suite("The event taps stay two, narrow and off-main")
struct ScrollTapSeamTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
    private static let productionTrees = [
        root.appendingPathComponent("Sources/KiwiDeskCore"),
        root.appendingPathComponent("Sources/KiwiDesk"),
    ]
    private static let tapFile = root.appendingPathComponent(
        "Sources/KiwiDeskCore/Events/ScrollGestureTap.swift"
    )

    private static func sites(
        of needle: String
    ) throws -> [MachineTouchSite] {
        try productionTrees.flatMap {
            try SourceScan.identifierSites(of: needle, under: $0)
        }
    }

    @Test("two event taps in the app, one per tap file")
    func oneTapPerFile() throws {
        // `tapCreate` without its `(` also catches `tapCreateForPid(`
        // and `tapCreateForPSN(`; `EventTapCreate` the C spelling.
        // The keyboard tap is #2601's, which every key reader joins
        // as a consumer (#1872).
        let sites =
            try Self.sites(of: "tapCreate")
            + Self.sites(of: "EventTapCreate")
        #expect(
            sites.map(\.file.lastPathComponent).sorted()
                == ["KeyboardTap.swift", "ScrollGestureTap.swift"],
            .init(rawValue: sites.map(\.site).joined(separator: ", "))
        )
    }

    @Test("the tap is created with the one mask constant")
    func maskIsTheConstant() throws {
        // The constant's VALUE is `ScrollSampleTests`' to pin.
        let source = try SourceScan.strippedSource(at: Self.tapFile)
        #expect(source.contains("eventsOfInterest: Self.mask"))
        #expect(source.components(separatedBy: "eventsOfInterest:").count == 2)
    }

    @Test("each tap installs inside its own thread's closure")
    func installsOffMain() throws {
        let taps = [
            ("ScrollGestureTap.swift", "Events", Self.tapFile),
            (
                "KeyboardTap.swift", "Keys",
                Self.root.appendingPathComponent(
                    "Sources/KiwiDeskCore/Keys/KeyboardTap.swift"
                )
            ),
        ]
        for (name, directory, url) in taps {
            let body = try SourceScan.functionBody(
                of: "start",
                in: name,
                under: directory
            )
            let closure = try #require(
                Self.closure(after: "Thread {", in: body)
            )
            #expect(closure.contains("install()"), "\(name)")
            let source = try SourceScan.strippedSource(at: url)
            // One call beside the declaration: a second call site
            // could install on whatever thread it runs on.
            #expect(
                source.components(separatedBy: "install()").count == 3,
                "\(name)"
            )
        }
    }

    /// The brace-balanced body that opens at `marker`'s `{`.
    private static func closure(
        after marker: String,
        in text: String
    ) -> String? {
        guard let start = text.range(of: marker) else { return nil }
        var depth = 0
        var index = text.index(before: start.upperBound)
        while index < text.endIndex {
            switch text[index] {
            case "{": depth += 1
            case "}":
                depth -= 1
                if depth == 0 {
                    return String(text[start.upperBound..<index])
                }
            default: break
            }
            index = text.index(after: index)
        }
        return nil
    }

    @Test("one live factory per tap, pinned inert in both twins")
    func liveFactoryPinned() throws {
        let factories: [(String, String, String)] = [
            (
                "ScrollGestureTap.live(", "ScrollGestures.swift",
                "mouse.scroll.makeTap = { _ in nil }"
            ),
            (
                "KeyboardTap.live(", "KeybindingManager.swift",
                "keys.makeKeyboardTap = { _, _, _ in nil }"
            ),
        ]
        for (factory, home, pin) in factories {
            let live = try Self.sites(of: factory)
            #expect(live.count == 1, "\(factory)")
            #expect(live.first?.file.lastPathComponent == home)
            for target in ["KiwiDeskCoreTests", "KiwiDeskGuiTests"] {
                let twin = Self.root.appendingPathComponent(
                    "Tests/\(target)/TestCore.swift"
                )
                let source = try SourceScan.strippedSource(at: twin)
                #expect(
                    source.contains(pin),
                    .init(rawValue: "\(target) misses \(pin)")
                )
            }
        }
    }

    @Test("the keyboard tap is built from its consumers' masks")
    func consumerMasks() throws {
        let file = Self.root.appendingPathComponent(
            "Sources/KiwiDeskCore/Keys/KeyboardTap.swift"
        )
        let source = try SourceScan.strippedSource(at: file)
        // One creation, from the live consumers' union; no mask
        // spelled beside the consumer's own constants.
        #expect(
            source.contains(
                "eventsOfInterest: KeyboardTapConsumer.union(consumers)"
            )
        )
        #expect(source.components(separatedBy: "eventsOfInterest:").count == 2)
        #expect(source.components(separatedBy: "CGEventMask(1)").count == 2)
        // The values: `.sides` key-down alone, `.modifierTaps` the
        // flag changes, key-down and mouse-down #1229 rules, and the
        // union of none is no mask.
        let bit = { (type: CGEventType) in CGEventMask(1) << type.rawValue }
        #expect(KeyboardTapConsumer.sides.mask == bit(.keyDown))
        #expect(
            KeyboardTapConsumer.modifierTaps.mask
                == bit(.flagsChanged) | bit(.keyDown) | bit(.leftMouseDown)
                | bit(.rightMouseDown) | bit(.otherMouseDown)
        )
        #expect(KeyboardTapConsumer.union([]) == 0)
        #expect(
            KeyboardTapConsumer.union([.sides, .modifierTaps])
                == KeyboardTapConsumer.modifierTaps.mask
        )
        // Only `.sides` swallows, so a taps-only tap listens.
        #expect(KeyboardTapConsumer.allCases.filter(\.swallows) == [.sides])
        #expect(source.contains("swallows ? .defaultTap : .listenOnly"))
    }
}
