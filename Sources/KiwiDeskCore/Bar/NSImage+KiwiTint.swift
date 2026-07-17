import AppKit
import CoreImage

extension NSImage {
    /// The image recolored to a monochrome ramp of `color`
    /// (#294 `tinted_image`): luminance maps into the tint,
    /// alpha survives — the iOS/macOS "Tinted" icon look.
    /// `darkRamp` inverts the luminance first so the icon
    /// renders dark (for light bars) instead of light.
    /// Returns self when the image has no bitmap (nothing to
    /// tint, better untinted than blank). Cheap at bar icon
    /// sizes; callers re-tint on state color changes.
    func kiwiTinted(
        with color: NSColor,
        darkRamp: Bool = false
    ) -> NSImage {
        var rect = CGRect(origin: .zero, size: size)
        guard
            let cg = cgImage(
                forProposedRect: &rect,
                context: nil,
                hints: nil
            ),
            let tint = CIColor(
                color: color.usingColorSpace(.sRGB) ?? color
            )
        else { return self }
        var source = CIImage(cgImage: cg)
        if darkRamp {
            source = source.applyingFilter("CIColorInvert")
        }
        let filter = CIFilter(name: "CIColorMonochrome")
        filter?.setValue(source, forKey: kCIInputImageKey)
        filter?.setValue(tint, forKey: kCIInputColorKey)
        filter?.setValue(1.0, forKey: kCIInputIntensityKey)
        guard let output = filter?.outputImage else {
            return self
        }
        let rep = NSCIImageRep(ciImage: output)
        let image = NSImage(size: size)
        image.addRepresentation(rep)
        return image
    }
}
