#!/usr/bin/env node
// new.mjs — read topics.csv, write skeleton MDX files into content/blog/{locale}/{slug}.mdx
//
// Usage:
//   node scripts/blog/new.mjs [--csv=topics.csv] [--force]

import { readFile, writeFile, mkdir } from "node:fs/promises";
import { existsSync } from "node:fs";
import path from "node:path";
import { argv, exit } from "node:process";
import {
  PROJECT_ROOT,
  parseCSV,
  splitList,
  yamlList,
  fillTemplate,
  LOCALE_LANG,
} from "./lib.mjs";

function parseArgs(args) {
  const out = { csv: "topics.csv", force: false };
  for (const a of args) {
    if (a.startsWith("--csv=")) out.csv = a.slice(6);
    else if (a === "--force") out.force = true;
    else if (a === "--help" || a === "-h") {
      console.log("Usage: node scripts/blog/new.mjs [--csv=topics.csv] [--force]");
      exit(0);
    }
  }
  return out;
}

const REQUIRED_COLS = [
  "slug",
  "locale",
  "title",
  "description",
  "tags",
  "template",
  "key_facts",
];

function validateRow(row, idx) {
  const missing = REQUIRED_COLS.filter((c) => !row[c] || row[c].trim() === "");
  if (missing.length > 0) {
    throw new Error(
      `Row ${idx + 2} (slug=${row.slug || "?"}) missing required columns: ${missing.join(", ")}`,
    );
  }
}

async function main() {
  const args = parseArgs(argv.slice(2));
  const csvPath = path.resolve(PROJECT_ROOT, args.csv);
  if (!existsSync(csvPath)) {
    console.error(`Topics CSV not found: ${csvPath}`);
    exit(1);
  }

  const csvText = await readFile(csvPath, "utf8");
  const rows = parseCSV(csvText);
  if (rows.length === 0) {
    console.error(`No rows in ${csvPath}`);
    exit(1);
  }

  const today = new Date().toISOString().slice(0, 10);
  let created = 0;
  let skipped = 0;

  for (let i = 0; i < rows.length; i++) {
    const row = rows[i];
    validateRow(row, i);

    const tmplPath = path.join(
      PROJECT_ROOT,
      "templates",
      `${row.template}.mdx.tmpl`,
    );
    if (!existsSync(tmplPath)) {
      throw new Error(
        `Template not found: ${tmplPath} (row ${i + 2}, slug=${row.slug})`,
      );
    }
    const tmpl = await readFile(tmplPath, "utf8");

    // key_facts uses `||` as separator (facts often contain inline ASCII `;`).
    // tags and internal_links keep `;` / `；` since they're short single-word values.
    const facts = row.key_facts
      .split(/\s*\|\|\s*/)
      .map((s) => s.trim())
      .filter(Boolean);
    const tags = splitList(row.tags);
    const links = splitList(row.internal_links);

    const targetLength =
      row.locale === "en" ? "1400–2400" : "1200–2000";

    const filled = fillTemplate(tmpl, {
      TITLE: row.title.replace(/"/g, '\\"'),
      DESCRIPTION: row.description.replace(/"/g, '\\"'),
      SLUG: row.slug,
      LOCALE: row.locale,
      LOCALE_LANG: LOCALE_LANG[row.locale] ?? row.locale,
      DATE: row.date && row.date.trim() !== "" ? row.date.trim() : today,
      READ_MIN: row.read_min && row.read_min.trim() !== "" ? row.read_min.trim() : "8",
      TAGS: tags.map((t) => `"${t.replace(/"/g, '\\"')}"`).join(", "),
      KEY_FACTS_YAML: yamlList(facts),
      INTERNAL_LINKS: links.map((l) => `"${l}"`).join(", "),
      TARGET_LENGTH: targetLength,
      COMPETITOR_NAME: row.competitor_name || "macOS Live Text",
    });

    const outDir = path.join(PROJECT_ROOT, "content", "blog", row.locale);
    await mkdir(outDir, { recursive: true });
    const outPath = path.join(outDir, `${row.slug}.mdx`);

    if (existsSync(outPath) && !args.force) {
      console.log(`⊘ skip ${row.locale}/${row.slug}.mdx (already exists; --force to overwrite)`);
      skipped++;
      continue;
    }

    await writeFile(outPath, filled);
    console.log(`✓ ${row.locale}/${row.slug}.mdx`);
    created++;
  }

  console.log(`\nDone: ${created} created, ${skipped} skipped.`);
}

main().catch((e) => {
  console.error(`Error: ${e.message}`);
  if (process.env.DEBUG) console.error(e.stack);
  exit(1);
});
