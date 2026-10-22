import AppKit
import QuartzCore

/// `BarMotion`'s reveal half (#761, #2497): a revealed shelf slides
/// in from its screen side whole, its content already laid out, or
/// — the user's `reveal_style` — grows its plate out of the mark
/// (`ShelfGrow`) or stretches it out as an unfold (`ShelfUnfold`).
/// Each plays under Reduce Motion too (owner ruling, 2026-10-21).
/// The same one home — `BarMotionSeamTests` censuses this file.
extension BarMotion {
    /// How a reveal or a retract plays.
    enum RevealMotion: Equatable {
        /// The content travels from `offset` (its own coordinates)
        /// to its rest, or back, over `length`.
        case slide(offset: CGVector, length: TimeInterval)
        /// The plate grows out of the mark (`ShelfGrow`).
        case morph(ShelfGrow.Morph)
        /// The plate stretches out of the mark, then deepens.
        case unfold(ShelfUnfold.Stretch)
        /// Each box springs out of the mark to its slot.
        case spread(ShelfUnfold.Spread)
        /// It cross-fades in place: the Fade style, nothing to
        /// travel, or no plate to grow to.
        case fade(TimeInterval)

        /// Its own length, before it is fitted to the user's.
        var length: TimeInterval {
            switch self {
            case .slide(_, let length), .fade(let length): length
            case .morph(let morph): morph.length
            case .unfold(let stretch): stretch.length
            case .spread(let spread): spread.length
            }
        }
    }

    /// A reveal's inputs, whichever kind plays it: the slide's
    /// `offset`, the grow's and the unfold's mark `origin` and
    /// `plate` — under Boxed the span of the boxes — all in the
    /// content's coordinates, and the shelf's edge.
    struct RevealPath: Equatable {
        var kind: RevealKind
        var offset: CGVector = .zero
        var origin: CGRect = .zero
        var plate: CGRect?
        var plateRadius: CGFloat = 0
        var edge: AppBarEdge = .top
        var horizontal: Bool { edge.isHorizontal }
        /// The user's `animations.reveal_duration`, in seconds, every
        /// style plays inside.
        var length = AnimationSettings().revealSeconds
    }

    /// The user's `animations.reveal_duration` in seconds, kept
    /// current by `KiwiCore.updateBars()`.
    @MainActor static var revealLength = AnimationSettings().revealSeconds

    /// The slide's length and curve (owner ruling, #2497): the
    /// prototype's numbers, fixed like the mark's own timings.
    static let revealSlide: TimeInterval = 0.28
    static let revealCurve: (Float, Float, Float, Float) = (0.3, 0.7, 0.2, 1)
    /// The cross-fade's length: the Fade style's, and where nothing
    /// travels (owner ruling, 2026-10-21).
    static let revealFade: TimeInterval = 0.15
    /// How long the mark fades back at the end of a retract,
    /// landing with it.
    static let markReturn: TimeInterval = 0.06
    /// How long a reveal stands at its start after the commit that
    /// orders the panel in: a freshly ordered window reaches the
    /// screen a frame or two after that commit, and a clock
    /// started there loses the travel those frames carry.
    static let revealLead: TimeInterval = 1.0 / 30

    /// Where a shelf on `edge` starts its slide, in its flipped
    /// content coordinates: past its screen side by its `depth`
    /// and the `gap` to the usable area's edge, so it starts
    /// wholly clipped and comes out from under the menu bar.
    static func revealOffset(
        edge: AppBarEdge,
        depth: CGFloat,
        gap: CGFloat
    ) -> CGVector {
        let travel = depth + max(gap, 0)
        switch edge {
        case .top: return CGVector(dx: 0, dy: -travel)
        case .bottom: return CGVector(dx: 0, dy: travel)
        case .left: return CGVector(dx: -travel, dy: 0)
        case .right: return CGVector(dx: travel, dy: 0)
        }
    }

    /// The motion for a reveal (`entering`) or a retract along
    /// `path`. Reduce Motion keeps it: the owner ruled the reveal
    /// a motion that plays regardless, as the Dock's auto-hide
    /// slides (2026-10-21).
    static func revealMotion(
        entering: Bool,
        path: RevealPath
    ) -> RevealMotion {
        // Out of the mark as its hover leaves it.
        let mark = hoverPlate(
            mark: path.origin,
            edge: path.edge,
            hovered: true
        )
        switch path.kind {
        case .slide:
            guard path.offset != .zero else { return .fade(revealFade) }
            return .slide(offset: path.offset, length: revealSlide)
        case .grow:
            guard let plate = path.plate else { return .fade(revealFade) }
            return .morph(
                ShelfGrow.morph(
                    entering: entering,
                    mark: mark,
                    plate: plate,
                    plateRadius: path.plateRadius
                )
            )
        case .unfold:
            guard let plate = path.plate else { return .fade(revealFade) }
            return .unfold(
                ShelfUnfold.stretch(
                    entering: entering,
                    mark: mark,
                    plate: plate,
                    plateRadius: path.plateRadius,
                    horizontal: path.horizontal
                )
            )
        case .spread:
            guard let plate = path.plate else { return .fade(revealFade) }
            return .spread(
                ShelfUnfold.spread(
                    entering: entering,
                    mark: mark,
                    span: path.horizontal ? plate.width : plate.height,
                    horizontal: path.horizontal
                )
            )
        case .fade:
            return .fade(revealFade)
        }
    }

    /// The motion a reveal along `path` plays now — what the
    /// panel's room is opened for before it starts.
    static func resolvedReveal(
        _ path: RevealPath,
        entering: Bool
    ) -> RevealMotion {
        revealMotion(entering: entering, path: path)
    }

    /// The reveal's animation key, on the content and the items.
    static let revealKey = "kiwi.reveal"

    /// The slide `view` is in, as a position shift in its
    /// superlayer, nil where none plays. Read it before the view's
    /// frame moves in the same pass: the presentation shows the
    /// last commit, the model the new frame.
    @MainActor
    static func revealShift(of view: NSView) -> CGPoint? {
        guard let layer = view.layer,
            layer.animationKeys()?.contains(revealKey) == true,
            let shown = layer.presentation()
        else { return nil }
        return CGPoint(
            x: shown.position.x - layer.position.x,
            y: shown.position.y - layer.position.y
        )
    }

    /// Plays a reveal (`entering`) or a retract on `view`, the
    /// panel's content, with `items` the section strip a grow fades,
    /// and returns its length; the caller lands it through its own
    /// `afterReveal` seam. A `held` start
    /// stands still until a later call replaces it — the pass that
    /// orders the panel in holds it — and a `lead` start waits
    /// `revealLead` first. The slide is ADDITIVE on the layer's
    /// position, so a resize of the panel's room under it moves
    /// nothing; a slide already playing continues from `from`
    /// (`revealShift`), a fade from where it stands.
    @MainActor
    @discardableResult
    static func playReveal(
        _ view: NSView,
        items: NSView,
        path: RevealPath,
        entering: Bool,
        from: CGPoint? = nil,
        held: Bool = false,
        lead: Bool = false
    ) -> TimeInterval {
        view.wantsLayer = true
        items.wantsLayer = true
        guard let layer = view.layer, let strip = items.layer else {
            return 0
        }
        let motion = revealMotion(entering: entering, path: path)
        // A length of 0 is no motion: the shelf stands where it lands.
        guard path.length > 0 else {
            endReveal(view, items: items)
            return 0
        }
        let current =
            layer.animationKeys()?.contains(revealKey) == true
            ? layer.presentation() : nil
        let start = held ? 0 : CACurrentMediaTime() + (lead ? revealLead : 0)
        // Every style plays inside the user's length: its own
        // timings stretched or squeezed as one.
        let scale = revealScale(motion.length, entering: entering, path.length)
        let timed = { (animation: CAAnimation, at: TimeInterval) in
            animation.fillMode = .both
            animation.isRemovedOnCompletion = false
            if held {
                animation.speed = 0
            } else {
                animation.speed = Float(1 / scale)
                animation.beginTime = start + at * scale
            }
        }
        let tail = lead ? revealLead : 0
        if case .spread = motion {} else { endSpread(in: items) }
        switch motion {
        case .unfold(let stretch):
            playUnfold(stretch, on: layer, items: strip, timed: timed)
            return held ? 0 : stretch.length * scale + tail
        case .spread(let spread):
            playSpread(spread, on: view, items: items, timed: timed)
            return held ? 0 : spread.length * scale + tail
        case .fade(let span):
            strip.removeAnimation(forKey: revealKey)
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = current?.opacity ?? (entering ? 0 : 1)
            fade.toValue = entering ? 1 : 0
            fade.duration = span
            timed(fade, 0)
            layer.add(fade, forKey: revealKey)
            return held ? 0 : span * scale + tail
        case .morph(let morph):
            let shown =
                strip.animationKeys()?.contains(revealKey) == true
                ? strip.presentation()?.opacity : nil
            // The clip is the layer's own bounds: its origin keeps
            // the content where it rests while its frame — the
            // position — moves to the clip's place.
            let place = { clipPlace($0, on: layer) }
            let from = entering ? morph.mark : morph.plate
            let to = entering ? morph.plate : morph.mark
            let bounds = CABasicAnimation(keyPath: "bounds")
            bounds.fromValue = current?.bounds ?? from
            bounds.toValue = to
            let position = CABasicAnimation(keyPath: "position")
            position.fromValue = current?.position ?? place(from)
            position.toValue = place(to)
            let corner = CABasicAnimation(keyPath: "cornerRadius")
            corner.fromValue =
                current?.cornerRadius
                ?? (entering ? morph.markRadius : morph.plateRadius)
            corner.toValue = entering ? morph.plateRadius : morph.markRadius
            let clip = CAAnimationGroup()
            clip.animations = [bounds, position, corner]
            clip.duration = morph.plateLength
            clip.timingFunction =
                entering
                ? CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1)
                : CAMediaTimingFunction(controlPoints: 0.4, 0, 1, 1)
            timed(clip, morph.plateStart)
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = shown ?? (entering ? 0 : 1)
            fade.toValue = entering ? 1 : 0
            fade.duration = morph.itemsLength
            fade.timingFunction = CAMediaTimingFunction(name: .easeOut)
            timed(fade, morph.itemsStart)
            layer.add(clip, forKey: revealKey)
            strip.add(fade, forKey: revealKey)
            return held ? 0 : morph.length * scale + tail
        case .slide(let offset, let span):
            strip.removeAnimation(forKey: revealKey)
            // The offset in the superlayer's coordinates, whichever
            // way each layer is flipped.
            let rest = layer.convert(layer.bounds, to: layer.superlayer)
            let away = layer.convert(
                layer.bounds.offsetBy(dx: offset.dx, dy: offset.dy),
                to: layer.superlayer
            )
            let shift = CGPoint(
                x: away.minX - rest.minX,
                y: away.minY - rest.minY
            )
            let slide = CABasicAnimation(keyPath: "position")
            slide.isAdditive = true
            slide.fromValue = NSValue(
                point: from ?? (entering ? shift : .zero)
            )
            slide.toValue = NSValue(point: entering ? .zero : shift)
            slide.duration = span
            let (a, b, c, d) = revealCurve
            // A retract plays the reveal's curve backwards.
            slide.timingFunction =
                entering
                ? CAMediaTimingFunction(controlPoints: a, b, c, d)
                : CAMediaTimingFunction(
                    controlPoints: 1 - c,
                    1 - d,
                    1 - a,
                    1 - b
                )
            timed(slide, 0)
            layer.add(slide, forKey: revealKey)
            return held ? 0 : span * scale + tail
        }
    }
}
