import Foundation

/// The motion-starting spellings the bar guards look for, and
/// the walks over `BarMotion.swift` that read them (#1078).
///
/// One copy, on `tests.md`'s drift ground rather than a count:
/// `BarMotionSeamTests` asks whether a spelling occurs OUTSIDE
/// the home file and whether a function INSIDE it that uses one
/// is gated. Those are two questions over one register, and a
/// second copy that narrowed a needle would answer the first
/// while silently exempting the second — a guard passing for the
/// wrong reason, which is what the register exists to prevent.
enum BarMotionNeedles {
    /// Ways to start AppKit or Core Animation motion. Type
    /// spellings, where constructing one IS starting an
    /// animation, plus the property-style
    /// `allowsImplicitAnimation`; `NSAnimation` carries
    /// `NSAnimationContext` too, since `mentions` takes no
    /// trailing boundary.
    ///
    /// `CATransaction` is deliberately absent and
    /// `setAnimationDuration` — its one motion-starting member —
    /// stands in for it. The bare type is how motion is turned
    /// OFF (`begin` / `setDisableActions` / `commit`, which the
    /// drop ring uses), so watching it would need a permanent
    /// exemption for those files, and a permanent exemption also
    /// passes the next real starter there.
    static let starters = [
        "NSAnimation", "NSViewAnimation", "CABasicAnimation",
        "CAKeyframeAnimation", "CASpringAnimation",
        "CAAnimationGroup", "CATransition",
        "allowsImplicitAnimation", "setAnimationDuration",
    ]

    /// The call-shaped starter, which needs the walk rather than
    /// a mention: `.animator` with no paren requirement also
    /// answers for a stored `animator` of our own.
    static let animatorCall = ".animator"

    /// SwiftUI's starters, held at ZERO here rather than added
    /// to `starters`, because the two lists earn different
    /// answers and merging them would give the wrong one. The
    /// subsystem is AppKit today; `bars.md` names #1229's
    /// overview panel as the next bar surface, and if it arrives
    /// in SwiftUI its animations carry an argument, so they take
    /// `ReduceMotionGateTests`' per-call gate — NOT a route
    /// through `BarMotion`, which is what a `starters` entry
    /// would demand. So the first one to land reds here and its
    /// author widens that suite's root instead.
    static let swiftUIStarters = [
        "withAnimation", ".animation", ".transaction",
        "phaseAnimator", "keyframeAnimator", "symbolEffect",
        "contentTransition",
    ]

    /// Whether a function body reaches a motion starter.
    static func startsMotion(_ body: String) -> Bool {
        let text = Array(body)
        if Self.starters.contains(where: {
            body.contains($0) && SourceScan.mentions($0, in: text)
        }) {
            return true
        }
        return !SourceScan.callSites(
            in: text,
            for: Self.animatorCall
        ).isEmpty
    }

    /// Every `func <name>(` declared in `source`.
    static func functionNames(in source: String) -> [String] {
        var names: [String] = []
        for part in source.components(separatedBy: "func ")
            .dropFirst()
        {
            let name = part.prefix {
                $0.isLetter || $0.isNumber || $0 == "_"
            }
            guard !name.isEmpty,
                part.dropFirst(name.count).first == "("
            else { continue }
            names.append(String(name))
        }
        return names
    }

    /// The parenthesised parameter list of `name`.
    static func signature(
        of name: String,
        in source: String
    ) -> String {
        let text = Array(source)
        guard
            var cursor = SourceScan.callSites(
                in: text,
                for: "func \(name)"
            ).first?.paren
        else { return "" }
        return SourceScan.balanced(
            text,
            from: &cursor,
            open: "(",
            close: ")"
        ) ?? ""
    }
}
