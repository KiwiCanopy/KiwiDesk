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
 * look's sketch and font, and a screenshot that is unreachable,
 * not a PNG or too large falls back to the sketch.
 */
import sharp from "sharp";

const REPO = "KiwiCanopy/KiwiDesk-Looks";
const RAW = `https://raw.githubusercontent.com/${REPO}/main/`;
const INDEX_FORMAT = 1;
const TIMEOUT_MS = 5000;
/** The look format KiwiDesk 4.0.0 reads (`LookDocument.currentFormat`);
 * moves with the release that bumps that format. */
export const RELEASED_LOOK_FORMAT = 2;
/** The largest screenshot the build downloads, in bytes. */
const MAX_IMAGE_BYTES = 8_000_000;
/** The longest screenshot edge the build accepts, in pixels. */
const MAX_IMAGE_EDGE = 8000;

export const LOOKS_REPO_URL = `https://github.com/${REPO}`;
/** Every like and download link a look carries starts here. */
const REPO_PREFIX = `${LOOKS_REPO_URL}/`;
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
  /** Remote image the build downloads, how it was made, and its
   * pixel size (read from the PNG the build fetched). */
  image: {
    src: string;
    kind: "screenshot" | "preview";
    width: number;
    height: number;
  } | null;
  /** The look file's `look_format`; 0 when the index omits it. */
  lookFormat: number;
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
 * The main button: one place for its label key and target. It hands
 * the look to the app over `kiwidesk://look/<id>` (owner,
 * 2026-10-28); the detail view adds a plain file download under it.
 */
export const mainAction = (look: Look) => ({
  href: `kiwidesk://look/${look.id}`,
  labelKey: "looks_add",
  ariaKey: "looks_add_aria",
});

/** Whether the look needs a KiwiDesk newer than the latest release
 * (#1740 ▸ Versions). */
export const needsNewerApp = (look: Look): boolean =>
  look.lookFormat > RELEASED_LOOK_FORMAT;

/** Families KiwiDesk itself draws with; never a "Needs font". */
export const SYSTEM_FONTS: Record<string, string> = {
  System: "looks_font_system",
  "System Monospaced": "looks_font_system_mono",
};

const HEX = /^#[0-9a-f]{6}(?:[0-9a-f]{2})?$/i;
const ID = /^[a-z0-9][a-z0-9-]*$/;
const DATE = /^\d{4}-\d{2}-\d{2}$/;
const IMAGE_PATH = /^looks\/[a-z0-9-]+\/(?:screenshot|preview)\.png$/;

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
/** A link into the looks repo, or `null` for any other target. */
const repoLink = (v: unknown): string | null => {
  const s = text(v);
  return s?.startsWith(REPO_PREFIX) && !s.includes("..") ? s : null;
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
  const likeUrl = repoLink(row?.like_url);
  const downloadUrl = repoLink(row?.download_url);
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
      path && IMAGE_PATH.test(path)
        ? {
            src: RAW + path,
            kind: row?.image?.kind === "screenshot" ? "screenshot" : "preview",
            width: 0,
            height: 0,
          }
        : null,
    lookFormat: count(row?.look_format),
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

/** The pixel size of a PNG, or why `bytes` is not one we accept.
 * Decodes it whole, so a truncated file is refused here rather
 * than failing the image pipeline later in the build. */
async function pngSize(
  bytes: Uint8Array,
): Promise<{ width: number; height: number }> {
  if (bytes.length > MAX_IMAGE_BYTES) {
    throw new Error(`${bytes.length} bytes, over ${MAX_IMAGE_BYTES}`);
  }
  const image = sharp(bytes, {
    limitInputPixels: MAX_IMAGE_EDGE * MAX_IMAGE_EDGE,
  });
  const { format, width, height } = await image.metadata();
  if (format !== "png") throw new Error(`${format ?? "unknown"}, not PNG`);
  if (!width || !height || width > MAX_IMAGE_EDGE || height > MAX_IMAGE_EDGE) {
    throw new Error(`${width}×${height} px`);
  }
  await image.stats();
  return { width, height };
}

/** `look` with its image dropped unless GitHub serves it now as a
 * PNG within the size limits; the kept image carries its size. */
async function withServedImage(look: Look): Promise<Look> {
  if (!look.image) return look;
  try {
    const res = await fetch(look.image.src, {
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const type = res.headers.get("content-type") ?? "";
    if (!/^image\/png\b/i.test(type) && !/^application\/octet-stream/i.test(type)) {
      throw new Error(`content-type ${type || "missing"}`);
    }
    const declared = Number(res.headers.get("content-length"));
    if (declared > MAX_IMAGE_BYTES) {
      throw new Error(`${declared} bytes, over ${MAX_IMAGE_BYTES}`);
    }
    const size = await pngSize(new Uint8Array(await res.arrayBuffer()));
    return { ...look, image: { ...look.image, ...size } };
  } catch (error) {
    console.warn(`[looks] image of ${look.id} dropped: ${error}`);
    return { ...look, image: null };
  }
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
        const [shown, sketch] = await Promise.all([
          withServedImage(look),
          readSketch(look, file),
        ]);
        return { ...shown, sketch };
      }),
    );
  } catch (error) {
    return none(String(error));
  }
}

export const looks: Look[] = await read();

// ---- Orders (#1740 ▸ Sorting) ----------------------------------

/** Discover: `src/lib/looks-order.ts`, kept pure so a test drives it. */
export { discoverOrder } from "./looks-order.ts";

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

/** A count as a card shows it: 1.2k from 1,000, 1M from 1,000,000.
 * Rounded down, so 999,999 reads 999.9k and never 1,000k. */
export function shortCount(n: number, lang: string): string {
  if (n < 1000) return new Intl.NumberFormat(lang).format(n);
  const [unit, suffix] = n < 1_000_000 ? [1000, "k"] : [1_000_000, "M"];
  const short = new Intl.NumberFormat(lang, { maximumFractionDigits: 1 })
    .format(Math.floor(n / (unit / 10)) / 10);
  return `${short}${suffix}`;
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
