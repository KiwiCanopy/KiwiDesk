// ROADMAP.md's "Next on my list" section as the JSON the What's
// new window reads (#1813). The one parser of that section: the
// build refuses a malformed one, so a typo fails the pull request
// that made it instead of hiding the list in every installed copy.
// `site/test-roadmap.mjs` holds each clause.

export const FORMAT = 1;
export const HEADING = "## Next on my list";
export const MAX_ITEMS = 3;

export interface NextOnMyList {
  format: number;
  // Absent when ROADMAP.md has no such section.
  as_of?: string;
  items: string[];
}

const DATE = /^([_*]?)As of (\d{4})-(\d{2})-(\d{2})\1$/;
const BULLET = /^[-*] (\S.*)$/;
// The release-notes rule: a reader has no referent for an issue
// number (docs/design-decisions.md ▸ Release notes).
const ISSUE = /(^|[^\w&])#\d+\b/;
const DAY = 86_400_000;

function isoDate(
  match: RegExpMatchArray,
  today: Date,
): string | string[] {
  const [, , y, m, d] = match;
  const date = new Date(Date.UTC(+y, +m - 1, +d));
  const iso = `${y}-${m}-${d}`;
  if (date.toISOString().slice(0, 10) !== iso) {
    return [`"${iso}" is not a date`];
  }
  // A day of slack for a date written ahead of UTC.
  if (date.getTime() > today.getTime() + DAY) {
    return [`"${iso}" is in the future`];
  }
  return iso;
}

export function parseRoadmap(
  markdown: string,
  today: Date = new Date(),
): NextOnMyList {
  const lines = markdown.split(/\r?\n/).map((line) => line.trimEnd());
  const starts = lines.flatMap((line, i) => (line === HEADING ? [i] : []));
  if (starts.length === 0) return { format: FORMAT, items: [] };

  const problems: string[] = [];
  if (starts.length > 1) {
    problems.push(`"${HEADING}" appears ${starts.length} times`);
  }
  let asOf: string | undefined;
  const items: string[] = [];
  for (let i = starts[0] + 1; i < lines.length; i++) {
    const line = lines[i];
    const at = `line ${i + 1}`;
    if (/^#{1,2} /.test(line)) break;
    if (line === "") continue;
    const date = line.match(DATE);
    const bullet = line.match(BULLET);
    if (date) {
      if (asOf !== undefined) {
        problems.push(`${at}: a second "As of" line`);
      } else if (items.length > 0) {
        problems.push(`${at}: "As of" comes before the items`);
      } else {
        const parsed = isoDate(date, today);
        if (typeof parsed === "string") asOf = parsed;
        else problems.push(...parsed.map((p) => `${at}: ${p}`));
      }
    } else if (bullet) {
      const item = bullet[1];
      if (ISSUE.test(item)) {
        problems.push(`${at}: no issue numbers in an item`);
      }
      items.push(item);
    } else {
      problems.push(
        `${at}: only an "As of YYYY-MM-DD" line and one-line ` +
          `"- " items belong here, not: ${line}`,
      );
    }
  }
  if (asOf === undefined) {
    problems.push(`no "As of YYYY-MM-DD" line under "${HEADING}"`);
  }
  if (items.length === 0) {
    problems.push(`no items under "${HEADING}"`);
  } else if (items.length > MAX_ITEMS) {
    problems.push(`${items.length} items; at most ${MAX_ITEMS}`);
  }
  if (problems.length > 0) {
    throw new Error(`ROADMAP.md: ${problems.join("; ")}`);
  }
  return { format: FORMAT, as_of: asOf, items };
}
