import AppKit

/// The leave fades a veil runs (#2417): while one is in flight the
/// content's mask stands down and the dim and the blur each take a
/// mask of their own — the resting shape less every fading region,
/// plus one layer per region whose opacity runs from clear to
/// covered. Glass cannot change its strength, so the blur fades by
/// the same mask opacity as the dim.
@MainActor
final class VisionVeilFade {
    let dimMask = CALayer()
    let blurMask = CALayer()
    let dimBase = CAShapeLayer()
    let blurBase = CAShapeLayer()
    /// Each region in flight, with its dim and its blur layer.
    var regions: [(path: CGPath, dim: CAShapeLayer, blur: CAShapeLayer)] =
        []
    /// Bumped per fade: only the newest fade's end ends them all.
    var generation = 0

    init() {
        dimMask.addSublayer(dimBase)
        blurMask.addSublayer(blurBase)
    }

    static func shapeLayer() -> CAShapeLayer {
        let layer = CAShapeLayer()
        layer.fillColor = NSColor.black.cgColor
        return layer
    }
}

extension VisionVeil {
    /// Fades `region` (the view's coordinates) from clear to the
    /// veil over `duration` seconds on `timing`, the dim and the
    /// blur together. A fade already running keeps going beside it.
    func fadeIn(
        _ region: CGPath,
        duration: CFTimeInterval,
        timing: CAMediaTimingFunction
    ) {
        guard let root = view.layer, duration > 0 else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let fade = self.fade ?? VisionVeilFade()
        if self.fade == nil {
            self.fade = fade
            fade.dimBase.fillColor = NSColor.black.cgColor
            fade.blurBase.fillColor = NSColor.black.cgColor
            root.mask = nil
            dimLayer.mask = fade.dimMask
            blurHost.layer?.mask = fade.blurMask
        }
        let dim = VisionVeilFade.shapeLayer()
        let blur = VisionVeilFade.shapeLayer()
        fade.dimMask.addSublayer(dim)
        fade.blurMask.addSublayer(blur)
        fade.regions.append((region, dim, blur))
        layoutFade()
        fade.generation += 1
        let generation = fade.generation
        CATransaction.setCompletionBlock { [weak self] in
            MainActor.assumeIsolated { self?.fadeEnded(generation) }
        }
        let begin = CACurrentMediaTime()
        for layer in [dim, blur] {
            layer.add(
                BarMotion.opacityFade(
                    from: 0,
                    to: 1,
                    begin: begin,
                    duration: duration,
                    reduceMotion: false,
                    timing: timing
                ),
                forKey: "fade"
            )
        }
        CATransaction.commit()
    }

    /// Lays the fade's masks over the resting shape: the base is
    /// that shape less every region, each region what of it the
    /// resting shape covers.
    func layoutFade() {
        guard let fade, let root = view.layer else { return }
        let bounds = root.bounds
        let whole = restingPath ?? CGPath(rect: bounds, transform: nil)
        let fading = fade.regions.reduce(CGPath(rect: .zero, transform: nil)) {
            $0.union($1.path)
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for layer in [
            fade.dimMask, fade.blurMask, fade.dimBase, fade.blurBase,
        ] {
            layer.frame = bounds
        }
        let base = whole.subtracting(fading)
        fade.dimBase.path = base
        fade.blurBase.path = base
        for region in fade.regions {
            let path = region.path.intersection(whole)
            region.dim.frame = bounds
            region.blur.frame = bounds
            region.dim.path = path
            region.blur.path = path
        }
        CATransaction.commit()
    }

    /// The newest fade landed: every region is covered, so the
    /// content takes its resting mask again.
    private func fadeEnded(_ generation: Int) {
        guard let fade, fade.generation == generation else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        dimLayer.mask = nil
        blurHost.layer?.mask = nil
        self.fade = nil
        CATransaction.commit()
        mask(restingPath)
    }
}
