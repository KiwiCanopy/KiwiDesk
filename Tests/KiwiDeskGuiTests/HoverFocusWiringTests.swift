import Foundation
import Testing

/// Pins hover focus's boot wiring (#1869) in
/// `KiwiCore+BootSeams.swift` — `armMachineSeams()` never runs in
/// a test core, so `HoverFocusTests` and `PointerRestTests` stay
/// green with any of these lines deleted while the feature never
/// fires in production. Three needles against comment-stripped
/// source: the rest reaches `focusUnderRestingPointer`, a mouse
/// settings change switches the rest, and boot seeds the switch
/// from the settings already loaded.
///
/// Known limits: textual, so a wire nulled later still matches,
/// and the 160-char windows let an unrelated statement sit
/// between a closure's head and its call.
@Suite("Hover focus wiring (#1869)")
struct HoverFocusWiringTests {
    private func bootSeams() throws -> String {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDeskCore/App/KiwiCore+BootSeams.swift"
            )
        let source = SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        try #require(!source.isEmpty)
        return source
    }

    private func wired(_ pattern: String) throws -> Bool {
        try bootSeams().range(
            of: pattern,
            options: .regularExpression
        ) != nil
    }

    @Test("the rest reaches the consumer")
    func restIsWired() throws {
        let pattern =
            #"mouse\.rest\.onRest\s*=\s*\{[\s\S]{0,160}?"#
            + #"focusUnderRestingPointer\(at:[^)]*armedFocus:\s*armed"#
        #expect(
            try wired(pattern),
            "the pointer rest no longer reaches hover focus"
        )
    }

    /// The armed focus has a nil default: unwired, every rest
    /// stands down whenever anything holds the focus.
    @Test("the rest reads the focus when it arms")
    func noteArmIsWired() throws {
        let pattern =
            #"mouse\.rest\.noteArm\s*=\s*\{[\s\S]{0,160}?"#
            + #"focusedWindowID"#
        #expect(
            try wired(pattern),
            "the rest no longer reads the focus it arms with"
        )
    }

    @Test("a mouse settings change switches the rest")
    func settingsSwitchIsWired() throws {
        let pattern =
            #"tiler\.onMouseSettings\s*=\s*\{[\s\S]{0,160}?"#
            + #"mouse\.rest\.setEnabled\([^)]*hoverFocus\)"#
        #expect(
            try wired(pattern),
            "a hover-focus toggle no longer starts the rest"
        )
    }

    @Test("boot seeds the switch from the loaded settings")
    func bootSeedIsWired() throws {
        let pattern =
            #"mouse\.rest\.setEnabled\(\s*"#
            + #"tiler\.settings\.mouse\.hoverFocus\s*\)"#
        #expect(
            try wired(pattern),
            "boot no longer seeds hover focus's rest"
        )
    }

    /// Hover focus and `mouse.follows_focus` cannot loop only
    /// because KiwiDesk moves the pointer with a bare warp, which
    /// posts no mouse event for the rest's monitor to hear
    /// (input-and-animation.md). A synthesized mouse event —
    /// a common way to refresh hover states after a warp — re-arms
    /// the rest from our own move, so neither tree may build or
    /// post one, and the warp stays the one call.
    @Test("KiwiDesk moves the pointer without a mouse event")
    func warpPostsNoMotion() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        // Whitespace-tolerant: a 79-column call breaks its line.
        let post = try NSRegularExpression(
            pattern: #"CGEvent\s*\(\s*mouseEventSource|"#
                + #"\.post\s*\(\s*tap|\.postToPid\s*\(|"#
                + #"tapPostEvent\s*\("#
        )
        let warp = try NSRegularExpression(
            pattern: #"CGWarpMouseCursorPosition\s*\("#
        )
        var posts: [String] = []
        var warps = 0
        for tree in ["Sources/KiwiDeskCore", "Sources/KiwiDesk"] {
            let files = try SourceScan.swiftSources(
                under: root.appendingPathComponent(tree)
            )
            #expect(!files.isEmpty)
            for file in files {
                let source = try SourceScan.strippedSource(at: file)
                let range = NSRange(source.startIndex..., in: source)
                if post.numberOfMatches(in: source, range: range) > 0 {
                    posts.append(file.lastPathComponent)
                }
                warps += warp.numberOfMatches(in: source, range: range)
            }
        }
        #expect(posts.isEmpty, "a synthesized mouse event: \(posts)")
        #expect(warps == 1, "the warp is one call, found \(warps)")
    }

    /// The rest's lifetime rides the tracker's: no suite starts a
    /// real tracker, so a lost line here turns the feature off
    /// with every behaviour test green (guard-prover, #1869).
    @Test("the tracker starts and stops the rest")
    func trackerCarriesTheRest() throws {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDeskCore/Events/MouseTracker.swift"
            )
        let source = SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        #expect(
            try Self.body(of: "func start()", in: source)
                .contains("rest.start()"),
            "MouseTracker.start no longer starts the rest"
        )
        #expect(
            try Self.body(of: "func stop()", in: source)
                .contains("rest.stop()"),
            "MouseTracker.stop no longer stops the rest"
        )
    }

    /// The brace-balanced body after `head`, so a call moved out
    /// of the function is not matched in a later one.
    private static func body(
        of head: String,
        in source: String
    ) throws -> Substring {
        let start = try #require(source.range(of: head))
        let open = try #require(
            source[start.upperBound...].firstIndex(of: "{")
        )
        var depth = 0
        var index = open
        while index < source.endIndex {
            if source[index] == "{" { depth += 1 }
            if source[index] == "}" {
                depth -= 1
                if depth == 0 { return source[open...index] }
            }
            index = source.index(after: index)
        }
        Issue.record("unbalanced body after \(head)")
        return ""
    }
}
