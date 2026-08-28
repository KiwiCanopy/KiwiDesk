import Foundation
import Testing

/// **Every `withAnimation` in the app's own chrome is gated on
/// Reduce Motion** (#989). A user who asked the system for less
/// motion gets it everywhere or nowhere: a single ungated call
/// animates an insertion, a reorder or a scroll in a window
/// whose every other animation correctly stood down, and
/// nothing about that is visible to a reader who does not have
/// the setting on — which is how five of them shipped at once.
///
/// The house split (`SettingsModel+Mode`) is what "gated" means
/// here: drop the MOTION, keep the affordance. So the shape
/// this scan requires is a call whose animation argument can
/// resolve to nil — `withAnimation(reduceMotion ? nil : x)`, or
/// a named animation property that makes the same choice — or a
/// call standing inside an `if reduceMotion` branch that does
/// the un-animated thing instead.
///
/// A model has no environment to read, so it takes
/// `reduceMotion` as a parameter from its caller
/// (`flipSettingsMode`, `setAutoStart`) and still satisfies the
/// scan by naming it at the call.
@Suite("Reduce Motion gating (#989)")
struct ReduceMotionGateTests {
    /// Files whose `withAnimation` may name no gate, each with
    /// the reason it is exempt. Empty by design — an entry here
    /// is a ruling that some motion must run even for a user
    /// who asked for less, which no site has needed yet.
    private static let allowed: [String: String] = [:]

    /// How far back from a call the gate may be spelled. Sized
    /// for the `if reduceMotion { … } else { withAnimation` arm,
    /// which is the longest shipped distance between the two.
    private static let window = 240

    @Test("Every withAnimation names its Reduce Motion gate")
    func everyAnimationIsGated() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
        var ungated: [String] = []
        var scanned = 0
        for file in try SourceScan.swiftSources(under: root) {
            let name = file.lastPathComponent
            let source = try SourceScan.strippedSource(at: file)
            guard source.contains("withAnimation(") else {
                continue
            }
            // PER CALL, never per file: a file may hold one
            // gated call and one ungated, and a whole-file
            // needle passes on exactly that pair.
            let text = Array(source)
            let needle = Array("withAnimation(")
            for start in text.indices
            where start + needle.count <= text.count
                && Array(text[start..<(start + needle.count)])
                    == needle
            {
                scanned += 1
                guard Self.allowed[name] == nil else { continue }
                // The gate is named AT the call (an argument
                // that can resolve to nil, or a property that
                // makes that choice) or just above it (the
                // `if reduceMotion` arm). Both put the word
                // within one small window of the call.
                var cursor = start + needle.count - 1
                let args =
                    SourceScan.balanced(
                        text,
                        from: &cursor,
                        open: "(",
                        close: ")"
                    ) ?? ""
                let before = String(
                    text[max(0, start - Self.window)..<start]
                )
                let gated =
                    args.contains("reduceMotion")
                    || args.contains("Animation")
                    || before.contains("reduceMotion")
                if !gated {
                    ungated.append(name)
                }
            }
        }
        // Fail loudly on an empty scan rather than passing for
        // having found nothing (rule-authoring.md). A FLOOR,
        // not the live count: the number of animations in the
        // app is a value every deliberate addition moves, and
        // pinning it would bill a guard-prover round per
        // animation while catching no regression (tests.md ▸
        // a drawn VALUE).
        #expect(scanned >= 5)
        #expect(ungated.isEmpty, "ungated: \(ungated)")
    }
}
