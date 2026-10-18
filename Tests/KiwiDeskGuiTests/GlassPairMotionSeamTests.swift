import Foundation
import Testing

/// A glass and its tint backdrop never animate their own frames: a
/// pair that travels fills one `GlassBox` host, and only the host
/// moves (#2095, #2150). The pair's two frame writers therefore
/// take no motion input — no flag, no frame-move closure — and
/// start no motion in their bodies, so a call site has no way to
/// make either travel. A writer that re-grew either input is the
/// regression: a pair gliding by its own frames trailed a crescent
/// on the device.
@Suite("Glass pair motion seam")
struct GlassPairMotionSeamTests {
    private static var bar: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore/Bar")
    }

    /// Each frame writer of a glass or its backdrop: its file and
    /// the declaration that opens it.
    private static let writers = [
        (file: "GlassPlate.swift", declaration: "static func update("),
        (file: "GlassTint.swift", declaration: "static func apply("),
        (file: "GlassTint.swift", declaration: "static func applyUniform("),
        (file: "GlassTint.swift", declaration: "private static func paint("),
    ]

    /// Motion inputs a signature may not take.
    private static let motionInputs = ["Bool", "BarFrameMove", "animated"]

    /// Spellings that start motion in a body.
    private static let motionStarts = ["animator()", "BarMotion."]

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
            #expect(signature.contains("frame: CGRect"), "\(signature)")
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
            for spelling in Self.motionStarts {
                #expect(
                    !body.contains(spelling),
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
        #expect(body.contains("content.frame = glass.bounds"), "\(body)")
        for spelling in Self.motionStarts {
            #expect(
                !body.contains(spelling),
                "the content fit starts motion: \(spelling)"
            )
        }
    }

    /// The host writes its pair to every size it takes (#2388): a
    /// writer whose input is the host's size, so it has no frame
    /// signature to read — its body alone starts no motion.
    @Test("the host's pair layout starts no motion")
    func hostLayoutStartsNoMotion() throws {
        let declaration = "override func setFrameSize("
        let source = try SourceScan.strippedSource(
            at: Self.bar.appendingPathComponent("GlassBox.swift")
        )
        let body = try #require(
            SourceScan.declarationBody(after: declaration, in: source),
            "\(declaration) is gone from GlassBox.swift"
        )
        #expect(body.contains(".frame = bounds"), "\(body)")
        for spelling in Self.motionStarts {
            #expect(
                !body.contains(spelling),
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
        #expect(body.contains("glass.frame = host.bounds"), "\(body)")
        for spelling in Self.motionStarts {
            #expect(
                !body.contains(spelling),
                "a box's settle starts motion: \(spelling)"
            )
        }
    }

    /// The Space run's glass install settles its boxes on the
    /// glide's own landing, never a timer beside it (#2425).
    @Test("the Space run settles its boxes when its glide lands")
    func spaceRunSettlesOnLanding() throws {
        let source = try SourceScan.strippedSource(
            at: Self.bar.appendingPathComponent(
                "SpaceBarOverlay+Render.swift"
            )
        )
        let install = try #require(
            source.range(of: "installGlassHosting(")
        )
        let before = source[..<install.lowerBound]
        let call = try #require(
            before.range(
                of: "BarMotion.runLayoutLanding {",
                options: .backwards
            )
        )
        let after = source[install.upperBound...]
        let landed = try #require(
            after.range(of: "} landed: {"),
            "the glass install's group takes no landing"
        )
        let tail = after[landed.upperBound...].prefix(80)
        #expect(tail.contains("settleBoxGlasses()"), "\(tail)")
        #expect(
            !source[call.upperBound..<landed.lowerBound]
                .contains("BarMotion.run"),
            "the landing belongs to another group"
        )
    }
}
