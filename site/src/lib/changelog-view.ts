// What the changelog page draws for a release's notes (#1542),
// kept out of the template so `site/test-changelog.mjs` can hold
// it: the corpus has no typed release before 2.0.0, and a check
// over the built pages alone passes for having looked at nothing.
//
// The page branches on each section's `type`, which
// `scripts/changelog-sync` writes; the title is only displayed.
import { Marked } from "marked";

export interface Section {
  title: string;
  items: string[];
  type?: string;
}

export interface SectionView {
  title: string;
  // " · N" on a typed section; null on a release before 2.0.0.
  count: number | null;
  // The scripting section starts closed, as in the update window.
  folded: boolean;
  items: string[];
}

const escapeHtml = (text: string): string =>
  text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

// Raw HTML in a body is shown as text, as `appcast-sync`'s
// `inline()` shows it, so the page and the update window agree.
const release = new Marked({
  renderer: { html: (token) => escapeHtml(token.text) },
});

export const releaseInline = (md: string): string =>
  release.parseInline(md) as string;

export const sectionView = (section: Section): SectionView => ({
  title: section.title,
  count: section.type ? section.items.length : null,
  folded: section.type === "scripting",
  items: section.items.map(releaseInline),
});
