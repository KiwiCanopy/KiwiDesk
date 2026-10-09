import Foundation

/// The Space chip's tint alphas — one table, so the relation
/// between them can be asserted (#1240).
///
/// The load-bearing decision is not any single number, it is an
/// ORDER: an automatic chip's HOVER fill stays under a pinned
/// chip's REST fill. Outline-versus-fill is the ruled kind
/// channel (`docs/design-decisions.md` ▸ Monitors), so spending
/// it on discoverability makes a hovered automatic chip read as
/// a pinned one. Left inline on the view, that relation was a
/// sentence in a doc comment; here `SpaceChipTintTests` holds
/// it, and a retune that inverts it reds.
///
/// The EDGE carries most of the hover because it is the one
/// channel both kinds share — the automatic chip has no fill to
/// lift, and it is the one most worth dragging. Retuning any of
/// these is fine; inverting an order is what must not pass.
enum SpaceChipTint {
    /// Capsule fill alpha. Zero at rest for `auto`, which is how
    /// the kind reads as an outline.
    static func fill(auto: Bool, hovering: Bool) -> Double {
        switch (auto, hovering) {
        case (true, false): return 0
        case (true, true): return 0.10
        case (false, false): return 0.15
        case (false, true): return 0.30
        }
    }

    /// Capsule edge alpha. The WIDTH never varies by kind — a
    /// sub-point stroke is a half-pixel at 1x and can vanish on
    /// an external screen, which is the display this page is
    /// about.
    static func stroke(auto: Bool, hovering: Bool) -> Double {
        switch (auto, hovering) {
        case (true, false): return 0.65
        case (true, true): return 1.0
        case (false, false): return 0.6
        case (false, true): return 0.95
        }
    }
}
