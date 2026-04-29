#!/usr/bin/env node
// build-sitemap.mjs — regenerate docs/sitemap.xml from current site state.
//
// Sources scanned per locale:
//   - landing pages: docs/{locale}/index.html (en is at docs/index.html)
//   - blog index pages: docs/{locale}/blog/index.html (en at docs/blog/index.html)
//   - posts: union of content/blog/{locale}/*.mdx + docs/{locale}/blog/*/index.html
//   - privacy.html (en only, x-default)

import { writeFile, readdir, readFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { exit } from "node:process";
import matter from "gray-matter";
import {
  PROJECT_ROOT,
  SITE_URL,
  LOCALE_HREFLANG,
} from "./lib.mjs";

const LOCALES = ["en", "zh", "ja", "ko"];
const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));
const LEGACY_CARDS_PATH = path.join(SCRIPT_DIR, "legacy-cards.json");

function landingUrl(locale) {
  return locale === "en" ? `${SITE_URL}/` : `${SITE_URL}/${locale}/`;
}

function blogIndexUrl(locale) {
  return locale === "en" ? `${SITE_URL}/blog/` : `${SITE_URL}/${locale}/blog/`;
}

function postUrl(locale, slug) {
  return locale === "en"
    ? `${SITE_URL}/blog/${slug}/`
    : `${SITE_URL}/${locale}/blog/${slug}/`;
}

/** Return the set of locales where a given page (path-builder fn) exists on disk. */
function existingLocales(diskPathFn) {
  return LOCALES.filter((l) => existsSync(diskPathFn(l)));
}

function landingDiskPath(locale) {
  return locale === "en"
    ? path.join(PROJECT_ROOT, "docs", "index.html")
    : path.join(PROJECT_ROOT, "docs", locale, "index.html");
}

function blogIndexDiskPath(locale) {
  return locale === "en"
    ? path.join(PROJECT_ROOT, "docs", "blog", "index.html")
    : path.join(PROJECT_ROOT, "docs", locale, "blog", "index.html");
}

function postDiskPath(locale, slug) {
  return locale === "en"
    ? path.join(PROJECT_ROOT, "docs", "blog", slug, "index.html")
    : path.join(PROJECT_ROOT, "docs", locale, "blog", slug, "index.html");
}

/**
 * Return ordered post slugs.
 * Order: new MDX-driven posts first (sorted by date desc), then legacy posts in
 * the editorial order recorded in legacy-cards.json.
 */
async function collectPostSlugs() {
  const seen = new Set();
  const ordered = [];

  // 1) MDX-driven posts (any locale), sorted by date desc.
  const mdxPosts = []; // { slug, date }
  for (const locale of LOCALES) {
    const mdxDir = path.join(PROJECT_ROOT, "content", "blog", locale);
    if (!existsSync(mdxDir)) continue;
    const files = await readdir(mdxDir);
    for (const f of files) {
      if (!f.endsWith(".mdx")) continue;
      const slug = f.replace(/\.mdx$/, "");
      if (mdxPosts.some((p) => p.slug === slug)) continue;
      const text = await readFile(path.join(mdxDir, f), "utf8");
      const { data: fm } = matter(text);
      mdxPosts.push({ slug, date: fm.date || "1900-01-01" });
    }
  }
  mdxPosts.sort((a, b) => (a.date < b.date ? 1 : a.date > b.date ? -1 : 0));
  for (const p of mdxPosts) {
    if (seen.has(p.slug)) continue;
    ordered.push(p.slug);
    seen.add(p.slug);
  }

  // 2) Legacy posts in editorial order (from legacy-cards.json, en locale).
  if (existsSync(LEGACY_CARDS_PATH)) {
    const legacy = JSON.parse(await readFile(LEGACY_CARDS_PATH, "utf8"));
    for (const card of legacy.en || []) {
      if (seen.has(card.slug)) continue;
      ordered.push(card.slug);
      seen.add(card.slug);
    }
  }

  // 3) Belt-and-suspenders: any post directories not yet captured.
  for (const locale of LOCALES) {
    const docsDir =
      locale === "en"
        ? path.join(PROJECT_ROOT, "docs", "blog")
        : path.join(PROJECT_ROOT, "docs", locale, "blog");
    if (!existsSync(docsDir)) continue;
    const entries = await readdir(docsDir, { withFileTypes: true });
    for (const e of entries) {
      if (
        e.isDirectory() &&
        !e.name.startsWith(".") &&
        !seen.has(e.name) &&
        existsSync(path.join(docsDir, e.name, "index.html"))
      ) {
        ordered.push(e.name);
        seen.add(e.name);
      }
    }
  }

  return ordered;
}

function urlBlock(loc, hreflangPairs, priority, changefreq = "monthly") {
  const lines = [`  <url>`, `    <loc>${loc}</loc>`];
  for (const { locale, url } of hreflangPairs) {
    lines.push(
      `    <xhtml:link rel="alternate" hreflang="${LOCALE_HREFLANG[locale]}" href="${url}"/>`,
    );
  }
  // x-default → en URL if available, otherwise first
  const xDefault =
    hreflangPairs.find((p) => p.locale === "en")?.url ||
    hreflangPairs[0]?.url ||
    loc;
  lines.push(`    <xhtml:link rel="alternate" hreflang="x-default" href="${xDefault}"/>`);
  lines.push(`    <changefreq>${changefreq}</changefreq>`);
  lines.push(`    <priority>${priority}</priority>`);
  lines.push(`  </url>`);
  return lines.join("\n");
}

async function main() {
  const blocks = [];

  // 1) Landing pages
  const landingExisting = existingLocales(landingDiskPath);
  for (const locale of landingExisting) {
    const pairs = landingExisting.map((l) => ({ locale: l, url: landingUrl(l) }));
    blocks.push(urlBlock(landingUrl(locale), pairs, "1.0"));
  }

  // 2) Blog index pages
  const blogIndexExisting = existingLocales(blogIndexDiskPath);
  for (const locale of blogIndexExisting) {
    const pairs = blogIndexExisting.map((l) => ({
      locale: l,
      url: blogIndexUrl(l),
    }));
    blocks.push(urlBlock(blogIndexUrl(locale), pairs, "0.7"));
  }

  // 3) Posts (in editorial order)
  const slugs = await collectPostSlugs();
  for (const slug of slugs) {
    const slugLocales = LOCALES.filter((l) => existsSync(postDiskPath(l, slug)));
    if (slugLocales.length === 0) continue;
    const pairs = slugLocales.map((l) => ({ locale: l, url: postUrl(l, slug) }));
    for (const locale of slugLocales) {
      blocks.push(urlBlock(postUrl(locale, slug), pairs, "0.8"));
    }
  }

  // 4) privacy.html (en, no hreflang alternates because it's only in en)
  if (existsSync(path.join(PROJECT_ROOT, "docs", "privacy.html"))) {
    const url = `${SITE_URL}/privacy.html`;
    blocks.push(
      `  <url>\n    <loc>${url}</loc>\n    <changefreq>yearly</changefreq>\n    <priority>0.3</priority>\n  </url>`,
    );
  }

  const xml = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"
        xmlns:xhtml="http://www.w3.org/1999/xhtml">
${blocks.join("\n")}
</urlset>
`;

  const outPath = path.join(PROJECT_ROOT, "docs", "sitemap.xml");
  await writeFile(outPath, xml);
  const totalUrls = (xml.match(/<loc>/g) || []).length;
  console.log(
    `✓ ${path.relative(process.cwd(), outPath)}  (${totalUrls} URLs)`,
  );
}

main().catch((e) => {
  console.error(`Error: ${e.message}`);
  if (process.env.DEBUG) console.error(e.stack);
  exit(1);
});
