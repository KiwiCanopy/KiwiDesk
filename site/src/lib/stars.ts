/**
 * The repo's GitHub star count, read ONCE per build.
 *
 * Build time, not in the browser: the site's CSP (`public/_headers`,
 * `connect-src 'self'`) and its privacy policy both promise no
 * third-party request from a visitor's page. Every push to `main`
 * redeploys, which keeps the number fresh enough.
 *
 * Any failure — offline build, rate limit, timeout — falls back to
 * `FLOOR`, a count the repo has already passed, so the page never
 * overstates it. Raise it now and then; never lower it.
 */
const FLOOR = 88;
const API = "https://api.github.com/repos/KiwiCanopy/KiwiDesk";

async function read(): Promise<number> {
  try {
    const token = process.env.GITHUB_TOKEN;
    const res = await fetch(API, {
      headers: {
        Accept: "application/vnd.github+json",
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
      signal: AbortSignal.timeout(5000),
    });
    if (!res.ok) return FLOOR;
    const n = (await res.json()).stargazers_count;
    return Number.isInteger(n) && n >= FLOOR ? n : FLOOR;
  } catch {
    return FLOOR;
  }
}

export const githubStars: number = await read();

/** The count as `lang` writes it, compact past a thousand. */
export const formatStars = (lang: string): string =>
  new Intl.NumberFormat(lang, {
    notation: githubStars >= 1000 ? "compact" : "standard",
    maximumFractionDigits: 1,
  }).format(githubStars);
