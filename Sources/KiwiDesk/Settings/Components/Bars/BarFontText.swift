import KiwiDeskCore

/// The Settings words for the shelf's font (#1681): Core stores a
/// family name and a weight number and reads what they draw
/// (`BarFont`); these narrate it.
@MainActor
enum BarFontText {
    /// A stored family as the user reads it: the two system
    /// families localized, an installed one by its own name.
    static func familyName(_ family: String) -> String {
        switch family {
        case KiwiShelf.systemFontFamily:
            return L("kiwishelf.font_family.system", "System")
        case KiwiShelf.systemMonospacedFontFamily:
            return L(
                "kiwishelf.font_family.system_monospaced",
                "System Monospaced"
            )
        default:
            return family
        }
    }

    /// A named weight's title — a chip's, and the caption's.
    static func weightName(_ weight: BarFontWeight) -> String {
        switch weight {
        case .ultralight:
            return L("kiwishelf.font_weight.ultralight", "Ultralight")
        case .thin: return L("kiwishelf.font_weight.thin", "Thin")
        case .light: return L("kiwishelf.font_weight.light", "Light")
        case .regular:
            return L("kiwishelf.font_weight.regular", "Regular")
        case .medium: return L("kiwishelf.font_weight.medium", "Medium")
        case .semibold:
            return L("kiwishelf.font_weight.semibold", "Semibold")
        case .bold: return L("kiwishelf.font_weight.bold", "Bold")
        case .heavy: return L("kiwishelf.font_weight.heavy", "Heavy")
        case .black: return L("kiwishelf.font_weight.black", "Black")
        }
    }

    /// The trigger's words for a family that is not installed.
    static var missing: String {
        L(
            "kiwishelf.font_family.missing",
            "Not installed — drawing %1$@",
            familyName(KiwiShelf.systemFontFamily)
        )
    }

    /// The weight row's caption: what the family draws in place of
    /// the stored weight, or nil when it draws that weight — or a
    /// face the chips would name alike, which a caption naming it
    /// as different would contradict.
    static func weightCaption(
        family: String,
        rendering: BarFont.Rendering,
        weight: Int
    ) -> String? {
        guard case .nearestFace(let drawn) = rendering else {
            return nil
        }
        let face = BarFontWeight.nearest(to: drawn)
        guard face != BarFontWeight.nearest(to: weight) else {
            return nil
        }
        return L(
            "kiwishelf.font_weight.nearest",
            "%1$@ has no weight %2$@, so it draws its “%3$@” face.",
            familyName(family),
            String(weight),
            weightName(face)
        )
    }

    /// Why the weight slider is greyed: `family` draws fixed faces
    /// only, so the chips are the choice (#1859). Nil for a family
    /// on a `wght` axis.
    static func fixedFacesCaption(family: String) -> String? {
        guard !BarFont.hasWeightAxis(family) else { return nil }
        return L(
            "kiwishelf.font_weight.fixed_faces",
            "%1$@ comes in fixed weights only — pick one above.",
            familyName(family)
        )
    }

    /// The slider's spoken value: the number and its nearest name,
    /// so a VoiceOver user hears the chip it sits on.
    static func spokenWeight(_ weight: Int) -> String {
        L(
            "kiwishelf.font_weight.spoken",
            "%1$@, %2$@",
            String(weight),
            weightName(BarFontWeight.nearest(to: weight))
        )
    }
}
