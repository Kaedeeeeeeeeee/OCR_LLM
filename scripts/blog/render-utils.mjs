// MDX → HTML rendering primitives for build-blog.mjs.

import { unified } from "unified";
import remarkParse from "remark-parse";
import remarkGfm from "remark-gfm";
import remarkRehype from "remark-rehype";
import rehypeSlug from "rehype-slug";
import rehypeStringify from "rehype-stringify";

// LLM-produced bodies are pure GFM markdown — no inline HTML — so we skip
// `rehype-raw` / `allowDangerousHtml`. Including them caused remark-rehype
// to emit blank-line noise around tables.
const processor = unified()
  .use(remarkParse)
  .use(remarkGfm)
  .use(remarkRehype)
  .use(rehypeSlug)
  .use(rehypeStringify);

/** Render markdown body to HTML. Strips any leading frontmatter remnants. */
export async function markdownToHtml(md) {
  const file = await processor.process(md);
  return String(file);
}

/**
 * HTML escape for text-nodes and attribute values.
 * Apostrophes are intentionally NOT escaped — the existing site uses raw `'`
 * inside text, attributes are double-quoted, and skipping `&#39;` keeps
 * regenerated diffs clean.
 */
export function escapeHtml(s) {
  return String(s)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

/** JSON-LD safe: escape '<', '>', '&' but not quotes (kept inside JSON). */
export function jsonLdEscape(obj) {
  return JSON.stringify(obj, null, 2)
    .replace(/</g, "\\u003c")
    .replace(/>/g, "\\u003e")
    .replace(/&/g, "\\u0026");
}

/**
 * Normalize a date value (Date | string) to "YYYY-MM-DD".
 * gray-matter auto-parses YAML dates into JS Date objects; we want plain ISO date strings.
 */
export function isoDate(d) {
  if (!d) return "";
  if (d instanceof Date) {
    const y = d.getUTCFullYear();
    const m = String(d.getUTCMonth() + 1).padStart(2, "0");
    const day = String(d.getUTCDate()).padStart(2, "0");
    return `${y}-${m}-${day}`;
  }
  const s = String(d).trim();
  // Trim time component if present
  const m = s.match(/^(\d{4}-\d{2}-\d{2})/);
  return m ? m[1] : s;
}

/** Strip markdown to plain text (for FAQ JSON-LD answers etc). */
export function stripMarkdown(s) {
  return String(s)
    .replace(/```[\s\S]*?```/g, "")
    .replace(/`([^`]+)`/g, "$1")
    .replace(/\*\*([^*]+)\*\*/g, "$1")
    .replace(/\*([^*]+)\*/g, "$1")
    .replace(/\[([^\]]+)\]\([^)]+\)/g, "$1")
    .replace(/\s+/g, " ")
    .trim();
}
