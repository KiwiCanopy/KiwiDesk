// Emits /llms/<page>.md: the raw Markdown body of each page
// /llms.txt lists (#3213). `public/_headers` marks the whole prefix
// noindex, so a copy never competes with its /docs/ page.
import type { APIRoute, GetStaticPaths } from "astro";
import { llmsPages } from "../../lib/llms.ts";

export const getStaticPaths: GetStaticPaths = async () =>
  (await llmsPages()).map((page) => ({
    params: { path: page.path },
    props: { body: page.body },
  }));

export const GET: APIRoute = ({ props }) =>
  new Response(props.body, {
    headers: { "Content-Type": "text/markdown; charset=utf-8" },
  });
