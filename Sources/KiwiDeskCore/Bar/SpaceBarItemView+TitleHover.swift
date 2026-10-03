import AppKit

/// A title stays open across relayouts under a resting pointer.
extension SpaceBarItemView {
    func reportTitleHover(
        _ target: SpaceBarGlyphTarget?,
        pointerMoved: Bool = false
    ) {
        guard let space, style.showHoverTitles, horizontal, !isActive,
            let window, let point = BarHoverHit.pointer(in: self)
        else {
            clearTitleHover()
            return
        }
        let screenPoint = window.convertPoint(toScreen: point)
        let frame = window.convertToScreen(convert(bounds, to: nil))
        if let held = titleHoverAnchor {
            let survives = apps.contains { $0.windows.contains(held.window) }
            guard survives, held.frame.union(frame).contains(screenPoint)
            else {
                clearTitleHover()
                return
            }
            // Placement may change the hit target without mouse motion.
            if !pointerMoved || target?.kind != .glyph { return }
        }
        guard pointerMoved, target?.kind == .glyph,
            let member = target?.members.first
        else { return }
        guard titleHoverAnchor?.window != member else { return }
        if let owner = glyphActions?.titleHoverOwner, owner !== self {
            owner.clearTitleHover()
        }
        glyphActions?.titleHoverOwner = self
        titleHoverAnchor = (member, frame)
        glyphActions?.hover(space, member)
        guard titleHoverWatch == nil else { return }
        titleHoverWatch = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .milliseconds(50)) } catch {
                    return
                }
                guard self?.pollTitleHover() == true else { return }
            }
        }
    }

    func clearTitleHover() {
        guard titleHoverAnchor != nil else { return }
        titleHoverAnchor = nil
        titleHoverWatch?.cancel()
        titleHoverWatch = nil
        if glyphActions?.titleHoverOwner === self {
            glyphActions?.titleHoverOwner = nil
        }
        if let space { glyphActions?.hover(space, nil) }
    }

    /// A moved chip may no longer receive an exit event.
    func pollTitleHover() -> Bool {
        guard !isHiddenOrHasHiddenAncestor else {
            clearTitleHover()
            return false
        }
        reportTitleHover(nil)
        return titleHoverAnchor != nil
    }
}
