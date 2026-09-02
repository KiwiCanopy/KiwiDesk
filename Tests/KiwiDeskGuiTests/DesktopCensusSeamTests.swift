import Foundation
import Testing

/// The per-Desktop census's seams (#1146): the private symbol is
/// spelled once, in the OS lane; a production reader reaches the
/// census through `DesktopMemory.readCensus`, the one door a
/// test pins too, never the builder; and the sweep that decides
/// removals never reads it — the on-screen census may REFUSE a
/// removal, never cause one (#1157), and the per-Desktop one is
/// downstream of that decision.
@Suite("The Desktop census stays behind its seams (#1146)")
struct DesktopCensusSeamTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
    private static let sources = root.appendingPathComponent("Sources")
    private static let core = sources.appendingPathComponent("KiwiDeskCore")
    private static let tests = root.appendingPathComponent("Tests")
    /// Spelled in two halves so this file is not its own hit.
    private static let builder = "NativeSpaces." + "desktopCensus("

    @Test("the symbol is spelled once, in the OS lane")
    func symbolSpelledOnce() throws {
        let sites = try SourceScan.identifierSites(
            of: "\"SLSCopyWindowsWithOptionsAndTags\"",
            under: Self.sources
        )
        #expect(
            sites.count == 1
                && sites.first?.file.lastPathComponent
                    == "SkyLight+WindowCensus.swift",
            .init(
                rawValue: "found "
                    + sites.map(\.site).joined(separator: ", ")
            )
        )
    }

    /// The builder is called from the seam's default alone; a
    /// consumer calling it directly would be unpinnable from a
    /// test and would read the host's WindowServer under one.
    @Test("production reads the census through the seam")
    func productionReadsThroughTheSeam() throws {
        let direct = try SourceScan.identifierSites(
            of: Self.builder,
            under: Self.sources
        )
        #expect(
            direct.map(\.file.lastPathComponent) == ["DesktopMemory.swift"],
            .init(
                rawValue: "found "
                    + direct.map(\.site).joined(separator: ", ")
            )
        )
        let readers = try SourceScan.identifierSites(
            of: "desktopMemory.readCensus(",
            under: Self.core
        )
        let files = Set(readers.map(\.file.lastPathComponent))
        #expect(
            readers.count == 3
                && files == [
                    "KiwiCore+AwayWindows.swift",
                    "KiwiCore+LaunchReach.swift",
                ],
            .init(
                rawValue: "expected the refresh, the boot seed "
                    + "and the reach, found "
                    + readers.map(\.site).joined(separator: ", ")
            )
        )
    }

    @Test("a test never calls the builder")
    func testsReachTheCensusThroughTheSeam() throws {
        let sites = try SourceScan.identifierSites(
            of: Self.builder,
            under: Self.tests
        )
        #expect(
            sites.isEmpty,
            .init(
                rawValue: "found "
                    + sites.map(\.site).joined(separator: ", ")
            )
        )
    }

    /// The one-way trust: no file of the event loop — the sweep,
    /// the heal, the carried gate, the boot passes — reads the
    /// per-Desktop census or the ledger. Every file under
    /// `Events/`, asserted non-empty so a moved directory cannot
    /// pass vacuously.
    @Test("the event loop never reads the per-Desktop census")
    func sweepStaysCensusBlind() throws {
        let events = Self.core.appendingPathComponent("Events")
        let files = try FileManager.default
            .contentsOfDirectory(atPath: events.path)
            .filter { $0.hasSuffix(".swift") }
        #expect(!files.isEmpty)
        for file in files {
            let source = try SourceScan.strippedSource(
                at: events.appendingPathComponent(file)
            )
            #expect(
                !source.contains("DesktopCensus")
                    && !source.contains("desktopCensus")
                    && !source.contains("awayWindows")
                    && !source.contains("readCensus"),
                .init(rawValue: "Events/\(file) reads the per-Desktop census")
            )
        }
    }
}
