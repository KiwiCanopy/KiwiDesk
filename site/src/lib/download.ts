import changelog from "../data/changelog.json";

/**
 * The promoted direct download (#904), or `null` when no
 * published release carries one.
 *
 * The URL is a release's OWN `.dmg` asset URL, recorded by
 * `scripts/changelog-sync` off the releases API — never composed
 * here from a version string. The argument for that, and for
 * omitting a download affordance outright rather than dimming
 * it, is `.claude/rules/site.md` ▸ *A promoted download link is
 * read off the release's own asset list*.
 *
 * It lives here rather than in each page because the SELECTION
 * rule — newest entry carrying a `download` — is a decision, not
 * a formatting detail: `Landing.astro` and `Guide.astro` must
 * offer the same build, and two hand-copies would drift the day
 * either grew a clause (a `prerelease` filter, say) that the
 * other did not. The entries are newest-first, which
 * `changelog-sync`'s own `_sort_key` guarantees.
 */
export const downloadHref: string | null =
  (changelog.releases as { download?: string }[]).find(
    (release) =>
      typeof release.download === "string" && release.download,
  )?.download ?? null;

/**
 * The version the promoted download is of, or `null` when there
 * is none. Read from the SAME entry as `downloadHref` rather
 * than from `releases[0]`, so the two can never describe
 * different releases.
 */
export const downloadVersion: string | null =
  (changelog.releases as { download?: string; version?: string }[]).find(
    (release) =>
      typeof release.download === "string" && release.download,
  )?.version ?? null;
