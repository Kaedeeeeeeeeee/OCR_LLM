#!/usr/bin/env node
// expand.mjs — skeleton MDX → fully-prosed MDX via DeepSeek (thinking disabled).
//
// Usage:
//   node --env-file=.env.local scripts/blog/expand.mjs [--concurrency=N] <file...>
//   node --env-file=.env.local scripts/blog/expand.mjs content/blog/zh/*.mdx

import { readFile, writeFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import { argv, exit, env } from "node:process";
import path from "node:path";
import matter from "gray-matter";
import { loadConfig, loadStyleGuide, LOCALE_LANG } from "./lib.mjs";

function parseArgs(args) {
  const out = { concurrency: 3, dryRun: false, files: [] };
  for (const a of args) {
    if (a.startsWith("--concurrency=")) {
      out.concurrency = Math.max(1, parseInt(a.slice(14), 10));
    } else if (a === "--dry-run") out.dryRun = true;
    else if (a === "--help" || a === "-h") {
      console.log(
        "Usage: node --env-file=.env.local scripts/blog/expand.mjs [--concurrency=N] [--dry-run] <file...>",
      );
      exit(0);
    } else {
      out.files.push(a);
    }
  }
  return out;
}

function buildSystemPrompt(config, styleGuide, locale) {
  const lang = LOCALE_LANG[locale] ?? locale;
  const tone = config.style.tone || "calm, expert, honest about tradeoffs";
  const [minLen, maxLen] = config.style.targetLength;
  const forbidden = config.style.forbiddenPhrases.length
    ? `\n\nFORBIDDEN phrases (must NOT appear in output): ${config.style.forbiddenPhrases.map((p) => `"${p}"`).join(", ")}.`
    : "";

  return `You are filling in a Cheese! OCR blog post outline. The user will paste an MDX file containing complete frontmatter and a body skeleton. Some lines start with the marker \`BULLET:\` — these are fact summaries you must expand into prose. Body text without that marker is final and must NOT be changed.

## Language

Write the body in ${lang}. Tone: ${tone}.

## Your task

Return the FULL FILE (frontmatter + body), with these changes:

1. **Frontmatter \`tldr\` field**: replace the single \`BULLET: ...\` line under the \`tldr: |\` block with 1 paragraph in ${lang} (no bullet marker). Preserve the YAML pipe (|) and indentation. Length: 80–140 English words OR 150–250 zh/ja/ko characters.
2. **Frontmatter \`faqs\`**: for each q/a pair, replace the \`BULLET: ...\` placeholder text after the colon with the actual question or answer in ${lang}. Keep the YAML structure (\`- q: "..."\` and \`    a: "..."\`) and exact indentation. Each answer is 2–4 full sentences. Do NOT use bullet lists inside the answer. Do NOT escape YAML quotes incorrectly — write everything inside the double quotes naturally and escape inner double quotes with \\".
3. **Frontmatter status field**: delete the entire line \`status: draft\`.
4. **Subagent notes block**: delete the entire \`{/* SUBAGENT WRITING NOTES ... */}\` comment block at the top of the body, INCLUDING the leading and trailing whitespace.
5. **Body \`BULLET:\` blocks**: replace each \`BULLET: ...\` line in the body with 2–4 flowing paragraphs in ${lang} that cover the same facts. Do NOT keep the bullet marker. Do NOT keep \`-\` bullet lists EXCEPT inside an explicitly enumerative section (e.g., a feature checklist labeled as such by the surrounding heading) AND in the \`<table>\` rows.
6. **\`BULLET:\` inside an H2/H3 line**: the heading text itself becomes the heading title in ${lang}. Strip the marker. Keep the \`##\` or \`###\` prefix.
7. **\`BULLET:\` inside a table cell**: replace with the actual cell value (a few words). Keep the table structure exactly.
8. **Body length total: ${minLen}–${maxLen} characters in the target language.**
9. **Preserve every internal link \`[text](/path)\`** — if any are present in the skeleton.
10. **Preserve fenced code blocks** verbatim if any.

## Style rules${styleGuide ? "\n\n" + styleGuide : ""}${forbidden}

- Numbers, version names, proper nouns, and stats from the \`key_facts:\` frontmatter list are ground truth. Use only those. Do NOT invent new ones.
- Paragraphs are 1–3 sentences.
- Information density high. Avoid redundant connectives like "moreover", "additionally", "furthermore".
- Use second person.
- Do NOT include any App Store URLs, "Download Cheese! OCR" links, or external download/buy buttons in the body. A CTA section is rendered separately by the template; the body MUST NOT contain its own CTA link.
- Do NOT add any closing call-to-action paragraph that links to the app. End the body on the last informational paragraph.

## Output format (CRITICAL)

Return ONLY the raw MDX file content, starting with \`---\` (frontmatter open) and ending with the last paragraph of the body. NO markdown code fences (\`\`\`mdx etc.) wrapping the output. NO preamble. NO trailing commentary. Anything extra breaks the file. The output is written directly back to disk.`;
}

async function callDeepSeek(config, { system, user }) {
  const apiKey = env[config.llm.apiKeyEnv];
  if (!apiKey) {
    throw new Error(
      `${config.llm.apiKeyEnv} is not set. Add it to .env.local and run with --env-file=.env.local.`,
    );
  }
  const t0 = Date.now();
  const res = await fetch(config.llm.endpoint, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model: config.llm.model,
      messages: [
        { role: "system", content: system },
        { role: "user", content: user },
      ],
      temperature: config.llm.temperature,
      thinking: { type: "disabled" },
      max_tokens: 8192,
    }),
  });
  if (!res.ok) {
    const body = await res.text();
    throw new Error(`DeepSeek ${res.status}: ${body.slice(0, 500)}`);
  }
  const data = await res.json();
  const text = data.choices?.[0]?.message?.content;
  if (!text) {
    throw new Error(`No content in response: ${JSON.stringify(data).slice(0, 300)}`);
  }
  const usage = data.usage ?? {};
  const ms = Date.now() - t0;
  const { inputPerM, outputPerM } = config.llm.pricing;
  const costUSD =
    ((usage.prompt_tokens ?? 0) * inputPerM +
      (usage.completion_tokens ?? 0) * outputPerM) /
    1_000_000;
  return {
    text,
    inputTokens: usage.prompt_tokens,
    outputTokens: usage.completion_tokens,
    ms,
    costUSD,
  };
}

function unwrap(text) {
  let t = text.trim();
  t = t.replace(/^```(?:mdx|markdown|md)?\s*\n/, "");
  t = t.replace(/\n```\s*$/, "");
  return t.trim() + "\n";
}

/**
 * Strip any Mac-App-Store / Cheese! OCR download links the LLM appends to the body
 * despite explicit instructions not to. The CTA card the renderer adds has the
 * correct URL — any URL the LLM produces is hallucinated (DeepSeek consistently
 * generates a fabricated App Store ID).
 *
 * Operates on the full file string (frontmatter + body); only the body section
 * after the second `---` is touched. Preserves frontmatter byte-for-byte to keep
 * gray-matter's date-quote format from being normalized away.
 */
function scrubAppStoreLinksInPlace(fileText) {
  const m = fileText.match(/^---\n[\s\S]*?\n---\n/);
  if (!m) return fileText; // no frontmatter → nothing safe to do
  const front = m[0];
  let body = fileText.slice(front.length);

  body = body.replace(
    /^[ \t]*\[[^\]]*\]\(https?:\/\/apps\.apple\.com\/[^)]+\)\s*$/gm,
    "",
  );
  body = body.replace(
    /\[([^\]]+)\]\(https?:\/\/apps\.apple\.com\/[^)]+\)/g,
    "$1",
  );
  body = body.replace(/https?:\/\/apps\.apple\.com\/\S+/g, "");
  body = body.replace(/\n{3,}/g, "\n\n");
  return front + body.trimEnd() + "\n";
}

async function expandOne(filePath, config, styleGuide) {
  const original = await readFile(filePath, "utf8");
  const parsed = matter(original);
  const locale = parsed.data.locale || "en";
  const systemPrompt = buildSystemPrompt(config, styleGuide, locale);
  const userPrompt = `Here is the outline file. Apply the rules and return the FULL FILE content with all BULLET: markers replaced, status:draft removed, SUBAGENT NOTES block deleted. Output raw file content only — no code fences.\n\n${original}`;

  const result = await callDeepSeek(config, { system: systemPrompt, user: userPrompt });
  const rawCleaned = unwrap(result.text);

  // Sanity: verify it still parses as gray-matter
  try {
    matter(rawCleaned);
  } catch (e) {
    throw new Error(`Output failed to parse as MDX with frontmatter: ${e.message}`);
  }

  // Sanity: BULLET: should not appear
  if (rawCleaned.includes("BULLET:")) {
    throw new Error(`Output still contains BULLET: marker — LLM did not fully expand`);
  }

  // Strip hallucinated App Store URLs from the body without re-serializing
  // frontmatter (gray-matter's stringify normalizes YAML dates to ISO timestamps,
  // which we'd then need to undo).
  const cleaned = scrubAppStoreLinksInPlace(rawCleaned);

  await writeFile(filePath, cleaned);
  return { filePath, chars: cleaned.length, ...result };
}

/** Run a function pool with limited concurrency. */
async function runPool(items, fn, concurrency) {
  const results = [];
  let i = 0;
  const workers = Array.from({ length: Math.min(concurrency, items.length) }, async () => {
    while (true) {
      const idx = i++;
      if (idx >= items.length) return;
      try {
        const r = await fn(items[idx]);
        results.push({ ok: true, ...r });
      } catch (e) {
        results.push({ ok: false, filePath: items[idx], error: e.message });
      }
    }
  });
  await Promise.all(workers);
  return results;
}

async function main() {
  const args = parseArgs(argv.slice(2));
  if (args.files.length === 0) {
    console.error("No files given. Pass MDX paths or a glob (shell-expanded).");
    exit(1);
  }

  const files = args.files.filter((f) => {
    if (!existsSync(f)) {
      console.warn(`⊘ not found: ${f}`);
      return false;
    }
    return true;
  });
  if (files.length === 0) {
    console.error("No valid files.");
    exit(1);
  }

  const config = await loadConfig();
  const styleGuide = await loadStyleGuide();

  if (args.dryRun) {
    console.log(`Would expand ${files.length} file(s):`);
    files.forEach((f) => console.log(`  ${f}`));
    exit(0);
  }

  console.log(
    `Expanding ${files.length} file(s) with ${config.llm.model} (concurrency=${args.concurrency})...`,
  );

  const t0 = Date.now();
  const results = await runPool(files, (f) => expandOne(f, config, styleGuide), args.concurrency);
  const ms = Date.now() - t0;

  let okCount = 0;
  let totalIn = 0;
  let totalOut = 0;
  let totalCost = 0;
  for (const r of results) {
    if (r.ok) {
      okCount++;
      totalIn += r.inputTokens || 0;
      totalOut += r.outputTokens || 0;
      totalCost += r.costUSD || 0;
      console.log(
        `✓ ${path.relative(process.cwd(), r.filePath)}  ${r.chars} chars, ` +
          `${r.inputTokens}→${r.outputTokens} tok, $${(r.costUSD || 0).toFixed(4)}, ${(r.ms / 1000).toFixed(1)}s`,
      );
    } else {
      console.error(`✗ ${path.relative(process.cwd(), r.filePath)}  ${r.error}`);
    }
  }

  console.log(
    `\nDone: ${okCount}/${files.length} ok in ${(ms / 1000).toFixed(1)}s. ` +
      `Tokens ${totalIn}→${totalOut}, total cost $${totalCost.toFixed(4)}.`,
  );
  if (okCount < files.length) exit(1);
}

main().catch((e) => {
  console.error(`Error: ${e.message}`);
  if (process.env.DEBUG) console.error(e.stack);
  exit(1);
});
