import AppKit
import ObjectiveC

/// Liquid Glass drawn as a key window's (owner, 2026-10-23, #2563):
/// macOS gives glass in the key window its bright top and bottom
/// edge, and the bars, the overflow marks and the peek never hold
/// the keyboard. AppKit asks a window's private `_hasActiveAppearance`
/// how to draw; the panels listed here answer YES without taking the
/// keyboard (measured, macOS 27: a non-key panel then draws exactly
/// as a key one). The selector is spelled here alone. Where a macOS
/// no longer asks it, the added method is never called and the glass
/// draws as it would anyway — the public fallback is doing nothing.
@MainActor
enum GlassActiveAppearance {
    /// AppKit's private question.
    static let privateSelector = "_hasActiveAppearance"

    /// The panels whose glass draws active: the shelf, the overflow
    /// mark and the peek. Never `NSPanel` itself, which every other
    /// panel KiwiDesk opens shares.
    static var classes: [NSPanel.Type] {
        [ShelfPanel.self, OverflowMarkPanel.self, BarPeekWindow.self]
    }

    /// Adds the YES answer to every listed class, once.
    static func install() { _ = installed }

    private static let installed: Void = {
        let block: @convention(block) (AnyObject) -> Bool = { _ in true }
        let imp = imp_implementationWithBlock(block)
        for panel in classes {
            class_addMethod(
                panel,
                NSSelectorFromString(privateSelector),
                imp,
                "B@:"
            )
        }
    }()

    /// Whether this AppKit still declares the question on `NSWindow`.
    static var isAsked: Bool {
        NSWindow.instancesRespond(to: NSSelectorFromString(privateSelector))
    }

    /// `self_test`'s row (#1889): liveness only — whether AppKit
    /// still declares the question; no public reader says how glass
    /// draws.
    static func selfTestProbes() -> [PrivatePathProbe] {
        [
            .read(
                privateSelector,
                kind: .objcMethod,
                home: "GlassActiveAppearance",
                resolved: { isAsked },
                verify: {
                    .answered(
                        "NSWindow declares it; \(classes.count) panels "
                            + "answer YES"
                    )
                }
            )
        ]
    }
}
