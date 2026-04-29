#!/usr/bin/env node
// qa.mjs — validate MDX files for publication.
//
// Checks:
//   - frontmatter required fields present
//   - status: draft is gone
//   - no BULLET: markers leaking through
//   - no SUBAGENT comment block
//   - no forbidden phrases
//   - body length within target range (per locale)
//   - internal_links resolve to existing slugs in same locale
//
// Usage:
//   node scripts/blog/qa.mjs <file...>

import { readFile, readdir } from "node:fs/promises";
import { existsSync } from "node:fs";
import path from "node:path";
import { argv, exit } from "node:process";
import matter from "gray-matter";
import { loadConfig, PROJECT_ROOT } from "./lib.mjs";

function parseArgs(args) {
  return { files: args.filter((a) => !a.startsWith("--")) };
}

const REQUIRED = [
  "title",
  "description",
  "slug",
  "locale",
  "date",
  "tags",
  "category",
  "template",
  "key_facts",
];

function bodyLength(body, locale) {
  // For zh/ja/ko we count characters; for en we count words for fairer length-target.
  const stripped = body
    .replace(/```[\s\S]*?```/g, "")
    .replace(/<[^>]+>/g, "")
    .replace(/\[([^\]]+)\]\([^)]+\)/g, "$1")
    .replace(/\s+/g, " ")
    .trim();
  if (locale === "en") {
    return stripped.split(/\s+/).length;
  }
  return stripped.length;
}

async function getExistingSlugs(locale) {
  const dir = path.join(PROJECT_ROOT, "content", "blog", locale);
  if (!existsSync(dir)) return new Set();
  const files = await readdir(dir);
  return new Set(files.filter((f) => f.endsWith(".mdx")).map((f) => f.replace(/\.mdx$/, "")));
}

async function checkFile(filePath, config) {
  const errors = [];
  const warnings = [];
  const text = await readFile(filePath, "utf8");

  let parsed;
  try {
    parsed = matter(text);
  } catch (e) {
    errors.push(`frontmatter parse error: ${e.message}`);
    return { errors, warnings };
  }
  const { data: fm, content: body } = parsed;

  for (const k of REQUIRED) {
    if (!(k in fm) || fm[k] === "" || fm[k] === null || fm[k] === undefined) {
      errors.push(`missing frontmatter field: ${k}`);
    }
  }

  if (fm.status === "draft") errors.push(`status:draft was not stripped`);
  if (Array.isArray(fm.key_facts) && fm.key_facts.length === 0) {
    errors.push(`key_facts is empty (skill rule: every post must have at least 1 fact)`);
  }

  if (text.includes("BULLET:")) errors.push(`BULLET: marker still present`);
  if (text.includes("SUBAGENT WRITING NOTES")) {
    errors.push(`SUBAGENT WRITING NOTES block was not deleted`);
  }

  const forbidden = config.style.forbiddenPhrases || [];
  for (const phrase of forbidden) {
    const re = new RegExp(phrase.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"), "i");
    if (re.test(body)) {
      errors.push(`forbidden phrase: "${phrase}"`);
    }
  }

  const locale = fm.locale || "en";
  const len = bodyLength(body, locale);
  // Length thresholds: en uses words (config target /5), others use chars
  const [minLen, maxLen] = config.style.targetLength;
  let lengthMin, lengthMax;
  if (locale === "en") {
    lengthMin = Math.round(minLen / 5.5);
    lengthMax = Math.round(maxLen / 4);
  } else {
    lengthMin = Math.round(minLen * 0.8);
    lengthMax = Math.round(maxLen * 1.1);
  }
  if (len < lengthMin) {
    warnings.push(
      `body length ${len} ${locale === "en" ? "words" : "chars"} below target ${lengthMin}`,
    );
  } else if (len > lengthMax) {
    warnings.push(
      `body length ${len} ${locale === "en" ? "words" : "chars"} above target ${lengthMax}`,
    );
  }

  // internal_links — must point to a slug that exists in the same locale's content/blog dir
  // Allow legacy hand-written slugs from docs/ as well.
  if (Array.isArray(fm.internal_links) && fm.internal_links.length > 0) {
    const sameLocaleSlugs = await getExistingSlugs(locale);
    const docsLegacy = await getDocsLegacySlugs(locale);
    for (const link of fm.internal_links) {
      if (!sameLocaleSlugs.has(link) && !docsLegacy.has(link)) {
        warnings.push(`internal_link "${link}" not found in content/blog/${locale}/ or docs/${locale === "en" ? "" : locale + "/"}blog/`);
      }
    }
  }

  // tldr present and not empty
  if (!fm.tldr || String(fm.tldr).trim() === "") {
    errors.push(`frontmatter.tldr is empty`);
  }

  // faqs structure
  if (fm.faqs) {
    if (!Array.isArray(fm.faqs)) {
      errors.push(`frontmatter.faqs must be an array`);
    } else {
      fm.faqs.forEach((faq, i) => {
        if (!faq.q || !faq.a) {
          errors.push(`faqs[${i}] missing q or a`);
        }
      });
    }
  }

  return { errors, warnings, len };
}

async function getDocsLegacySlugs(locale) {
  const dir =
    locale === "en"
      ? path.join(PROJECT_ROOT, "docs", "blog")
      : path.join(PROJECT_ROOT, "docs", locale, "blog");
  if (!existsSync(dir)) return new Set();
  const entries = await readdir(dir, { withFileTypes: true });
  return new Set(
    entries
      .filter((e) => e.isDirectory() && !e.name.startsWith("."))
      .map((e) => e.name),
  );
}

async function main() {
  const args = parseArgs(argv.slice(2));
  if (args.files.length === 0) {
    console.error("No files given. Pass MDX paths.");
    exit(1);
  }
  const config = await loadConfig();

  let totalErrors = 0;
  let totalWarnings = 0;

  for (const f of args.files) {
    if (!existsSync(f)) {
      console.error(`⊘ not found: ${f}`);
      continue;
    }
    const { errors, warnings, len } = await checkFile(f, config);
    const rel = path.relative(process.cwd(), f);
    if (errors.length === 0 && warnings.length === 0) {
      console.log(`✓ ${rel}  (${len ?? "?"} ${rel.includes("/en/") ? "words" : "chars"})`);
    } else {
      console.log(`${errors.length > 0 ? "✗" : "!"} ${rel}`);
      for (const e of errors) console.log(`  ERROR: ${e}`);
      for (const w of warnings) console.log(`  WARN:  ${w}`);
    }
    totalErrors += errors.length;
    totalWarnings += warnings.length;
  }

  console.log(
    `\nQA done: ${totalErrors} error(s), ${totalWarnings} warning(s) across ${args.files.length} file(s).`,
  );
  if (totalErrors > 0) exit(1);
}

main().catch((e) => {
  console.error(`Error: ${e.message}`);
  if (process.env.DEBUG) console.error(e.stack);
  exit(1);
});
