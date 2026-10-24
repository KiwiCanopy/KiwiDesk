import AppKit
import ObjectiveC

/// Liquid Glass drawn as a key window's (owner, #2569): macOS gives
/// glass in the key window its bright rim, and the bars, the overflow
/// marks, the peek and the plates never hold the keyboard. AppKit
/// asks a window's private `_hasActiveAppearance` how to draw; the
/// panels listed here answer YES without taking the keyboard
/// (measured, macOS 27: a non-key panel then draws exactly as a key
/// one). The selector is spelled here alone. Where a macOS
/// no longer asks it, the added method is never called and the glass
/// draws as it would anyway — the public fallback is doing nothing.
@MainActor
enum GlassActiveAppearance {
    /// AppKit's private question.
    static let privateSelector = "_hasActiveAppearance"

    /// The panels whose glass draws active: the shelf, the overflow
    /// mark, the peek and the plates' `ActiveGlassPanel`. Never
    /// `NSPanel` itself, which every other panel KiwiDesk opens shares.
    static var classes: [NSPanel.Type] {
        [
            ShelfPanel.self, OverflowMarkPanel.self, BarPeekWindow.self,
            ActiveGlassPanel.self,
        ]
    }

    /// Adds the YES answer to every listed class, once.
    static func install() { _ = installed }

    private static let installed: Void = {
        // A plate's panel answers its own switch, read on every ask:
        // the panels toggle off to exactly today's look (#2569).
        let block: @convention(block) (AnyObject) -> Bool = { window in
            (window as? ActiveGlassPanel)?.wearsActiveLook ?? true
        }
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
                    install()
                    let selector = NSSelectorFromString(privateSelector)
                    let base = NSWindow.instanceMethod(for: selector)
                    let missing = classes.filter {
                        $0.instanceMethod(for: selector) == base
                    }
                    guard missing.isEmpty else {
                        return .failed(
                            "no answer added on \(missing.map { "\($0)" })"
                        )
                    }
                    return .answered(
                        "NSWindow declares it; \(classes.count) panels "
                            + "answer YES"
                    )
                }
            )
        ]
    }
}

/// A plate's panel — the cue plates' and the Space-switch slide
/// plates' — whose glass wears the key-window look while
/// `wearsActiveLook` holds (#2569 ▸ the toggle). The one panel
/// class outside Core's own list that answers; never `NSPanel`.
public final class ActiveGlassPanel: NSPanel {
    /// Read by AppKit on each ask; the owner sets it from the toggle.
    public var wearsActiveLook = true

    override public init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        GlassActiveAppearance.install()
        super.init(
            contentRect: contentRect,
            styleMask: style,
            backing: backingStoreType,
            defer: flag
        )
    }
}
