import AppKit

/// Inline strips move by their measured cells, including title widths.
extension SpaceBarItemView {
    func prepareTitleTransition(to apps: [App], keepsSpace: Bool) {
        if !keepsSpace {
            pendingTitleReveal = false
            pendingInlineWalk = false
            titleTransitionFrames = [:]
            drawnTitleWindows = []
        }
        let hasTitles = (self.apps + apps).contains {
            $0.inlineTitle != nil
        }
        guard hasTitles else { return }
        let walks = keepsSpace && pendingWalk != nil
        let changed = self.apps.map(\.inlineTitle) != apps.map(\.inlineTitle)
        guard changed || walks else { return }
        if !pendingTitleReveal && keepsSpace {
            titleTransitionFrames = Dictionary(
                uniqueKeysWithValues: zip(self.apps, appViews).compactMap {
                    app,
                    view in
                    app.windows.first.map { ($0, view.frame) }
                }
            )
            drawnTitleWindows = Set(
                self.apps.filter { $0.inlineTitle != nil }
                    .compactMap { $0.windows.first }
            )
        }
        pendingTitleReveal = true
        pendingInlineWalk = pendingInlineWalk || walks
    }

    func playTitleReveal() {
        guard pendingTitleReveal else { return }
        pendingTitleReveal = false
        let walks = pendingInlineWalk
        pendingInlineWalk = false
        if walks { pendingWalk = nil }
        var steps: [BarMotion.WalkStep] = []
        let stripShift =
            zip(apps, appViews).compactMap { app, view in
                app.windows.first.flatMap { titleTransitionFrames[$0] }.map {
                    CGVector(
                        dx: $0.minX - view.frame.minX,
                        dy: $0.minY - view.frame.minY
                    )
                }
            }.first ?? .zero
        for (index, app) in apps.enumerated() {
            guard let window = app.windows.first else { continue }
            let glyph = appViews[index]
            let old = titleTransitionFrames[window]
            let shift =
                old.map {
                    CGVector(
                        dx: $0.minX - glyph.frame.minX,
                        dy: $0.minY - glyph.frame.minY
                    )
                } ?? (walks ? stripShift : .zero)
            let parts: [NSView] = [
                glyph, badgeViews[index], stickyBadgeViews[index],
                floatingBadgeViews[index],
            ]
            if old != nil || walks {
                steps += parts.filter { !$0.isHidden }.map {
                    .init(
                        view: $0,
                        slide: shift,
                        fade: walks && old == nil ? -$0.alphaValue : 0
                    )
                }
            }
            let title = titleViews[index]
            if !title.isHidden {
                steps.append(
                    .init(
                        view: title,
                        slide: shift,
                        fade: drawnTitleWindows.contains(window) ? 0 : -1
                    )
                )
            }
        }
        titleTransitionFrames = [:]
        drawnTitleWindows = []
        let leaving = walks ? leavingViews : []
        for view in leaving {
            let alpha = view.alphaValue
            view.frame = view.frame.offsetBy(
                dx: -stripShift.dx,
                dy: -stripShift.dy
            )
            view.alphaValue = 0
            steps.append(.init(view: view, slide: stripShift, fade: alpha))
        }
        BarMotion.playWalk(steps) { [weak self] in
            leaving.forEach { $0.removeFromSuperview() }
            self?.leavingViews.removeAll { view in
                leaving.contains { $0 === view }
            }
        }
    }
}
