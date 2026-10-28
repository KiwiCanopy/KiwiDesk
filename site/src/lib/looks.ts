/**
 * The looks gallery (#1740), read ONCE per build from the public
 * `KiwiCanopy/KiwiDesk-Looks` repo: its generated `index.json`,
 * then each look's own file for the colors the preview sketch
 * draws. Build time, never the browser, like `stars.ts` and
 * `voices.ts`: the CSP (`public/_headers`) and the privacy policy
 * promise no third-party request from a visitor's page, so a
 * screenshot goes through astro:assets (`image.remotePatterns`)
 * and is served from the site itself.
 *
 * Unauthenticated against raw.githubusercontent.com, no secret
 * (`.claude/rules/site.md` ▸ *Build-time reads*). A failed index
 * read renders NO look and says so in the build log, so a GitHub
 * hiccup never fails the deploy; the site gate reds instead when
 * the built /looks page draws no card (`check-site-tokens.py` ▸
 * `check_looks_rendered`). A failed look file only drops that
 * look's sketch colors, and an unreachable screenshot falls back
 * to the sketch.
 */
const REPO = "KiwiCanopy/KiwiDesk-Looks";
const RAW = `https://raw.githubusercontent.com/${REPO}/main/`;
const INDEX_FORMAT = 1;
const TIMEOUT_MS = 5000;

export const LOOKS_REPO_URL = `https://github.com/${REPO}`;
export const SUBMIT_URL =
  `${LOOKS_REPO_URL}/issues/new?template=submit-look.yml`;
export const REPORT_URL =
  `${LOOKS_REPO_URL}/issues/new?template=report-look.yml`;
export const CC_BY_URL = "https://creativecommons.org/licenses/by/4.0/";

/** Who a look credits. `removed` means the original's author took
 * their name off the gallery; `id` is set only when the original
 * came from the gallery. */
export type Credit =
  | { removed: false; name: string; author: string; id: string | null }
  | { removed: true };

/** What the sketch draws when there is no screenshot: the look's
 * own colors (validated hex) and the shape of its bars and border. */
export interface Sketch {
  fill: string | null;
  item: string | null;
  active: string | null;
  ring: string | null;
  /** Focus border width in points, 0–12. */
  ringWidth: number;
  glow: boolean;
  square: boolean;
  glass: boolean;
  /** Bar corner roundness, 0–1. */
  roundness: number;
  /** Bar edges, the Space Bar's first; one entry when both share. */
  edges: Edge[];
  boxed: boolean;
  hug: boolean;
  centered: boolean;
  font: string | null;
}
export type Edge = "top" | "bottom" | "left" | "right";

export interface Look {
  id: string;
  name: string;
  author: string;
  credit: Credit | null;
  builtOn: string[];
  tags: string[];
  keywords: string[];
  inspiredBy: string | null;
  description: string;
  version: string | null;
  needsFonts: string[];
  fontUrl: string | null;
  /** Remote image URL the build downloads, and how it was made. */
  image: { src: string; kind: "screenshot" | "preview" } | null;
  added: string;
  updated: string;
  revision: number;
  likes: number;
  likeUrl: string;
  downloads: number;
  downloadUrl: string;
  sketch: Sketch | null;
}

/**
 * The main button: one place for its label key and target, so the
 * switch to "Add to KiwiDesk" and a `kiwidesk://` link is one edit
 * here once the app handles the scheme (owner, 2026-10-28).
 */
export const mainAction = (look: Look) => ({
  href: look.downloadUrl,
  labelKey: "looks_download",
  ariaKey: "looks_download_aria",
});

/** Families KiwiDesk itself draws with; never a "Needs font". */
export const SYSTEM_FONTS: Record<string, string> = {
  System: "looks_font_system",
  "System Monospaced": "looks_font_system_mono",
};

const HEX = /^#[0-9a-f]{6}(?:[0-9a-f]{2})?$/i;
const ID = /^[a-z0-9][a-z0-9-]*$/;
const DATE = /^\d{4}-\d{2}-\d{2}$/;

const text = (v: unknown): string | null =>
  typeof v === "string" && v.trim() !== "" ? v.trim() : null;
const count = (v: unknown): number =>
  Number.isInteger(v) && (v as number) >= 0 ? (v as number) : 0;
const strings = (v: unknown): string[] =>
  Array.isArray(v) ? v.map(text).filter((s): s is string => !!s) : [];
const https = (v: unknown): string | null => {
  const s = text(v);
  return s?.startsWith("https://") ? s : null;
};
const color = (v: unknown): string | null => {
  const s = text(v);
  return s && HEX.test(s) ? s : null;
};
const edge = (v: unknown): Edge =>
  v === "bottom" || v === "left" || v === "right" ? v : "top";

function toCredit(v: any): Credit | null {
  if (v === null || v === undefined) return null;
  if (v?.removed === true) return { removed: true };
  const name = text(v?.name);
  const author = text(v?.author);
  if (!name || !author) return null;
  const id = text(v?.id);
  return { removed: false, name, author, id: id && ID.test(id) ? id : null };
}

/** A row and the path of its look file, or `null` when malformed. */
function toLook(row: any): { look: Look; file: string } | null {
  const id = text(row?.id);
  const name = text(row?.name);
  const author = text(row?.author);
  const file = text(row?.file);
  const likeUrl = https(row?.like_url);
  const downloadUrl = https(row?.download_url);
  const added = text(row?.added);
  if (
    !id || !ID.test(id) || !name || !author || !file ||
    !likeUrl || !downloadUrl || !added || !DATE.test(added)
  ) {
    return null;
  }
  const updated = text(row?.updated);
  const path = text(row?.image?.path);
  const fonts = strings(row?.needs_fonts).filter(
    (f) => !Object.hasOwn(SYSTEM_FONTS, f),
  );
  const look: Look = {
    id,
    name,
    author,
    credit: toCredit(row?.based_on),
    builtOn: strings(row?.built_on).filter((b) => ID.test(b)),
    tags: strings(row?.tags),
    keywords: strings(row?.keywords),
    inspiredBy: text(row?.inspired_by),
    description: text(row?.description) ?? "",
    version: text(row?.kiwidesk_version),
    needsFonts: fonts,
    fontUrl: https(row?.font_url),
    image:
      path && !path.includes("..")
        ? {
            src: RAW + path.replace(/^\/+/, ""),
            kind: row?.image?.kind === "screenshot" ? "screenshot" : "preview",
          }
        : null,
    added,
    updated: updated && DATE.test(updated) ? updated : added,
    revision: Math.max(1, count(row?.version)),
    likes: count(row?.likes),
    likeUrl,
    downloads: count(row?.downloads),
    downloadUrl,
    sketch: null,
  };
  return { look, file };
}

async function get(url: string): Promise<any> {
  const res = await fetch(url, { signal: AbortSignal.timeout(TIMEOUT_MS) });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.json();
}

/** The sketch values of one look file, or `null` when unreadable. */
async function readSketch(look: Look, file: string): Promise<Sketch | null> {
  try {
    const doc = await get(RAW + file.replace(/^\/+/, ""));
    const colors = doc?.look?.colors ?? {};
    const style = doc?.look?.style ?? {};
    const spaceEdge = edge(style["space_bar.edge"]);
    const appEdge = edge(style["app_bar.edge"]);
    const width = Number(style["border.width"]);
    const round = Number(style["kiwishelf.corner_roundness"]);
    return {
      fill: color(colors["kiwishelf.fill_color"]),
      item: color(colors["kiwishelf.item_color"]),
      active: color(colors["kiwishelf.active_item_color"]),
      ring: color(colors["border.focused_color"]),
      ringWidth: Number.isFinite(width) ? Math.min(Math.max(width, 0), 12) : 3,
      glow: style["border.glow"] === true,
      square: style["border.corner_style"] === "square",
      glass: style["kiwishelf.liquid_glass"] === true,
      roundness: Number.isFinite(round)
        ? Math.min(Math.max(round, 0), 100) / 100
        : 0.5,
      edges: spaceEdge === appEdge ? [spaceEdge] : [spaceEdge, appEdge],
      boxed: style["kiwishelf.background_style"] === "boxed",
      hug: style["kiwishelf.background_fit"] === "hug",
      centered: style["kiwishelf.alignment"] !== "start",
      font: text(style["kiwishelf.font_family"]),
    };
  } catch (error) {
    console.warn(`[looks] no sketch for ${look.id}: ${error}`);
    return null;
  }
}

/** `look` with its image dropped unless GitHub serves it now. */
async function withReachableImage(look: Look): Promise<Look> {
  if (!look.image) return look;
  try {
    const res = await fetch(look.image.src, {
      method: "HEAD",
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });
    if (res.ok) return look;
    console.warn(`[looks] image of ${look.id}: HTTP ${res.status}`);
  } catch (error) {
    console.warn(`[looks] image of ${look.id}: ${error}`);
  }
  return { ...look, image: null };
}

const none = (why: string): Look[] => {
  console.warn(`[looks] rendering no looks: ${why}`);
  return [];
};

async function read(): Promise<Look[]> {
  try {
    const index = await get(RAW + "index.json");
    if (index?.format !== INDEX_FORMAT) {
      return none(`index format ${index?.format}, not ${INDEX_FORMAT}`);
    }
    if (!Array.isArray(index.looks)) return none("no looks array");
    const rows: ({ look: Look; file: string } | null)[] =
      index.looks.map(toLook);
    const seen = new Set<string>();
    const valid = rows.filter((r): r is { look: Look; file: string } => {
      if (!r || seen.has(r.look.id)) return false;
      seen.add(r.look.id);
      return true;
    });
    const dropped = rows.length - valid.length;
    if (dropped > 0) console.warn(`[looks] dropped ${dropped} malformed`);
    if (valid.length === 0) return none("the index lists no look");
    return await Promise.all(
      valid.map(async ({ look, file }) => {
        const shown = await withReachableImage(look);
        const sketch = shown.image ? null : await readSketch(shown, file);
        return { ...shown, sketch };
      }),
    );
  } catch (error) {
    return none(String(error));
  }
}

export const looks: Look[] = await read();

// ---- Orders (#1740 ▸ Sorting) ----------------------------------

const DAY_MS = 86_400_000;
const dayNumber = (iso: string): number =>
  Math.floor(Date.parse(`${iso}T00:00:00Z`) / DAY_MS);

/** Seeded PRNG (mulberry32): the same cycle shuffles the same way
 * on every build of that cycle. */
function mulberry32(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function shuffled<T>(items: T[], seed: number): T[] {
  const out = [...items];
  const random = mulberry32(seed);
  for (let i = out.length - 1; i > 0; i--) {
    const j = Math.floor(random() * (i + 1));
    [out[i], out[j]] = [out[j], out[i]];
  }
  return out;
}

/** Top block: 6 looks, 12 from about 150. */
const topBlock = (n: number): number => (n >= 150 ? 12 : 6);
/** Places in the top block kept for looks added in the window. */
const NEW_PLACES = 2;
const NEW_WINDOW_DAYS = 14;

/**
 * Discover, the default: a fair daily rotation from the UTC date,
 * computed at build time. Up to two looks added in the last 14
 * days (by add date, newest first) lead; every other look rotates
 * through the remaining top places, shuffled once per cycle with
 * the cycle number as seed and shifted each day by those places.
 * A cycle lasts until every look has had its turn. Likes and
 * downloads never touch it.
 */
export function discoverOrder(list: Look[], now = new Date()): Look[] {
  const today = Math.floor(now.getTime() / DAY_MS);
  const fresh = list
    .filter((l) => today - dayNumber(l.added) <= NEW_WINDOW_DAYS)
    .sort((a, b) => b.added.localeCompare(a.added) || a.id.localeCompare(b.id))
    .slice(0, NEW_PLACES);
  const free = Math.max(1, topBlock(list.length) - NEW_PLACES);
  const cycleDays = Math.max(1, Math.ceil(list.length / free));
  const cycle = Math.floor(today / cycleDays);
  const base = [...list].sort((a, b) => a.id.localeCompare(b.id));
  const deck = shuffled(base, cycle);
  const shift = deck.length ? ((today % cycleDays) * free) % deck.length : 0;
  const rotated = [...deck.slice(shift), ...deck.slice(0, shift)];
  const lead = new Set(fresh.map((l) => l.id));
  return [...fresh, ...rotated.filter((l) => !lead.has(l.id))];
}

/** Recent: by the later of added and updated, newest first. */
export const recentOrder = (list: Look[]): Look[] =>
  [...list].sort(
    (a, b) =>
      b.updated.localeCompare(a.updated) ||
      b.added.localeCompare(a.added) ||
      a.name.localeCompare(b.name),
  );

/** Popular: by likes, downloads breaking ties. */
export const popularOrder = (list: Look[]): Look[] =>
  [...list].sort(
    (a, b) =>
      b.likes - a.likes ||
      b.downloads - a.downloads ||
      a.name.localeCompare(b.name),
  );

/** Whether Recent labels the look "Updated" rather than "New". */
export const wasUpdated = (look: Look): boolean =>
  look.revision > 1 || look.updated > look.added;

// ---- Formatting ------------------------------------------------

/** A count as a card shows it: 1.2k from 1,000. */
export function shortCount(n: number, lang: string): string {
  if (n < 1000) return new Intl.NumberFormat(lang).format(n);
  const k = new Intl.NumberFormat(lang, { maximumFractionDigits: 1 })
    .format(Math.floor(n / 100) / 10);
  return `${k}k`;
}

export const fullCount = (n: number, lang: string): string =>
  new Intl.NumberFormat(lang).format(n);

/** A `YYYY-MM-DD` date as `lang` writes it. */
export const formatDate = (iso: string, lang: string): string =>
  new Intl.DateTimeFormat(lang, { dateStyle: "medium", timeZone: "UTC" })
    .format(new Date(`${iso}T00:00:00Z`));

/**
 * The sketch's inline custom properties. The values are look DATA
 * from the gallery, not brand colors, so they live in the built
 * page's `style` attributes and nowhere in `site/src`.
 */
export function sketchStyle(s: Sketch | null): string {
  if (!s) return "";
  const props: [string, string | null][] = [
    ["--lk-fill", s.fill],
    ["--lk-item", s.item],
    ["--lk-active", s.active],
    ["--lk-ring", s.ring],
    ["--lk-ring-w", `${(s.ringWidth / 4).toFixed(2)}cqi`],
    ["--lk-round", s.roundness.toFixed(2)],
  ];
  return props
    .filter(([, v]) => v !== null)
    .map(([k, v]) => `${k}: ${v}`)
    .join("; ");
}
