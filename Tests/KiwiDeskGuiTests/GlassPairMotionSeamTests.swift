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
}
