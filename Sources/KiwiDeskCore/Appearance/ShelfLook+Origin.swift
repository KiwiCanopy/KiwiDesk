import Foundation

/// Where the current look came from (#1740 ▸ Step 3 decisions): a
/// pick of a look that credits someone records it as the origin, a
/// pick of the user's own or a bundled look clears it, and Share and
/// Save credit the origin while half of it is kept.
extension ShelfLook {
    /// Whether picking this look records it as the origin: it names
    /// an author, or carries the credit a saved look kept.
    public var recordsOrigin: Bool { author != nil || basedOn != nil }

    /// Paints this look onto `settings` as a PICK — the one door a
    /// Settings tile and `look.apply` take — and records or clears
    /// the origin.
    public func pick(into settings: inout TilingSettings) {
        let look = admitted
        look.apply(to: &settings)
        settings.lookOrigin = recordsOrigin ? look : nil
    }

    /// The look `settings` wear now, under `name`, with the credit
    /// its origin still earns — what Save stores and Share sends.
    public static func current(
        named name: String,
        in settings: TilingSettings
    ) -> ShelfLook {
        ShelfLook(
            name: name,
            style: LookKeys.extract(from: settings),
            colors: ColorPaletteKeys.extract(from: settings),
            basedOn: settings.lookCredit
        )
    }

    /// The credit a look started from this one carries: its author's
    /// own, else the credit it kept.
    public var credit: LookCredit? {
        guard let author else { return basedOn }
        return LookCredit(name: name, author: author)
    }
}

extension TilingSettings {
    /// The credit Share and Save attach: the origin's while it is
    /// `stillCredited` (ShelfLook+Credit.swift), else none. An
    /// origin since deleted from the library keeps it.
    public var lookCredit: LookCredit? {
        guard let lookOrigin, lookOrigin.stillCredited(by: self) else {
            return nil
        }
        return lookOrigin.credit
    }
}
