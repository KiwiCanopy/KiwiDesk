/// The looks gallery's one switch (#1740 ▸ Launch together): its
/// doors — Advanced's Share this look… and Browse looks…, and
/// Simple's Browse tile — exist only while it is on, and switched
/// off they are not drawn at all, never greyed. The owner flips it
/// with the site's nav and sitemap at launch; the flip owes each
/// door its census row (`SettingKey`), since search lands on a
/// census row and a door that is not drawn has none.
enum LookGallery {
    static let isLive = false
}
