import Foundation
import Testing

/// **A hosted Core overlay view is an engine picture** (#1645,
/// gui.md ▸ This tree draws glass through one modifier). This
/// tree's own glass is untinted chrome through `glassChrome(in:)`;
/// a Core view it hosts may carry the engine's tinted glass,
/// because it IS the surface the product draws. The SwiftUI glass
/// scan cannot see inside a hosted view, so this suite is the
/// register of which ones may.
///
/// **Stated limit:** a hosted type is read off each `makeNSView`'s
/// declared return type. A representable that returns a generic
/// `NSView` built by a helper in another file hides the Core view
/// it wraps, and this scan cannot follow that helper.
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

    /// The Core types every `makeNSView` in `source` returns.
    static func hostedTypes(in source: String) -> [String] {
        let needle = "func makeNSView(context: Context) -> "
        var types: [String] = []
        var rest = source[...]
        while let hit = rest.range(of: needle) {
            types.append(
                String(
                    rest[hit.upperBound...].prefix {
                        $0.isLetter || $0.isNumber
                    }
                )
            )
            rest = rest[hit.upperBound...]
        }
        return types
    }

    /// Whether `source` declares `type` as a whole word — a class
    /// or an extension of it, never a longer name that starts with
    /// it.
    static func declares(_ type: String, in source: String) -> Bool {
        let pattern =
            "\\b(class|extension)\\s+"
            + NSRegularExpression.escapedPattern(for: type)
            + "\\b"
        return source.range(of: pattern, options: .regularExpression)
            != nil
    }

    /// Core files declaring `type`.
    private static func coreSources(
        declaring type: String
    ) throws -> [String] {
        try SourceScan.swiftSources(
            under: repo.appendingPathComponent("Sources/KiwiDeskCore")
        )
        .map { try SourceScan.strippedSource(at: $0) }
        .filter { declares(type, in: $0) }
    }

    @Test("every hosted Core view that draws glass is registered")
    func glassHostsAreRegistered() throws {
        var hosted: Set<String> = []
        for file in try SourceScan.swiftSources(
            under: Self.repo.appendingPathComponent("Sources/KiwiDesk")
        ) {
            let source = try SourceScan.strippedSource(at: file)
            guard source.contains("NSViewRepresentable") else { continue }
            for type in Self.hostedTypes(in: source) {
                let core = try Self.coreSources(declaring: type)
                guard
                    core.contains(where: { $0.contains("GlassPlate.make(") })
                else { continue }
                hosted.insert(type)
                #expect(
                    Self.glassHosts[type] != nil,
                    Comment(
                        rawValue:
                            "\(file.lastPathComponent) hosts \(type), "
                            + "which draws glass, outside the register"
                    )
                )
            }
        }
        #expect(
            Set(Self.glassHosts.keys).isSubset(of: hosted),
            "a register entry hosts nothing: \(Self.glassHosts.keys)"
        )
    }

    /// The reading itself: every representable in a file counts,
    /// and a class name matches as a whole word only.
    @Test("every makeNSView in a file is read, names as whole words")
    func readsEveryHost() {
        let two = """
            func makeNSView(context: Context) -> NSTextField { x }
            func makeNSView(context: Context) -> DragMarkerView { y }
            """
        #expect(
            Self.hostedTypes(in: two) == ["NSTextField", "DragMarkerView"]
        )
        #expect(
            Self.declares("DragMarker", in: "final class DragMarker: A {}")
        )
        #expect(
            !Self.declares("DragMarker", in: "final class DragMarkerView {}")
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
