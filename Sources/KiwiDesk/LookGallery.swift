/// The looks gallery's doors are drawn only while this is on, and
/// never greyed while it is off (#1740 ▸ Launch together); turning
/// it on owes each door its `SettingKey` census row.
enum LookGallery {
    static let isLive = false
}
