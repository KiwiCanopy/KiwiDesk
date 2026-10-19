import AppKit

/// The leave fades a veil runs (#2417): while one is in flight the
/// content's mask stands down and the dim and the blur each take a
/// mask of their own — the resting shape less every fading region,
/// plus one layer per region whose opacity runs from clear to
/// covered. Glass cannot change its strength, so the blur fades by
/// the same mask opacity as the dim.
@MainActor
final class VisionVeilFade {
    /// One window's region in flight. `token` names the fade that
    /// last started it, so an older fade's end retires nothing.
    struct Region {
        var path: CGPath
        var dim: CAShapeLayer
        var blur: CAShapeLayer
        var token: Int
    }

    let dimMask = CALayer()
    let blurMask = CALayer()
    let dimBase = CAShapeLayer()
    let blurBase = CAShapeLayer()
    /// Each window's region in flight, keyed by the window.
    var regions: [CGWindowID: Region] = [:]
    /// Bumped per fade started.
    var token = 0

    init() {
        dimMask.addSublayer(dimBase)
        blurMask.addSublayer(blurBase)
        dimBase.fillColor = NSColor.black.cgColor
        blurBase.fillColor = NSColor.black.cgColor
    }

    static func shapeLayer() -> CAShapeLayer {
        let layer = CAShapeLayer()
        layer.fillColor = NSColor.black.cgColor
        return layer
    }
}

extension VisionVeil {
    /// Fades `window`'s `region` (the view's coordinates) from clear
    /// to the veil over `duration` seconds on `timing`, the dim and
    /// the blur together; cut in under `reduceMotion`. A window
    /// left again mid-fade carries on from where its region is now,
    /// and other windows' fades keep going beside it.
    func fadeIn(
        _ region: CGPath,
        of window: CGWindowID,
        duration: CFTimeInterval,
        timing: CAMediaTimingFunction,
        reduceMotion: Bool
    ) {
        guard let root = view.layer, duration > 0 else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let fade = self.fade ?? VisionVeilFade()
        if self.fade == nil {
            self.fade = fade
            root.mask = nil
            dimLayer.mask = fade.dimMask
            blurHost.layer?.mask = fade.blurMask
        }
        fade.token += 1
        let token = fade.token
        var entry =
            fade.regions[window]
            ?? VisionVeilFade.Region(
                path: region,
                dim: VisionVeilFade.shapeLayer(),
                blur: VisionVeilFade.shapeLayer(),
                token: token
            )
        if fade.regions[window] == nil {
            entry.dim.opacity = 0
            entry.blur.opacity = 0
            fade.dimMask.addSublayer(entry.dim)
            fade.blurMask.addSublayer(entry.blur)
        }
        entry.path = region
        entry.token = token
        fade.regions[window] = entry
        layoutFade()
        CATransaction.setCompletionBlock { [weak self] in
            MainActor.assumeIsolated {
                self?.fadeEnded(window, token: token)
            }
        }
        let begin = CACurrentMediaTime()
        for layer in [entry.dim, entry.blur] {
            let from = layer.presentation()?.opacity ?? layer.opacity
            layer.removeAnimation(forKey: "fade")
            layer.add(
                BarMotion.opacityFade(
                    from: from,
                    to: 1,
                    begin: begin,
                    duration: duration,
                    reduceMotion: reduceMotion,
                    timing: timing
                ),
                forKey: "fade"
            )
            layer.opacity = 1
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
        let fading = fade.regions.values.reduce(
            CGPath(rect: .zero, transform: nil)
        ) { $0.union($1.path) }
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
        for region in fade.regions.values {
            let path = region.path.intersection(whole)
            region.dim.frame = bounds
            region.blur.frame = bounds
            region.dim.path = path
            region.blur.path = path
        }
        CATransaction.commit()
    }

    /// `window`'s fade landed, unless a newer one restarted it: its
    /// region joins the base, and once none is left the content
    /// takes its resting mask again — in one transaction, so no
    /// frame draws the veil unmasked.
    func fadeEnded(_ window: CGWindowID, token: Int) {
        guard let fade, let region = fade.regions[window],
            region.token == token
        else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        region.dim.removeFromSuperlayer()
        region.blur.removeFromSuperlayer()
        fade.regions[window] = nil
        if fade.regions.isEmpty {
            self.fade = nil
            mask(restingPath)
            dimLayer.mask = nil
            blurHost.layer?.mask = nil
        } else {
            layoutFade()
        }
        CATransaction.commit()
    }
}
