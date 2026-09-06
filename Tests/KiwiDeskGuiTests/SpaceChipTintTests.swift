import Testing

@testable import KiwiDesk

/// The Space chip's tint alphas as a ranked family (#1240).
///
/// Every clause here is an ORDER derived from the shipped table,
/// never one of its numbers: retuning any alpha leaves them
/// green, and inverting a relation reds. That is the whole
/// reason the table is a value rather than two `switch`es inside
/// the view — as doc-comment prose the load-bearing relation was
/// guarded by nobody, and a retune to `0.16` would have spent
/// the kind channel with every source scan still passing (code
/// review 2026-09-06).
@Suite("Space chip tint order")
struct SpaceChipTintTests {
    /// The one that carries the ruling: outline-versus-fill is
    /// how the two kinds are told apart
    /// (`docs/design-decisions.md` ▸ Monitors), so hover may not
    /// push an automatic chip up to where a pinned chip RESTS.
    /// It would not be wrong-looking, it would be a chip of the
    /// wrong kind.
    @Test("a hovered automatic chip stays under a pinned rest")
    func hoverNeverReachesTheOtherKind() {
        #expect(
            SpaceChipTint.fill(auto: true, hovering: true)
                < SpaceChipTint.fill(auto: false, hovering: false),
            """
            the automatic chip's hover fill has reached a pinned \
            chip's rest fill — hover is spending the channel that \
            says which kind this is
            """
        )
    }

    /// An outline kind is an outline kind: zero fill at rest is
    /// what makes the distinction legible before any pointer
    /// arrives.
    @Test("the automatic chip has no rest fill")
    func automaticRestsUnfilled() {
        #expect(SpaceChipTint.fill(auto: true, hovering: false) == 0)
    }

    /// Hover LIFTS, on both channels and for both kinds. The
    /// edge matters most for the automatic chip, which has no
    /// fill worth lifting and is the one most worth dragging.
    @Test("hover raises both channels for both kinds")
    func hoverRaisesEveryChannel() {
        for auto in [true, false] {
            let kind = auto ? "automatic" : "pinned"
            #expect(
                SpaceChipTint.fill(auto: auto, hovering: true)
                    > SpaceChipTint.fill(auto: auto, hovering: false),
                Comment(
                    rawValue:
                        "the \(kind) chip's fill does not rise on "
                        + "hover"
                )
            )
            #expect(
                SpaceChipTint.stroke(auto: auto, hovering: true)
                    > SpaceChipTint.stroke(
                        auto: auto,
                        hovering: false
                    ),
                Comment(
                    rawValue:
                        "the \(kind) chip's edge does not rise on "
                        + "hover — the channel both kinds share"
                )
            )
        }
    }

    /// Every alpha is a legal alpha. A `1.1` compiles, clamps
    /// silently, and quietly retires the hover step above it.
    @Test("every alpha is within range")
    func alphasAreInRange() {
        for auto in [true, false] {
            for hovering in [true, false] {
                for alpha in [
                    SpaceChipTint.fill(auto: auto, hovering: hovering),
                    SpaceChipTint.stroke(
                        auto: auto,
                        hovering: hovering
                    ),
                ] {
                    #expect(alpha >= 0 && alpha <= 1)
                }
            }
        }
    }
}
