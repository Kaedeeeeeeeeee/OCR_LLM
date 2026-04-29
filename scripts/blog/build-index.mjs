#!/usr/bin/env node
// build-index.mjs — regenerate docs/{locale-prefix}/blog/index.html for all 4 locales.
//
// Source of truth for posts (per locale):
//   1. content/blog/{locale}/*.mdx (new MDX-driven posts)
//   2. docs/{locale-prefix}/blog/<slug>/index.html (legacy hand-written posts)
//
// MDX frontmatter wins on conflict. Sorted by date descending.

import { readFile, writeFile, readdir } from "node:fs/promises";
import { existsSync } from "node:fs";
import path from "node:path";
import { argv, exit } from "node:process";
import { fileURLToPath } from "node:url";
import matter from "gray-matter";

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));
const LEGACY_CARDS_PATH = path.join(SCRIPT_DIR, "legacy-cards.json");
import {
  PROJECT_ROOT,
  SITE_URL,
  CONTACT_EMAIL,
  LOCALE_OG,
  LOCALE_HREFLANG,
  LOCALE_LABEL,
  LOCALE_FOOTER,
} from "./lib.mjs";
import { escapeHtml } from "./render-utils.mjs";

const LOCALES = ["en", "zh", "ja", "ko"];

// Per-locale labels for the index page itself.
const INDEX_COPY = {
  en: {
    htmlLang: "en",
    pageTitle: "Blog — Cheese! OCR | Mac OCR Tutorials, Comparisons, and Deep Dives",
    metaDesc:
      "Practical Mac OCR guides — comparisons, how-tos, and technical deep dives covering PDFs, screenshots, video frames, multi-language text, and Apple Vision.",
    ogTitle: "Cheese! OCR Blog — Mac OCR Tutorials and Comparisons",
    ogDesc: "Practical Mac OCR guides — comparisons, how-tos, and technical deep dives.",
    twitterTitle: "Cheese! OCR Blog",
    twitterDesc: "Practical Mac OCR guides and deep dives.",
    backLinkLabel: "← Cheese! OCR",
    heroH1: "Blog",
    heroLede: "Practical Mac OCR guides — comparisons, how-tos, and the occasional deep dive.",
    cssHref: "article.css",
    favBase: "../",
    homeHref: "../",
    privacyHref: "../privacy.html",
    blogPathSegment: "blog/",
  },
  zh: {
    htmlLang: "zh-Hans",
    pageTitle: "博客 — Cheese! OCR ｜ Mac OCR 教程、对比与技术解析",
    metaDesc:
      "实用的 Mac OCR 文章合集——工具对比、操作教程、技术解析，涵盖 PDF 识别、截图取文、视频文字提取、多语言识别与 Apple Vision 框架。",
    ogTitle: "Cheese! OCR 博客 — Mac OCR 教程与对比",
    ogDesc: "实用的 Mac OCR 文章合集——工具对比、操作教程、技术解析。",
    twitterTitle: "Cheese! OCR 博客",
    twitterDesc: "实用的 Mac OCR 文章合集。",
    backLinkLabel: "← Cheese! OCR",
    heroH1: "博客",
    heroLede: "实用的 Mac OCR 文章——工具对比、操作教程、偶尔来一篇技术解析。",
    cssHref: "../../blog/article.css",
    favBase: "../../",
    homeHref: "../",
    privacyHref: "../../privacy.html",
    blogPathSegment: "zh/blog/",
  },
  ja: {
    htmlLang: "ja",
    pageTitle: "ブログ — Cheese! OCR ｜ Mac OCR チュートリアル・比較・技術解説",
    metaDesc:
      "Mac の OCR に関する実用記事 — ツール比較、ハウツー、技術解説。PDF 認識、スクリーンショット、動画のテキスト抽出、多言語対応、Apple Vision まで。",
    ogTitle: "Cheese! OCR ブログ — Mac OCR のチュートリアルと比較",
    ogDesc: "Mac の OCR に関する実用記事 — ツール比較、ハウツー、技術解説。",
    twitterTitle: "Cheese! OCR ブログ",
    twitterDesc: "Mac の OCR に関する実用記事。",
    backLinkLabel: "← Cheese! OCR",
    heroH1: "ブログ",
    heroLede: "Mac の OCR に関する実用記事 — ツール比較、ハウツー、ときどき技術解説。",
    cssHref: "../../blog/article.css",
    favBase: "../../",
    homeHref: "../",
    privacyHref: "../../privacy.html",
    blogPathSegment: "ja/blog/",
  },
  ko: {
    htmlLang: "ko",
    pageTitle: "블로그 — Cheese! OCR | Mac OCR 가이드, 비교, 심층 분석",
    metaDesc:
      "Mac OCR에 관한 실용 글 모음 — 도구 비교, 가이드, 기술 분석. PDF·스크린샷·영상 텍스트 추출·다국어 인식·Apple Vision까지.",
    ogTitle: "Cheese! OCR 블로그 — Mac OCR 가이드와 비교",
    ogDesc: "Mac OCR에 관한 실용 글 — 도구 비교, 가이드, 기술 분석.",
    twitterTitle: "Cheese! OCR 블로그",
    twitterDesc: "Mac OCR에 관한 실용 글 모음.",
    backLinkLabel: "← Cheese! OCR",
    heroH1: "블로그",
    heroLede: "Mac OCR에 관한 실용 글 — 도구 비교, 가이드, 가끔은 심층 분석까지.",
    cssHref: "../../blog/article.css",
    favBase: "../../",
    homeHref: "../",
    privacyHref: "../../privacy.html",
    blogPathSegment: "ko/blog/",
  },
};

// Translation table: canonical category (from frontmatter) → per-locale display tag.
const CATEGORY_LABEL = {
  en: {
    Comparison: "Comparison",
    "How-to": "How-to",
    Guide: "Guide",
    "Deep Dive": "Deep Dive",
  },
  zh: {
    Comparison: "对比",
    "How-to": "教程",
    Guide: "指南",
    "Deep Dive": "技术解析",
  },
  ja: {
    Comparison: "比較",
    "How-to": "ハウツー",
    Guide: "ガイド",
    "Deep Dive": "技術解説",
  },
  ko: {
    Comparison: "비교",
    "How-to": "가이드",
    Guide: "가이드",
    "Deep Dive": "심층 분석",
  },
};

// Categories of the 7 legacy hand-written posts (canonical / English form).
const LEGACY_CATEGORIES = {
  "cheese-ocr-vs-live-text": "Comparison",
  "how-to-ocr-pdf-on-mac": "How-to",
  "copy-text-from-video-on-mac": "How-to",
  "ocr-asian-languages-on-mac": "Guide",
  "extract-text-from-screenshot-on-mac": "How-to",
  "how-on-device-ocr-works": "Deep Dive",
  "cheese-ocr-vs-text-sniper": "Comparison",
};

function localeBlogDirOnDisk(locale) {
  if (locale === "en") return path.join(PROJECT_ROOT, "docs", "blog");
  return path.join(PROJECT_ROOT, "docs", locale, "blog");
}

async function loadLegacyCards() {
  if (!existsSync(LEGACY_CARDS_PATH)) return {};
  return JSON.parse(await readFile(LEGACY_CARDS_PATH, "utf8"));
}

/**
 * Read all post metadata for a given locale, merging MDX + legacy cards.
 * MDX frontmatter is the source of truth for new posts.
 * Legacy cards (from legacy-cards.json) are the source of truth for hand-written posts —
 * including their editorial card title, blurb, and order. Their underlying article HTML
 * keeps the meta description for SEO; the card blurb is intentionally curated and shorter.
 */
async function collectPosts(locale, legacyCards) {
  const posts = []; // { slug, title, description, date, category, sortKey }
  const seen = new Set();

  // 1) MDX (highest priority)
  const mdxDir = path.join(PROJECT_ROOT, "content", "blog", locale);
  if (existsSync(mdxDir)) {
    const files = await readdir(mdxDir);
    for (const f of files) {
      if (!f.endsWith(".mdx")) continue;
      const slug = f.replace(/\.mdx$/, "");
      const text = await readFile(path.join(mdxDir, f), "utf8");
      const { data: fm } = matter(text);
      posts.push({
        slug,
        title: fm.title,
        description: fm.card_description || fm.description,
        date: fm.date,
        category: fm.category || "Guide",
        // MDX posts get a sortKey starting with their date so newer posts naturally lead.
        sortKey: `0:${fm.date}:${slug}`,
        source: "mdx",
      });
      seen.add(slug);
    }
  }

  // 2) Legacy hand-written posts via legacy-cards.json (preserves editorial order)
  const localeLegacy = legacyCards[locale] || [];
  for (const card of localeLegacy) {
    if (seen.has(card.slug)) continue;
    // Sanity: the directory must exist on disk
    const idxHtml = path.join(localeBlogDirOnDisk(locale), card.slug, "index.html");
    if (!existsSync(idxHtml)) continue;
    posts.push({
      slug: card.slug,
      title: card.title,
      description: card.description,
      categoryTag: card.categoryTag, // already locale-translated
      date: "1900-01-01", // sort below MDX
      // Legacy posts get a sortKey based on their hand-curated order
      sortKey: `1:${String(card.order).padStart(4, "0")}:${card.slug}`,
      source: "legacy",
    });
    seen.add(card.slug);
  }

  // 3) Belt-and-suspenders: any directory in docs/{locale}/blog/ that we didn't find
  // in MDX or legacy-cards.json. Falls back to scraping the HTML.
  const docsDir = localeBlogDirOnDisk(locale);
  if (existsSync(docsDir)) {
    const entries = await readdir(docsDir, { withFileTypes: true });
    for (const e of entries) {
      if (!e.isDirectory() || e.name.startsWith(".")) continue;
      const slug = e.name;
      if (seen.has(slug)) continue;
      const idxHtml = path.join(docsDir, slug, "index.html");
      if (!existsSync(idxHtml)) continue;
      const html = await readFile(idxHtml, "utf8");
      const ogTitle = html.match(/<meta\s+property="og:title"\s+content="([^"]*)"/i);
      const desc = html.match(/<meta\s+name="description"\s+content="([^"]*)"/i);
      const date = html.match(
        /<meta\s+property="article:published_time"\s+content="([^"]*)"/i,
      );
      posts.push({
        slug,
        title: ogTitle ? ogTitle[1] : slug,
        description: desc ? desc[1] : "",
        date: date ? date[1] : "1900-01-01",
        category: "Guide",
        sortKey: `2:${date ? date[1] : "1900-01-01"}:${slug}`,
        source: "scrape",
      });
    }
  }

  posts.sort((a, b) => a.sortKey.localeCompare(b.sortKey));
  return posts;
}

function renderCard(post, locale) {
  const tag =
    post.categoryTag ||
    CATEGORY_LABEL[locale][post.category] ||
    post.category;
  return `        <a href="${post.slug}/" class="blog-card">
            <span class="blog-card-tag">${escapeHtml(tag)}</span>
            <h2>${escapeHtml(post.title)}</h2>
            <p>${escapeHtml(post.description)}</p>
        </a>`;
}

function renderLangSwitcher(currentLocale) {
  return LOCALES.map((l) => {
    const href = l === "en" ? "/OCR_LLM/blog/" : `/OCR_LLM/${l}/blog/`;
    const ariaCurrent = l === currentLocale ? ' aria-current="page"' : "";
    return `            <a href="${href}"${ariaCurrent} hreflang="${LOCALE_HREFLANG[l]}">${LOCALE_LABEL[l]}</a>`;
  }).join("\n");
}

function renderHreflang() {
  const lines = LOCALES.map((l) => {
    const href = l === "en" ? `${SITE_URL}/blog/` : `${SITE_URL}/${l}/blog/`;
    return `    <link rel="alternate" hreflang="${LOCALE_HREFLANG[l]}" href="${href}">`;
  });
  lines.push(`    <link rel="alternate" hreflang="x-default" href="${SITE_URL}/blog/">`);
  return lines.join("\n");
}

async function buildIndex(locale, legacyCards) {
  const c = INDEX_COPY[locale];
  const posts = await collectPosts(locale, legacyCards);
  const cards = posts.map((p) => renderCard(p, locale)).join("\n\n");
  const canonical =
    locale === "en" ? `${SITE_URL}/blog/` : `${SITE_URL}/${locale}/blog/`;
  const f = LOCALE_FOOTER[locale];

  const html = `<!DOCTYPE html>
<html lang="${c.htmlLang}">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="color-scheme" content="light dark">
    <meta name="theme-color" content="#ffffff" media="(prefers-color-scheme: light)">
    <meta name="theme-color" content="#141416" media="(prefers-color-scheme: dark)">

    <title>${escapeHtml(c.pageTitle)}</title>
    <meta name="description" content="${escapeHtml(c.metaDesc)}">

    <link rel="canonical" href="${canonical}">
${renderHreflang()}

    <link rel="icon" type="image/svg+xml" href="${c.favBase}favicon.svg?v=3">
    <link rel="icon" type="image/png" sizes="32x32" href="${c.favBase}favicon-32.png">
    <link rel="apple-touch-icon" sizes="180x180" href="${c.favBase}apple-touch-icon.png">

    <link rel="stylesheet" href="${c.cssHref}">

    <meta property="og:type" content="website">
    <meta property="og:site_name" content="Cheese! OCR">
    <meta property="og:title" content="${escapeHtml(c.ogTitle)}">
    <meta property="og:description" content="${escapeHtml(c.ogDesc)}">
    <meta property="og:url" content="${canonical}">
    <meta property="og:image" content="${SITE_URL}/og-image.png">
    <meta property="og:locale" content="${LOCALE_OG[locale]}">

    <meta name="twitter:card" content="summary_large_image">
    <meta name="twitter:title" content="${escapeHtml(c.twitterTitle)}">
    <meta name="twitter:description" content="${escapeHtml(c.twitterDesc)}">
    <meta name="twitter:image" content="${SITE_URL}/og-image.png">
</head>
<body>

    <nav class="article-nav">
        <a href="${c.homeHref}" class="back-link">${escapeHtml(c.backLinkLabel)}</a>
        <div class="lang-switcher">
${renderLangSwitcher(locale)}
        </div>
    </nav>

    <header class="blog-hero">
        <h1>${escapeHtml(c.heroH1)}</h1>
        <p>${escapeHtml(c.heroLede)}</p>
    </header>

    <main class="blog-list">
${cards}
    </main>

    <footer class="article-footer">
        <a href="${c.homeHref}">${escapeHtml(f.home)}</a>
        <a href="${c.privacyHref}">${escapeHtml(f.privacy)}</a>
        <a href="mailto:${CONTACT_EMAIL}">${escapeHtml(f.contact)}</a>
        <p>${f.copyright}</p>
    </footer>

</body>
</html>
`;

  const outPath = path.join(localeBlogDirOnDisk(locale), "index.html");
  await writeFile(outPath, html);
  return { locale, outPath, postCount: posts.length };
}

async function main() {
  const onlyLocale = argv.slice(2).find((a) => a.startsWith("--locale="))?.slice(9);
  const locales = onlyLocale ? [onlyLocale] : LOCALES;
  const legacyCards = await loadLegacyCards();
  for (const l of locales) {
    if (!LOCALES.includes(l)) {
      console.error(`Unknown locale: ${l}`);
      exit(1);
    }
    const r = await buildIndex(l, legacyCards);
    console.log(`✓ ${path.relative(process.cwd(), r.outPath)}  (${r.postCount} posts)`);
  }
}

main().catch((e) => {
  console.error(`Error: ${e.message}`);
  if (process.env.DEBUG) console.error(e.stack);
  exit(1);
});
