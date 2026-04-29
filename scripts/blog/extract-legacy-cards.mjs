#!/usr/bin/env node
// extract-legacy-cards.mjs — one-time tool: parse the current hand-written
// docs/{locale}/blog/index.html files and emit scripts/blog/legacy-cards.json,
// preserving editorial order, card title, and card description per locale.

import { readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { exit } from "node:process";
import { PROJECT_ROOT } from "./lib.mjs";

const LOCALES = ["en", "zh", "ja", "ko"];

function indexPath(locale) {
  return locale === "en"
    ? path.join(PROJECT_ROOT, "docs", "blog", "index.html")
    : path.join(PROJECT_ROOT, "docs", locale, "blog", "index.html");
}

function decodeEntities(s) {
  return s
    .replace(/&#39;/g, "'")
    .replace(/&quot;/g, '"')
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">");
}

const CARD_RE =
  /<a\s+href="([^"]+)\/"\s+class="blog-card">\s*<span\s+class="blog-card-tag">([^<]+)<\/span>\s*<h2>([\s\S]+?)<\/h2>\s*<p>([\s\S]+?)<\/p>\s*<\/a>/g;

async function extractLocale(locale) {
  const html = await readFile(indexPath(locale), "utf8");
  const cards = [];
  let m;
  let order = 0;
  CARD_RE.lastIndex = 0;
  while ((m = CARD_RE.exec(html))) {
    const [, slug, tag, title, desc] = m;
    cards.push({
      slug,
      order: order++,
      categoryTag: decodeEntities(tag.trim()),
      title: decodeEntities(title.trim()),
      description: decodeEntities(desc.trim()),
    });
  }
  return cards;
}

async function main() {
  const out = {};
  for (const locale of LOCALES) {
    out[locale] = await extractLocale(locale);
    console.log(`${locale}: ${out[locale].length} cards`);
  }
  const outPath = path.join(PROJECT_ROOT, "scripts", "blog", "legacy-cards.json");
  await writeFile(outPath, JSON.stringify(out, null, 2) + "\n");
  console.log(`\n✓ wrote ${path.relative(process.cwd(), outPath)}`);
}

main().catch((e) => {
  console.error(`Error: ${e.message}`);
  exit(1);
});
