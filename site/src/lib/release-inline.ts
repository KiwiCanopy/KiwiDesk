// Inline markdown for release-note text on the changelog page.
//
// One instance, built once per build rather than per render. Raw
// HTML in a release body is shown as text, as `appcast-sync`'s
// `inline()` shows it, so the page and the update window agree.
import { Marked } from "marked";

const escapeHtml = (text: string): string =>
  text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

const release = new Marked({
  renderer: { html: (token) => escapeHtml(token.text) },
});

export const releaseInline = (md: string): string =>
  release.parseInline(md) as string;
