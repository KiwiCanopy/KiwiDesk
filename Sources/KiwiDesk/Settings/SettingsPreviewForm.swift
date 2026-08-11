/// Which form an offering area's live preview takes at the
/// measured width (#678 turn 17a), as ONE total derivation
/// rather than three predicates a site can get half right.
///
/// The point of stating it as an enum is what the enum makes
/// impossible: an area that offers a preview always lands on
/// exactly one of these three, so no width and no answer can
/// leave the preview unreachable. 17a drops the preview's
/// COLUMN as the window narrows — never the preview, and never
/// the way to it (`SettingsResponsiveOrderTests` proves the
/// totality over every band and every answer).
enum SettingsPreviewForm: String, CaseIterable, Sendable {
    /// A column of its own beside the content — the only form
    /// that takes layout space, and so the only one the save
    /// pill's centring offset answers to.
    case docked
    /// A card over the content: draggable, closable, and the
    /// same object in both narrow bands.
    case floating
    /// No card, and the "Show preview" offer in its place.
    case offer

    /// `shown` is the user's answer this mount, `nil` while the
    /// band's own default stands.
    static func at(
        _ width: SettingsWidthClass,
        shown: Bool?
    ) -> SettingsPreviewForm {
        if width.docksPanel { return .docked }
        return (shown ?? width.floatsPreviewByDefault)
            ? .floating : .offer
    }
}
