import AppKit
import KiwiDeskCore

/// `.combo` mode's modifier taps (#1872): Core's one tap rule
/// decides, so what records is what fires. A double tap commits
/// at once; a single one commits once the gap runs out with
/// nothing pressed, and is always sided. A double tap keeps its
/// side only while sides are handed in, as a chord does.
extension ChordRecorder {
    /// The modifiers `flags` holds, sides read from the device bits
    /// through Core's one reader.
    static func held(_ flags: NSEvent.ModifierFlags) -> HotkeyModifiers {
        HotkeyModifiers.held(
            by: CGEventFlags(rawValue: UInt64(flags.rawValue))
        )
    }

    /// The binding `tap` records.
    static func recorded(
        _ tap: ModifierTap,
        sides: RecorderSides?
    ) -> KeyCombo? {
        let side = tap.count == 1 || sides != nil ? tap.key.side : nil
        return KeyCombo.tap(tap.key.kind, side: side, count: tap.count)
    }

    func feedTap(_ input: ModifierTapDetector.Input) {
        guard var detector = tapDetector else { return }
        let out = detector.feed(input)
        tapDetector = detector
        if let tap = out.taps.first {
            commitTap(tap)
        } else if let pending = out.pending {
            wait(pending)
        } else if tapWait != nil {
            tapWait?.cancel()
            tapWait = nil
            onPendingTap(nil)
        }
    }

    private func wait(_ pending: ModifierTapDetector.Pending) {
        tapWait?.cancel()
        onPendingTap(
            Self.recorded(ModifierTap(pending.key, count: 1), sides: sides)
        )
        tapWait = Task { @MainActor [weak self] in
            let gap = ModifierTapDetector.gapLimit
            try? await Task.sleep(nanoseconds: UInt64(gap * 1e9))
            guard !Task.isCancelled, let self,
                var detector = self.tapDetector
            else { return }
            let tap = detector.expire(pending.token)
            self.tapDetector = detector
            self.tapWait = nil
            if let tap { self.commitTap(tap) }
        }
    }

    private func commitTap(_ tap: ModifierTap) {
        guard let combo = Self.recorded(tap, sides: sides),
            let text = combo.comboString()
        else { return }
        finish(.chord(text))
    }

    /// Drops a waiting tap with the capture.
    func endTaps() {
        tapWait?.cancel()
        tapWait = nil
        tapDetector = nil
        onPendingTap(nil)
        onPendingTap = { _ in }
    }
}
