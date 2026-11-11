// The pages /llms.txt lists and /llms/ serves as raw Markdown
// (#3213). The list is the Starlight sidebar minus its contributor
// group, read from the resolved config, so a page added to the
// sidebar joins without an edit here. Both paths are permanent once
// an agent has cached them (.claude/rules/site.md).
import { getCollection } from "astro:content";
import starlightConfig from "virtual:starlight/user-config";

// Where the raw copies live. One prefix, so `public/_headers` keeps
// them out of search indexes with one rule.
export const LLMS_PREFIX = "/llms/";

// The one sidebar group that is not user documentation.
const CONTRIBUTOR_GROUP = "Contributing";

// The docs collection's files, as the content loader names them.
const DOCS_ROOT = "src/content/docs/docs/";

export interface LlmsPage {
  group: string;
  title: string;
  description: string;
  // Below LLMS_PREFIX, mirroring the repository's `docs/` folder so
  // a page's relative `.md` links reach the other copies.
  path: string;
  body: string;
  bytes: number;
}

interface SidebarGroup {
  label: string;
  slugs: string[];
}

function sidebarGroups(): SidebarGroup[] {
  const groups = (starlightConfig.sidebar ?? []).map((group: any) => {
    if (typeof group?.label !== "string" || !Array.isArray(group.items)) {
      throw new Error(
        "llms: every top-level sidebar entry must be a group of " +
          "pages, so each page has a section in /llms.txt",
      );
    }
    const slugs = group.items.map((item: any) => {
      const slug = typeof item === "string" ? item : item?.slug;
      if (typeof slug !== "string") {
        throw new Error(
          `llms: sidebar group "${group.label}" holds an entry ` +
            "that is not a page slug, which /llms.txt cannot list",
        );
      }
      return slug;
    });
    return { label: group.label, slugs };
  });
  // A renamed group would otherwise publish the contributor pages.
  if (!groups.some((g: SidebarGroup) => g.label === CONTRIBUTOR_GROUP)) {
    throw new Error(
      `llms: the sidebar has no "${CONTRIBUTOR_GROUP}" group; ` +
        "rename CONTRIBUTOR_GROUP with it",
    );
  }
  return groups.filter(
    (g: SidebarGroup) => g.label !== CONTRIBUTOR_GROUP,
  );
}

export async function llmsPages(): Promise<LlmsPage[]> {
  const entries = new Map(
    (await getCollection("docs")).map((entry) => [entry.id, entry]),
  );
  const pages: LlmsPage[] = [];
  for (const group of sidebarGroups()) {
    for (const slug of group.slugs) {
      const entry = entries.get(slug);
      const file = entry?.filePath;
      if (!entry || !file?.startsWith(DOCS_ROOT) || !entry.body) {
        throw new Error(
          `llms: sidebar slug "${slug}" has no Markdown source ` +
            `under ${DOCS_ROOT}`,
        );
      }
      if (!entry.data.description) {
        throw new Error(`llms: "${slug}" has no description`);
      }
      pages.push({
        group: group.label,
        title: entry.data.title,
        description: entry.data.description,
        path: file.slice(DOCS_ROOT.length),
        // Passed through untouched: an `:::unreleased` marker stays
        // literal, and nothing here parses it.
        body: entry.body,
        bytes: Buffer.byteLength(entry.body, "utf8"),
      });
    }
  }
  return pages;
}

export function siteTitle(): string {
  const title = starlightConfig.title;
  return typeof title === "string"
    ? title
    : (title.en ?? Object.values(title)[0]);
}

export function siteDescription(): string {
  return starlightConfig.description ?? "";
}
