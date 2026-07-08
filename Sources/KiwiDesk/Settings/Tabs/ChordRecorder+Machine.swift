import AppKit
import KiwiDeskCore

/// The chord state machine — see `ChordRecorder.swift` for
/// the semantics and the reason this lives in an extension
/// (file-size ceiling; the monitor shell stays separate).
extension ChordRecorder {
    // MARK: - The state machine (testable seam)

    /// Feeds one key event through the chord logic. Returns
    /// whether the event should be swallowed. Internal so
    /// tests can drive sequences without `NSEvent`.
    @discardableResult
    func handle(
        _ kind: EventKind,
        keyCode: UInt16,
        flags: NSEvent.ModifierFlags
    ) -> Bool {
        switch kind {
        case .keyDown:
            return keyDown(keyCode: keyCode, flags: flags)
        case .keyUp:
            // Swallow only the keyUp of a keyDown we
            // swallowed — a key held from before the
            // recording started belongs to its original
            // responder.
            let tracked =
                heldKeys.remove(keyCode) != nil
            // Back to at most one held key: the one-key
            // overlap hint no longer applies — it must leave
            // with the overlap, not wait for the next press.
            if tracked, heldKeys.count <= 1 {
                onHint(nil)
            }
            if let held = pending,
                held.keyCode == UInt32(keyCode)
            {
                // The base key left: stash the chord for the
                // burst window (the preview keeps showing it
                // until the window settles).
                stashCandidate(held)
                pending = nil
            }
            lastFlags = flags
            publishPreview(flags: flags)
            tryLockIn(flags: flags)
            return tracked
        case .flagsChanged:
            defer { lastFlags = flags }
            if var held = pending {
                let before = held
                held.mirror(flags)
                if held.lostModifier(since: before) {
                    // A modifier left mid-chord: preview
                    // downgrades, the burst stash keeps the
                    // fuller chord lockable.
                    stashCandidate(before)
                } else if before.lostModifier(since: held) {
                    // A modifier JOINED — a new chord is
                    // being built over any stashed one.
                    candidate = nil
                }
                pending = held
            } else if flags.subtracting(lastFlags)
                .intersection([
                    .command, .option, .control, .shift,
                ]) != []
            {
                candidate = nil
            }
            publishPreview(flags: flags)
            tryLockIn(flags: flags)
            return false
        }
    }

    /// Keeps the chord a release just downgraded — only the
    /// burst's FIRST downgrade: a fresh candidate is never
    /// overwritten (the fullest chord wins), an expired one
    /// is replaced by the live truth.
    private func stashCandidate(_ pending: PendingChord) {
        if let candidate,
            now().timeIntervalSince(candidate.at)
                < Self.releaseWindow
        {
            return
        }
        guard let combo = pending.combo else { return }
        let stamped = BurstCandidate(combo: combo, at: now())
        candidate = stamped
        scheduleSettle(stamped.at)
    }

    /// The lazy downgrade: if the candidate is still standing
    /// when its window closes (no lock-in, no new chord), the
    /// frozen preview finally settles to what is actually
    /// held. Internal so tests can fire it against the
    /// injected clock.
    func settleBurst(stampedAt: Date) {
        guard let candidate, candidate.at == stampedAt,
            now().timeIntervalSince(candidate.at)
                >= Self.releaseWindow
        else { return }
        self.candidate = nil
        publishPreview(flags: lastFlags)
    }

    private func scheduleSettle(_ stamp: Date) {
        Task { [weak self] in
            let margin =
                Self.releaseWindow + Self.settleSlack
            try? await Task.sleep(
                nanoseconds: UInt64(
                    margin * 1_000_000_000
                )
            )
            self?.settleBurst(stampedAt: stamp)
        }
    }

    private func keyDown(
        keyCode: UInt16,
        flags: NSEvent.ModifierFlags
    ) -> Bool {
        let bareEscape =
            keyCode == 53
            && !flags.contains(.command)
            && !flags.contains(.option)
            && !flags.contains(.control)
            && !flags.contains(.shift)
        if bareEscape {
            finish(.cancelled)
            return true
        }
        // A keyDown for a key already held is the OS
        // auto-repeat: swallow it without touching the
        // pending chord or the hint — a repeat must neither
        // re-snapshot to the overlapped key (defeating
        // first-wins) nor rebuild the chord from the current
        // flags (stripping accumulated modifiers).
        if heldKeys.contains(keyCode) {
            return true
        }
        // A second base key while the first is still held is
        // a chord attempt — a shortcut is modifiers + ONE key
        // (Carbon can't register more). Keep the first key,
        // teach instead of silently switching; the new key
        // still counts as held so the lock-in waits for its
        // release too.
        if pending != nil, !heldKeys.isEmpty,
            !heldKeys.contains(keyCode)
        {
            heldKeys.insert(keyCode)
            onHint(
                "Only one key besides modifiers — release "
                    + "it first to switch."
            )
            return true
        }
        heldKeys.insert(keyCode)
        // A fresh key discards any stashed burst chord — the
        // user is building a new one.
        candidate = nil
        // The snapshot: key + the modifiers held right now.
        pending = PendingChord(
            keyCode: UInt32(keyCode),
            command: flags.contains(.command),
            option: flags.contains(.option),
            control: flags.contains(.control),
            shift: flags.contains(.shift)
        )
        onHint(nil)
        publishPreview(flags: flags)
        return true
    }

    /// The lock-in: everything released. A fresh burst
    /// candidate locks; an expired one is discarded and the
    /// recording continues with an honest, empty preview —
    /// the user disassembled the chord slowly and can simply
    /// re-enter.
    private func tryLockIn(flags: NSEvent.ModifierFlags) {
        guard heldKeys.isEmpty,
            !flags.contains(.command),
            !flags.contains(.option),
            !flags.contains(.control),
            !flags.contains(.shift),
            let candidate
        else { return }
        self.candidate = nil
        if now().timeIntervalSince(candidate.at)
            < Self.releaseWindow
        {
            finish(.chord(candidate.combo))
        } else {
            onPreview("", nil)
        }
    }

    // MARK: - Preview

    private func publishPreview(
        flags: NSEvent.ModifierFlags
    ) {
        // While a fresh burst candidate holds the chord, the
        // display keeps it: lock-in usually completes inside
        // the window, and an instant downgrade made the combo
        // visibly vanish right before it locked.
        if let candidate,
            now().timeIntervalSince(candidate.at)
                < Self.releaseWindow
        {
            return
        }
        if let combo = pending?.combo,
            let parsed = KeyCombo.parse(combo)
        {
            onPreview(
                ComboSymbols.render(
                    parsed,
                    layoutChar: LayoutKeyGlyph.char
                ),
                combo
            )
        } else {
            onPreview(Self.modifierSymbols(flags), nil)
        }
    }
}
