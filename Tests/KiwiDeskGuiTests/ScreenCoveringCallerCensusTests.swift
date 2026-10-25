import Foundation
import Testing

/// Every raw read of the screen-covering verdict in Core is
/// classified, or it reds (#1788). A reader asking whether a
/// TRACKED window is presenting takes `KiwiCore.presents`, which
/// rules the float gate once; the raw `covers` / `coversAScreen`
/// is for a CANDIDATE frame whose float ruling the caller already
/// made (the fit, the gather, through `coversAsShow`) and for
/// the verdict's own home. A new raw caller is the drift #1788
/// closes, so it reds here until it routes through the door or
/// names its reason.
///
/// Pinned by COUNT per file over comment-stripped source, each
/// name matched whole — a call or a bare function reference
/// alike, never inside a longer identifier. The trade: a raw read
/// swapped for another raw read in a file already listed stays
/// green, which the consumer suites own.
@Suite("Screen-covering caller census")
struct ScreenCoveringCallerCensusTests {
    /// Files spelling the raw verdict, with their reason.
    private let allowed: [String: Int] = [
        // The home: both definitions, `coversAScreen`'s own
        // `covers`, the front-window reads, the door and
        // the crossing's before/after.
        // `coversAsShow`'s `coversAScreen`.
        "App/KiwiCore+ScreenCovering.swift": 8
    ]

    /// `covers` or `coversAScreen` as a whole identifier.
    private static func verdictHits(in source: String) -> Int {
        let pattern = try! NSRegularExpression(
            pattern: #"\bcovers(AScreen)?\b"#
        )
        return pattern.numberOfMatches(
            in: source,
            range: NSRange(source.startIndex..., in: source)
        )
    }

    @Test("every raw screen-covering read in Core is classified")
    func everyCallerIsClassified() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
        let prefix = root.path + "/"
        var counts: [String: Int] = [:]
        for file in try SourceScan.swiftSources(under: root) {
            let key = String(file.path.dropFirst(prefix.count))
            let source = try SourceScan.strippedSource(at: file)
            let hits = Self.verdictHits(in: source)
            guard hits > 0 else { continue }
            counts[key] = hits
        }
        #expect(counts["App/KiwiCore+ScreenCovering.swift"] != nil)
        for (file, count) in counts.sorted(by: { $0.key < $1.key }) {
            let unlisted =
                "\(file) reads the screen-covering verdict "
                + "\(count)× — ask KiwiCore.presents for a tracked "
                + "window, or classify and pin it here (#1788)"
            #expect(
                allowed[file] == count,
                Comment(rawValue: unlisted)
            )
        }
        for (file, pinned) in allowed {
            #expect(
                counts[file] == pinned,
                "\(file) no longer reads the verdict \(pinned)×"
            )
        }
    }

    /// The show verdict's two halves have one composition
    /// (#1788 item 5): `mayPresent` is spelled in the home alone,
    /// and a candidate-frame caller takes `coversAsShow`, so no
    /// caller can keep the frame and drop the subrole.
    private let showAllowed: [String: Int] = [
        // Both definitions, `coversAsShow`'s `mayPresent`, the
        // door's `coversAsShow` and the stand-down's `mayPresent`.
        "App/KiwiCore+ScreenCovering.swift": 5,
        // The float fit judges the frame it would write, on the
        // workspace its caller names (#1787).
        "App/KiwiCore+FloatClamp.swift": 1,
        // The gather judges the frame a member would show, on the
        // entry the mode write makes (#1787).
        "App/KiwiCore+FloatGather.swift": 1,
    ]

    @Test("the show verdict is composed in one home")
    func showVerdictHasOneComposition() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
        let prefix = root.path + "/"
        let pattern = try NSRegularExpression(
            pattern: #"\b(mayPresent|coversAsShow)\b"#
        )
        var counts: [String: Int] = [:]
        for file in try SourceScan.swiftSources(under: root) {
            let source = try SourceScan.strippedSource(at: file)
            let hits = pattern.numberOfMatches(
                in: source,
                range: NSRange(source.startIndex..., in: source)
            )
            guard hits > 0 else { continue }
            counts[String(file.path.dropFirst(prefix.count))] = hits
        }
        #expect(counts == showAllowed)
    }

    /// The raw front-to-back read (#1788 item 4): the seam, its
    /// live default and the CGWindowList read beneath it are each
    /// spelled in their one home, and a reader is ruled here — the
    /// presentation verdict, and hover focus's hit test (#1869). A
    /// new z-order need reads THIS seam's element, never a second
    /// front-to-back read beside it.
    private let frontSeamAllowed: [String: Int] = [
        // The seam's declaration and its live default.
        "App/KiwiCore.swift": 2,
        // The stand-down's one read, the default's definition and
        // the CGWindowList call it wraps, and KiwiVision's
        // chrome-free view's definition and its own raw read, the
        // desktop's elements kept.
        "App/KiwiCore+ScreenCovering.swift": 5,
        // The CGWindowList read's own definition.
        "AX/FloatDetection.swift": 1,
        // KiwiVision's mask (#2103 ruling 21): its one list seam's
        // live default, read at a settle or with nothing cached.
        "Vision/VisionManager.swift": 1,
        // Hover focus's hit test at the resting pointer (#1869).
        "App/KiwiCore+HoverFocus.swift": 1,
        // The display follow's Dock hit test at a press: an
        // auto-hidden Dock reserves no visible frame.
        "Commands/KiwiCore+DisplayFocus.swift": 1,
        // `list_windows`' stacking rank, on demand only (#2546).
        "Commands/KiwiCore+WindowList.swift": 1,
    ]

    @Test("every front-window seam reader is ruled")
    func frontWindowSeamReadersAreRuled() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
        let prefix = root.path + "/"
        let pattern = try NSRegularExpression(
            pattern: #"\b(frontStack|liveFrontStack|"#
                + #"liveFrontWindows|frontToBackWindows)\b"#
        )
        var counts: [String: Int] = [:]
        for file in try SourceScan.swiftSources(under: root) {
            let source = try SourceScan.strippedSource(at: file)
            let hits = pattern.numberOfMatches(
                in: source,
                range: NSRange(source.startIndex..., in: source)
            )
            guard hits > 0 else { continue }
            counts[String(file.path.dropFirst(prefix.count))] = hits
        }
        #expect(
            counts == frontSeamAllowed,
            "a front-window seam reader is ruled in frontSeamAllowed"
        )
    }

    /// KiwiVision's read keeps the desktop's elements: macOS counts
    /// SketchyBar's layer −20 bar among them, and Never dimmed must
    /// see it (#2103). Hover and the presentation verdict read the
    /// other way, through `liveFrontStack`.
    @Test("KiwiVision's read keeps the desktop's elements")
    func visionReadKeepsDesktop() throws {
        let source = try SourceScan.strippedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(
                    "Sources/KiwiDeskCore/App/KiwiCore+ScreenCovering.swift"
                )
        ).filter { !$0.isWhitespace }
        #expect(
            source.contains(
                "staticfuncliveFrontWindows()->[FrontWindow]{"
                    + "withoutOwnChrome(FloatDetection.frontToBackWindows("
                    + "includingDesktopElements:true"
            )
        )
        #expect(
            source.contains(
                "staticfuncliveFrontStack()->[FrontWindow]{"
                    + "FloatDetection.frontToBackWindows{"
            )
        )
    }

    /// The raw spellings beneath the seam stay in their homes, so a
    /// reader cannot swap the seam for the live read and keep its
    /// file's count — which would read the host's real windows
    /// past every test pin.
    @Test("the seam's live default is read only behind it")
    func rawFrontReadsStayHome() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
        let prefix = root.path + "/"
        let raw = try NSRegularExpression(
            pattern: #"\b(liveFrontStack|frontToBackWindows)\b"#
        )
        var homes: [String: Int] = [:]
        for file in try SourceScan.swiftSources(under: root) {
            let source = try SourceScan.strippedSource(at: file)
            let hits = raw.numberOfMatches(
                in: source,
                range: NSRange(source.startIndex..., in: source)
            )
            guard hits > 0 else { continue }
            homes[String(file.path.dropFirst(prefix.count))] = hits
        }
        #expect(
            homes == [
                // The seam's default.
                "App/KiwiCore.swift": 1,
                // The default's definition, the read it wraps, and
                // KiwiVision's own raw read, the desktop's elements
                // kept.
                "App/KiwiCore+ScreenCovering.swift": 3,
                // The read's own definition.
                "AX/FloatDetection.swift": 1,
            ],
            "\(homes)"
        )
    }
}
