import Foundation
import Testing

/// **A hosted Core overlay view is an engine picture** (#1645,
/// gui.md ▸ This tree draws glass through one modifier). This
/// tree's own glass is untinted chrome through `glassChrome(in:)`;
/// a Core view it hosts may carry the engine's tinted glass,
/// because it IS the surface the product draws. The SwiftUI glass
/// scan cannot see inside a hosted view, so this suite is the
/// register of which ones may.
@Suite("Hosted engine pictures (#1645)")
struct HostedEnginePictureTests {
    /// Core views this tree may host that draw glass, each with its
    /// ruling — the one copy of who is exempt from #1295's
    /// untinted rule.
    private static let glassHosts: [String: String] = [
        "DragMarkerView": "the drag preview is the drag's marker (#1645)"
    ]

    private static var repo: URL {
        SourceScan.repoRoot(from: #filePath)
    }

    /// The Core type a representable's `makeNSView` returns.
    private static func hostedType(in source: String) -> String? {
        guard
            let hit = source.range(of: "func makeNSView(context: Context) -> ")
        else { return nil }
        return String(
            source[hit.upperBound...].prefix {
                $0.isLetter || $0.isNumber
            }
        )
    }

    /// Core files declaring `type`.
    private static func coreSources(
        declaring type: String
    ) throws -> [String] {
        try SourceScan.swiftSources(
            under: repo.appendingPathComponent("Sources/KiwiDeskCore")
        )
        .map { try SourceScan.strippedSource(at: $0) }
        .filter {
            $0.contains("class \(type)") || $0.contains("extension \(type)")
        }
    }

    @Test("every hosted Core view that draws glass is registered")
    func glassHostsAreRegistered() throws {
        var hosted: Set<String> = []
        for file in try SourceScan.swiftSources(
            under: Self.repo.appendingPathComponent("Sources/KiwiDesk")
        ) {
            let source = try SourceScan.strippedSource(at: file)
            guard source.contains("NSViewRepresentable"),
                let type = Self.hostedType(in: source)
            else { continue }
            let core = try Self.coreSources(declaring: type)
            guard core.contains(where: { $0.contains("GlassPlate.make(") })
            else { continue }
            hosted.insert(type)
            #expect(
                Self.glassHosts[type] != nil,
                Comment(
                    rawValue:
                        "\(file.lastPathComponent) hosts \(type), which "
                        + "draws glass, outside the register"
                )
            )
        }
        #expect(
            Set(Self.glassHosts.keys).isSubset(of: hosted),
            "a register entry hosts nothing: \(Self.glassHosts.keys)"
        )
    }

    /// The drag preview draws the marker through Core's view and
    /// no shape of its own over it — a SwiftUI re-drawing would be
    /// a second copy of what the engine draws (#702).
    @Test("the drag preview builds DragMarkerView and draws no marker")
    func dragPreviewHostsTheEngine() throws {
        let source = try SourceScan.strippedSource(
            at: Self.repo.appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Common/"
                    + "DragVisualPreview.swift"
            )
        )
        let make = try #require(
            SourceScan.declarationBody(after: "func makeNSView(", in: source)
        )
        #expect(String(make).contains("DragMarkerView("))
        let mock = try #require(
            SourceScan.declarationBody(after: "var mock:", in: source)
        )
        let body = String(mock)
        #expect(body.contains("DragMarkerHost("))
        for shape in [
            "Rectangle(", "RoundedRectangle(", "Capsule(", "Circle(",
            "Path(", ".stroke", ".strokeBorder", ".fill(", ".border(",
        ] {
            #expect(!body.contains(shape), "the mock draws \(shape)")
        }
    }
}
