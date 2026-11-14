import Foundation
import Testing

/// A glass and its tint backdrop never animate their own frames: a
/// pair that travels fills one `GlassBox` host, and only the host
/// moves (#2095, #2150). The pair's frame writers therefore take
/// no motion input — no flag, no frame-move closure — and start no
/// motion in their bodies, so a call site has no way to make
/// either travel. A writer that re-grew either input is the
/// regression: a pair gliding by its own frames trailed a crescent
/// on the device. Every pair frame write in `GlassBox`,
/// `GlassPlate` and `GlassTint` goes through the one no-motion
/// writer, since a plain write inside the host's group was stepped
/// by AppKit a frame behind the host (#2878).
@Suite("Glass pair motion seam")
struct GlassPairMotionSeamTests {
    private static var bar: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore/Bar")
    }

    /// Each frame writer of a glass or its backdrop: its file, the
    /// declaration that opens it and the parameter its frame comes
    /// from — the tint takes the glass's (#2569).
    private static let writers = [
        (
            file: "GlassPlate.swift", declaration: "static func update(",
            input: "frame: CGRect"
        ),
        (
            file: "GlassPlate.swift",
            declaration: "static func setBackdrop(",
            input: "_ view: NSView"
        ),
        (
            file: "GlassTint.swift", declaration: "static func apply(",
            input: "in glass: NSView"
        ),
        (
            file: "GlassTint.swift",
            declaration: "static func applyBehind(",
            input: "below glass: NSView"
        ),
    ]

    /// The files whose every pair frame write goes through the
    /// no-motion writer.
    private static let pairFiles = [
        "GlassBox.swift", "GlassPlate.swift", "GlassTint.swift",
    ]

    /// Motion inputs a signature may not take.
    private static let motionInputs = ["Bool", "BarFrameMove", "animated"]

    /// Spellings that start motion in a body.
    private static let motionStarts = ["animator()", "BarMotion."]

    /// The no-motion writer's calls, the one `BarMotion` a pair
    /// writer may name (#2878); the host's layout also starts the
    /// follow.
    private static let stillCalls = [
        "BarMotion.writeStill(", "BarMotion.layoutStill(",
    ]

    /// `body` with the no-motion writer's calls and `extra` taken
    /// out, so what is left starts motion only by a needle above.
    private static func unstill(
        _ body: some StringProtocol,
        _ extra: [String] = []
    ) -> String {
        (stillCalls + extra).reduce(String(body)) {
            $0.replacingOccurrences(of: $1, with: "")
        }
    }

    /// Spellings of a frame write that bypasses the writer: a
    /// frame or bounds (or a member of one) assigned, compound
    /// assignment included, or a frame or bounds setter called —
    /// `super.setFrameSize(` and the override's own declaration
    /// excepted, the host's write of itself, and a setter named as
    /// a function reference (`setFrame(_:`), the host's move route.
    /// Trade: a setter called with a first argument spelled `_:`
    /// passes unscanned, and so does a bare implicit-self
    /// `frame =`, which only a view's own member could write; no
    /// call in these files takes either shape.
    private static func rawWriteCount(in source: String) -> Int {
        let assigned = source.matches(
            of: #/\.(frame|bounds)(\.\w+)*\s*[-+*\/]?=(?!=)/#
        ).count
        let setters = source.matches(
            of: #/(super\.|func )?set(Frame|Bounds)(Size|Origin)?\((?!_:)/#
        ).filter { $0.output.1 == nil }.count
        return assigned + setters
    }

    @Test("a glass pair's frame writers take no motion input")
    func writersTakeNoMotion() throws {
        for writer in Self.writers {
            let source = try SourceScan.strippedSource(
                at: Self.bar.appendingPathComponent(writer.file)
            )
            let start = try #require(
                source.range(of: writer.declaration),
                "\(writer.declaration) is gone from \(writer.file)"
            )
            let open = try #require(
                source[start.upperBound...].firstIndex(of: "{")
            )
            let signature = source[start.lowerBound..<open]
            #expect(signature.contains(writer.input), "\(signature)")
            for input in Self.motionInputs {
                #expect(
                    !signature.contains(input),
                    "\(writer.declaration) takes \(input)"
                )
            }
            let body = try #require(
                SourceScan.declarationBody(
                    after: writer.declaration,
                    in: source
                )
            )
            #expect(!body.isEmpty)
            let rest = Self.unstill(body)
            for spelling in Self.motionStarts {
                #expect(
                    !rest.contains(spelling),
                    "\(writer.declaration) starts motion: \(spelling)"
                )
            }
        }
    }

    /// The glass's content follows every resize of the glass
    /// (#2425), a host glide's steps included: its body starts no
    /// motion either.
    @Test("the glass's content fit starts no motion")
    func contentFitStartsNoMotion() throws {
        let declaration = "static func fitContent("
        let source = try SourceScan.strippedSource(
            at: Self.bar.appendingPathComponent("GlassPlate.swift")
        )
        let body = try #require(
            SourceScan.declarationBody(after: declaration, in: source),
            "\(declaration) is gone from GlassPlate.swift"
        )
        #expect(
            body.contains("BarMotion.writeStill(held, view.bounds)"),
            "\(body)"
        )
        let rest = Self.unstill(body)
        for spelling in Self.motionStarts {
            #expect(
                !rest.contains(spelling),
                "the content fit starts motion: \(spelling)"
            )
        }
    }

    /// The host writes its pair to every size it takes (#2388): a
    /// writer whose input is the host's size, so it has no frame
    /// signature to read — its body alone starts no motion.
    @Test("the host's pair layout starts no motion of its own")
    func hostLayoutOnlyCopiesTheFollow() throws {
        let declaration = "override func setFrameSize("
        let source = try SourceScan.strippedSource(
            at: Self.bar.appendingPathComponent("GlassBox.swift")
        )
        let body = try #require(
            SourceScan.declarationBody(after: declaration, in: source),
            "\(declaration) is gone from GlassBox.swift"
        )
        #expect(
            body.contains("BarMotion.writeStill($0, bounds)"),
            "\(body)"
        )
        #expect(body.contains("BarMotion.followHostResize("), "\(body)")
        // It reads whether the host glides and copies the follow;
        // neither starts motion of its own.
        let rest = Self.unstill(
            body,
            ["BarMotion.followHostResize(", "BarMotion.carriesResize("]
        )
        for spelling in Self.motionStarts {
            #expect(
                !rest.contains(spelling),
                "the host's pair layout starts motion: \(spelling)"
            )
        }
    }

    /// A box settles to its host once the run's glide has landed
    /// (#2425): written after the motion, its body starts none.
    @Test("a box's settle starts no motion")
    func settleStartsNoMotion() throws {
        let declaration = "static func settle("
        let source = try SourceScan.strippedSource(
            at: Self.bar.appendingPathComponent("GlassBox.swift")
        )
        let body = try #require(
            SourceScan.declarationBody(after: declaration, in: source),
            "\(declaration) is gone from GlassBox.swift"
        )
        #expect(
            body.contains("BarMotion.writeStill(glass, host.bounds)"),
            "\(body)"
        )
        let rest = Self.unstill(body)
        for spelling in Self.motionStarts {
            #expect(
                !rest.contains(spelling),
                "a box's settle starts motion: \(spelling)"
            )
        }
    }

    /// Every pair frame write goes through the no-motion writer
    /// (#2878): a raw write inside a host's glide is the one AppKit
    /// steps a frame behind the host.
    @Test("glass frame writes go through the no-motion writer")
    func frameWritesAreStill() throws {
        #expect(Self.rawWriteCount(in: "a.frame = b") == 1)
        #expect(Self.rawWriteCount(in: "a.setFrameSize(s)") == 1)
        #expect(Self.rawWriteCount(in: "super.setFrameSize(s)") == 0)
        #expect(Self.rawWriteCount(in: "m = B.setFrame(_:to:)") == 0)
        #expect(Self.rawWriteCount(in: "a.frame.origin.x += 1") == 1)
        #expect(Self.rawWriteCount(in: "a.bounds = b") == 1)
        #expect(Self.rawWriteCount(in: "a.setBoundsSize(s)") == 1)
        #expect(Self.rawWriteCount(in: "a.frame == b") == 0)
        for file in Self.pairFiles {
            let source = try SourceScan.strippedSource(
                at: Self.bar.appendingPathComponent(file)
            )
            #expect(source.contains("BarMotion.writeStill("), "\(file)")
            #expect(
                Self.rawWriteCount(in: source) == 0,
                "\(file) writes a frame past BarMotion.writeStill"
            )
        }
    }
}
