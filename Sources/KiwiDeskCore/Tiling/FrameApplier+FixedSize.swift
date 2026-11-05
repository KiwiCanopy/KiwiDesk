import CoreGraphics
import Foundation

/// A run of size-led writes: where the window really is, and whether a
/// hotkey fire asked for it.
public struct SizeLedRun: Equatable, Sendable {
    let anchor: CGRect
    let pressed: Bool
}

/// One size-led write's report that macOS says its window's size
/// cannot be set (#2994). `serial` orders it among the writes, and
/// `pressed` says a hotkey fire started the run it belongs to.
struct FixedSizeReport: Sendable {
    let window: WindowID
    let asked: CGSize
    let anchor: CGRect
    let serial: Int
    let pressed: Bool
}

/// Where reports leave the applier. Holds write order and one report's
/// press, never a finding about a window (`docs/design-decisions.md`).
@MainActor
final class FixedSizeDoor {
    var serial = 0
    /// Writes up to here were issued before the last cue, so their
    /// reports draw nothing.
    var cuedThrough = 0
    /// True while a pressed write's report draws its cue, which lands
    /// outside the fire the refusal sound gates on.
    var reportingPress = false
    var onReport: @MainActor (FixedSizeReport) -> Void = { _ in }
}

extension FrameApplier {
    func clearInstantTarget(_ id: WindowID, unlessSized size: CGSize) {
        if let sent = instantTarget(id), sent.size != size {
            clearInstantTarget(id)
        }
    }

    func sizeLead(_ id: WindowID, run: SizeLedRun) -> SizeLedWrite.Lead {
        let door = fixedSizeDoor
        door.serial += 1
        let serial = door.serial
        let anchor = run.anchor
        let pressed = run.pressed
        return SizeLedWrite.Lead(
            anchor: anchor,
            screens: screenFrames(),
            fixed: { [weak door] asked in
                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        door?.onReport(
                            FixedSizeReport(
                                window: id,
                                asked: asked,
                                anchor: anchor,
                                serial: serial,
                                pressed: pressed
                            )
                        )
                    }
                }
            }
        )
    }
}

extension TilingEngine {
    /// Ends a run macOS says cannot size its window. A resend or a
    /// stamp at the anchor's size is a newer move's to keep.
    func endSizeLedRun(of id: WindowID, anchor: CGRect) {
        if applier.sizeLedRuns[id]?.anchor == anchor {
            animation.cancel(window: id)
        }
        applier.forgetResend(id, unlessSized: anchor.size)
        applier.clearInstantTarget(id, unlessSized: anchor.size)
    }
}
