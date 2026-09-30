// Drives src/lib/roadmap.ts, the one parser of ROADMAP.md's
// "Next on my list" section (#1813), over fixtures and over the
// real file. Run by site.yml; `node site/test-roadmap.mjs` locally.

import { readFileSync } from "node:fs";
import { parseRoadmap } from "./src/lib/roadmap.ts";

const failures = [];
let ran = 0;
const today = new Date(Date.UTC(2026, 8, 30));

function check(name, run) {
  ran += 1;
  try {
    run();
  } catch (error) {
    failures.push(`${name}: ${error.message}`);
  }
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

const doc = (...section) =>
  ["# Roadmap", "", "Intro.", "", "## Next on my list", "", ...section]
    .join("\n");

function refuses(name, markdown, needle) {
  check(`refuses ${name}`, () => {
    let message = null;
    try {
      parseRoadmap(markdown, today);
    } catch (error) {
      message = error.message;
    }
    assert(message !== null, "parsed without complaint");
    assert(message.includes(needle), `said: ${message}`);
  });
}

check("reads the date and the items", () => {
  const list = parseRoadmap(
    doc("_As of 2026-09-28_", "", "- One", "- Two"),
    today,
  );
  assert(list.format === 1, `format ${list.format}`);
  assert(list.as_of === "2026-09-28", `as_of ${list.as_of}`);
  assert(list.items.join("|") === "One|Two", list.items.join("|"));
});

check("takes the date plain, in italics or starred", () => {
  for (const line of [
    "As of 2026-09-28",
    "_As of 2026-09-28_",
    "*As of 2026-09-28*",
  ]) {
    const list = parseRoadmap(doc(line, "- One"), today);
    assert(list.as_of === "2026-09-28", `${line} → ${list.as_of}`);
  }
});

check("the section ends at the next heading", () => {
  const list = parseRoadmap(
    doc("As of 2026-09-28", "- One", "", "## Later", "", "- Not this"),
    today,
  );
  assert(list.items.length === 1, list.items.join("|"));
});

check("a file with no such section lists nothing", () => {
  const list = parseRoadmap("# Roadmap\n\n## Later\n\n- Idea\n", today);
  assert(list.items.length === 0, list.items.join("|"));
  assert(!("as_of" in list), `as_of ${list.as_of}`);
});

check("a date a day ahead passes, for a writer east of UTC", () => {
  const list = parseRoadmap(doc("As of 2026-10-01", "- One"), today);
  assert(list.as_of === "2026-10-01", `as_of ${list.as_of}`);
});

refuses("a missing date", doc("- One"), "no \"As of");
refuses("a date after the items", doc("- One", "As of 2026-09-28"),
  "comes before the items");
refuses("a second date",
  doc("As of 2026-09-28", "As of 2026-09-29", "- One"),
  "a second \"As of\"");
refuses("a date that does not exist",
  doc("As of 2026-02-30", "- One"), "is not a date");
refuses("a date further ahead than a day",
  doc("As of 2026-10-02", "- One"), "is in the future");
refuses("an empty list", doc("As of 2026-09-28"), "no items");
refuses("four items",
  doc("As of 2026-09-28", "- A", "- B", "- C", "- D"), "at most 3");
refuses("an issue number", doc("As of 2026-09-28", "- Fix #123"),
  "no issue numbers");
refuses("a paragraph", doc("As of 2026-09-28", "Some prose.", "- One"),
  "belong here");
refuses("a continued item",
  doc("As of 2026-09-28", "- One", "  and more"), "belong here");
refuses("a subheading", doc("As of 2026-09-28", "### Soon", "- One"),
  "belong here");
refuses("the section twice",
  `${doc("As of 2026-09-28", "- One")}\n## Next on my list\n`,
  "appears 2 times");

// The real file, which is what the build and the app read.
check("ROADMAP.md itself parses", () => {
  const source = readFileSync(
    new URL("../ROADMAP.md", import.meta.url),
    "utf8",
  );
  parseRoadmap(source);
});

if (failures.length) {
  console.error(`test-roadmap: ${failures.length} of ${ran} failed`);
  for (const failure of failures) console.error(`  - ${failure}`);
  process.exit(1);
}
console.log(`test-roadmap: ${ran} check(s) passed`);
