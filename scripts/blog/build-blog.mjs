#!/usr/bin/env node
// build-blog.mjs — render MDX posts in content/blog/{locale}/*.mdx to docs/.../blog/{slug}/index.html
//
// Output paths:
//   en  → docs/blog/{slug}/index.html
//   zh  → docs/zh/blog/{slug}/index.html
//   ja  → docs/ja/blog/{slug}/index.html
//   ko  → docs/ko/blog/{slug}/index.html
//
// Each post emits:
//   - full <head> with canonical + 4 hreflang + favicons + OG/Twitter + 3 JSON-LD blocks
//   - lang switcher nav, header (title + meta), TL;DR aside, body, FAQ section, CTA, related grid
//
// Usage:
//   node scripts/blog/build-blog.mjs [--only=<slug>] [--locale=<locale>]

import { readFile, writeFile, mkdir, readdir } from "node:fs/promises";
import { existsSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { argv, exit } from "node:process";
import matter from "gray-matter";

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));
const LEGACY_CARDS_PATH = path.join(SCRIPT_DIR, "legacy-cards.json");
import {
  PROJECT_ROOT,
  SITE_URL,
  APP_STORE_URL,
  CONTACT_EMAIL,
  LOCALE_OG,
  LOCALE_HREFLANG,
  LOCALE_LABEL,
  LOCALE_DATE_FORMAT,
  LOCALE_READ_MIN_LABEL,
  LOCALE_BACK_TO_BLOG,
  LOCALE_TLDR,
  LOCALE_FAQ_HEADING,
  LOCALE_RELATED_HEADING,
  LOCALE_CTA,
  LOCALE_FOOTER,
} from "./lib.mjs";
import {
  markdownToHtml,
  escapeHtml,
  jsonLdEscape,
  stripMarkdown,
  isoDate,
} from "./render-utils.mjs";

const LOCALES = ["en", "zh", "ja", "ko"];

function parseArgs(args) {
  const out = { only: null, locale: null };
  for (const a of args) {
    if (a.startsWith("--only=")) out.only = a.slice(7);
    else if (a.startsWith("--locale=")) out.locale = a.slice(9);
  }
  return out;
}

/** Path on disk where the rendered HTML goes for a given locale+slug. */
function htmlOutPath(locale, slug) {
  if (locale === "en") {
    return path.join(PROJECT_ROOT, "docs", "blog", slug, "index.html");
  }
  return path.join(PROJECT_ROOT, "docs", locale, "blog", slug, "index.html");
}

/** Public URL for a given locale+slug. */
function postUrl(locale, slug) {
  if (locale === "en") return `${SITE_URL}/blog/${slug}/`;
  return `${SITE_URL}/${locale}/blog/${slug}/`;
}

/** Public site-relative URL (used in the lang-switcher) — must include base path. */
function postSiteRelUrl(locale, slug) {
  if (locale === "en") return `/OCR_LLM/blog/${slug}/`;
  return `/OCR_LLM/${locale}/blog/${slug}/`;
}

/** Where the post directory lives on disk. */
function postOutDir(locale, slug) {
  return path.dirname(htmlOutPath(locale, slug));
}

/** Relative URL to article.css from inside a given output dir. */
function articleCssHref(locale) {
  // en posts: docs/blog/<slug>/  →  ../article.css
  // zh/ja/ko posts: docs/<locale>/blog/<slug>/  →  ../../../blog/article.css
  if (locale === "en") return "../article.css";
  return "../../../blog/article.css";
}

/** Relative URL to a sibling slug's directory (used for related grid + back-link). */
function relativeSiblingHref(slug) {
  return `../${slug}/`;
}

function backToBlogHref() {
  return "../";
}

function homeHref(locale) {
  if (locale === "en") return "../../";
  return "../../";
}

function privacyHref(locale) {
  // Privacy page lives at docs/privacy.html (en only). All locales link to same canonical.
  if (locale === "en") return "../../privacy.html";
  return "../../../privacy.html";
}

function faviconBase(locale) {
  // From docs/blog/<slug>/  →  ../../  is docs/
  // From docs/<locale>/blog/<slug>/  →  ../../../  is docs/
  if (locale === "en") return "../../";
  return "../../../";
}

/**
 * Build a slug→{title, description} index per locale, used to render related-article
 * cards. Resolution order:
 *   1) MDX frontmatter for new posts
 *   2) legacy-cards.json (curated card title + blurb, locale-specific)
 *   3) Belt-and-suspenders: scrape <title> + <meta description> from docs/.../index.html
 */
async function buildSlugIndex() {
  const idx = {};

  // Load legacy cards once
  let legacyCards = {};
  if (existsSync(LEGACY_CARDS_PATH)) {
    legacyCards = JSON.parse(await readFile(LEGACY_CARDS_PATH, "utf8"));
  }

  for (const locale of LOCALES) {
    idx[locale] = {};

    // 1) MDX
    const mdxDir = path.join(PROJECT_ROOT, "content", "blog", locale);
    if (existsSync(mdxDir)) {
      const files = await readdir(mdxDir);
      for (const f of files) {
        if (!f.endsWith(".mdx")) continue;
        const slug = f.replace(/\.mdx$/, "");
        const text = await readFile(path.join(mdxDir, f), "utf8");
        const fm = matter(text).data;
        idx[locale][slug] = {
          title: fm.title || slug,
          description: fm.card_description || fm.description || "",
        };
      }
    }

    // 2) legacy-cards.json (curated card copy)
    for (const card of legacyCards[locale] || []) {
      if (idx[locale][card.slug]) continue;
      idx[locale][card.slug] = {
        title: card.title,
        description: card.description,
      };
    }

    // 3) Fallback: scrape any remaining post directories
    const docsDir =
      locale === "en"
        ? path.join(PROJECT_ROOT, "docs", "blog")
        : path.join(PROJECT_ROOT, "docs", locale, "blog");
    if (existsSync(docsDir)) {
      const entries = await readdir(docsDir, { withFileTypes: true });
      for (const e of entries) {
        if (!e.isDirectory() || e.name.startsWith(".")) continue;
        const slug = e.name;
        if (idx[locale][slug]) continue;
        const idxHtml = path.join(docsDir, slug, "index.html");
        if (!existsSync(idxHtml)) continue;
        const html = await readFile(idxHtml, "utf8");
        const titleMatch = html.match(/<title>([^<]*)<\/title>/);
        const descMatch = html.match(
          /<meta\s+name="description"\s+content="([^"]*)"/i,
        );
        idx[locale][slug] = {
          title: titleMatch
            ? titleMatch[1]
                .replace(/\s*[—–-]\s*Cheese!?\s*OCR\s*(Blog|博客|ブログ|블로그)?.*$/i, "")
                .trim()
            : slug,
          description: descMatch ? descMatch[1] : "",
        };
      }
    }
  }
  return idx;
}

/** Resolve hreflang set for a given slug — only include locales where the slug actually exists. */
function hreflangSet(slug, slugIndex) {
  const result = [];
  for (const locale of LOCALES) {
    if (slugIndex[locale]?.[slug]) {
      result.push({ locale, url: postUrl(locale, slug) });
    }
  }
  return result;
}

/** Build the full <head> for a post. */
function renderHead({ fm, locale, slug, url, slugIndex }) {
  const ogLocale = LOCALE_OG[locale];
  const hreflangs = hreflangSet(slug, slugIndex);
  const xDefaultUrl =
    hreflangs.find((h) => h.locale === "en")?.url || hreflangs[0]?.url || url;

  const hreflangLinks = hreflangs
    .map(
      (h) =>
        `    <link rel="alternate" hreflang="${LOCALE_HREFLANG[h.locale]}" href="${escapeHtml(h.url)}">`,
    )
    .join("\n");

  // Article JSON-LD
  const articleLd = {
    "@context": "https://schema.org",
    "@type": "Article",
    headline: fm.title,
    description: fm.description,
    author: {
      "@type": "Organization",
      name: "Cheese! OCR",
      url: SITE_URL + "/",
    },
    publisher: {
      "@type": "Organization",
      name: "Cheese! OCR",
      url: SITE_URL + "/",
    },
    datePublished: fm.date,
    dateModified: fm.date,
    image: SITE_URL + "/og-image.png",
    url,
    inLanguage: LOCALE_HREFLANG[locale],
    mainEntityOfPage: { "@type": "WebPage", "@id": url },
  };

  // FAQ JSON-LD
  let faqLd = "";
  if (Array.isArray(fm.faqs) && fm.faqs.length > 0) {
    const ld = {
      "@context": "https://schema.org",
      "@type": "FAQPage",
      inLanguage: LOCALE_HREFLANG[locale],
      mainEntity: fm.faqs.map((f) => ({
        "@type": "Question",
        name: stripMarkdown(f.q),
        acceptedAnswer: {
          "@type": "Answer",
          text: stripMarkdown(f.a),
        },
      })),
    };
    faqLd = `\n    <script type="application/ld+json">\n    ${jsonLdEscape(ld)}\n    </script>\n`;
  }

  // Breadcrumb JSON-LD
  const breadcrumbBlogUrl =
    locale === "en" ? `${SITE_URL}/blog/` : `${SITE_URL}/${locale}/blog/`;
  const breadcrumbLd = {
    "@context": "https://schema.org",
    "@type": "BreadcrumbList",
    itemListElement: [
      {
        "@type": "ListItem",
        position: 1,
        name: "Cheese! OCR",
        item: SITE_URL + "/",
      },
      {
        "@type": "ListItem",
        position: 2,
        name: "Blog",
        item: breadcrumbBlogUrl,
      },
      { "@type": "ListItem", position: 3, name: fm.title },
    ],
  };

  const fav = faviconBase(locale);

  return `    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="color-scheme" content="light dark">
    <meta name="theme-color" content="#ffffff" media="(prefers-color-scheme: light)">
    <meta name="theme-color" content="#141416" media="(prefers-color-scheme: dark)">

    <title>${escapeHtml(fm.title)} — Cheese! OCR Blog</title>
    <meta name="description" content="${escapeHtml(fm.description)}">

    <link rel="canonical" href="${escapeHtml(url)}">
${hreflangLinks}
    <link rel="alternate" hreflang="x-default" href="${escapeHtml(xDefaultUrl)}">

    <link rel="icon" type="image/svg+xml" href="${fav}favicon.svg?v=3">
    <link rel="icon" type="image/png" sizes="32x32" href="${fav}favicon-32.png">
    <link rel="apple-touch-icon" sizes="180x180" href="${fav}apple-touch-icon.png">

    <link rel="stylesheet" href="${articleCssHref(locale)}">

    <meta property="og:type" content="article">
    <meta property="og:site_name" content="Cheese! OCR">
    <meta property="og:title" content="${escapeHtml(fm.title)}">
    <meta property="og:description" content="${escapeHtml(fm.description)}">
    <meta property="og:url" content="${escapeHtml(url)}">
    <meta property="og:image" content="${SITE_URL}/og-image.png">
    <meta property="og:image:width" content="1200">
    <meta property="og:image:height" content="630">
    <meta property="og:locale" content="${ogLocale}">
    <meta property="article:published_time" content="${fm.date}">
    <meta property="article:author" content="Cheese! OCR Team">

    <meta name="twitter:card" content="summary_large_image">
    <meta name="twitter:title" content="${escapeHtml(fm.title)}">
    <meta name="twitter:description" content="${escapeHtml(fm.description)}">
    <meta name="twitter:image" content="${SITE_URL}/og-image.png">

    <script type="application/ld+json">
    ${jsonLdEscape(articleLd)}
    </script>${faqLd}
    <script type="application/ld+json">
    ${jsonLdEscape(breadcrumbLd)}
    </script>`;
}

function renderLangSwitcher(slug, currentLocale, slugIndex) {
  const items = LOCALES.filter((l) => slugIndex[l]?.[slug]).map((l) => {
    const href = postSiteRelUrl(l, slug);
    const ariaCurrent = l === currentLocale ? ' aria-current="page"' : "";
    return `            <a href="${href}"${ariaCurrent} hreflang="${LOCALE_HREFLANG[l]}">${LOCALE_LABEL[l]}</a>`;
  });
  return `        <div class="lang-switcher">
${items.join("\n")}
        </div>`;
}

function renderTldr(tldr, locale) {
  if (!tldr || String(tldr).trim() === "") return "";
  const text = String(tldr).trim();
  // tldr may be a multi-line plain string; render as a single paragraph (preserve line breaks as spaces).
  const cleaned = text.replace(/\s+/g, " ").trim();
  return `
    <aside class="tldr">
        <strong>${LOCALE_TLDR[locale]}</strong>
        ${escapeHtml(cleaned)}
    </aside>
`;
}

async function renderBody(content) {
  return markdownToHtml(content);
}

function renderFaq(faqs, locale) {
  if (!Array.isArray(faqs) || faqs.length === 0) return "";
  const items = faqs
    .map((f) => {
      const q = stripMarkdown(f.q);
      const a = stripMarkdown(f.a);
      return `        <details class="faq-item">
            <summary>${escapeHtml(q)}</summary>
            <div class="answer">${escapeHtml(a)}</div>
        </details>`;
    })
    .join("\n");
  return `
    <section class="article-faq">
        <h2>${LOCALE_FAQ_HEADING[locale]}</h2>
${items}
    </section>
`;
}

function renderCta(locale) {
  const cta = LOCALE_CTA[locale];
  return `
    <section class="article-cta">
        <div class="cta-card">
            <h2>${escapeHtml(cta.heading)}</h2>
            <p>${escapeHtml(cta.body)}</p>
            <a href="${APP_STORE_URL}" class="cta-button">${escapeHtml(cta.button)}</a>
        </div>
    </section>
`;
}

function renderRelated(internalLinks, locale, slugIndex) {
  if (!Array.isArray(internalLinks) || internalLinks.length === 0) return "";
  const cards = internalLinks
    .map((linkSlug) => {
      const meta = slugIndex[locale]?.[linkSlug];
      if (!meta) return null;
      return `            <a href="${relativeSiblingHref(linkSlug)}" class="related-card">
                <h3>${escapeHtml(meta.title)}</h3>
                <p>${escapeHtml(meta.description)}</p>
            </a>`;
    })
    .filter(Boolean);
  if (cards.length === 0) return "";
  return `
    <section class="article-related">
        <h2>${LOCALE_RELATED_HEADING[locale]}</h2>
        <div class="related-grid">
${cards.join("\n")}
        </div>
    </section>
`;
}

function renderFooter(locale) {
  const f = LOCALE_FOOTER[locale];
  return `
    <footer class="article-footer">
        <a href="${homeHref(locale)}">${escapeHtml(f.home)}</a>
        <a href="${privacyHref(locale)}">${escapeHtml(f.privacy)}</a>
        <a href="mailto:${CONTACT_EMAIL}">${escapeHtml(f.contact)}</a>
        <p>${f.copyright}</p>
    </footer>
`;
}

async function renderPost(filePath, slugIndex) {
  const raw = await readFile(filePath, "utf8");
  const { data: fm, content } = matter(raw);
  if (!fm.slug || !fm.locale) {
    throw new Error(`${filePath}: missing slug/locale in frontmatter`);
  }
  // Normalize: gray-matter auto-parses YAML dates into Date objects, but we
  // need a plain "YYYY-MM-DD" string everywhere downstream.
  fm.date = isoDate(fm.date);
  const slug = fm.slug;
  const locale = fm.locale;
  const url = postUrl(locale, slug);

  const head = renderHead({ fm, locale, slug, url, slugIndex });
  const langSwitcher = renderLangSwitcher(slug, locale, slugIndex);
  const tldr = renderTldr(fm.tldr, locale);
  const bodyHtml = await renderBody(content);
  const faq = renderFaq(fm.faqs, locale);
  const cta = renderCta(locale);
  const related = renderRelated(fm.internal_links, locale, slugIndex);
  const footer = renderFooter(locale);

  const dateLabel = LOCALE_DATE_FORMAT[locale](fm.date);
  const readMin = fm.read_min ? LOCALE_READ_MIN_LABEL[locale](fm.read_min) : "";
  const meta =
    `        <time datetime="${fm.date}">${escapeHtml(dateLabel)}</time>` +
    (readMin ? `\n            · ${escapeHtml(readMin)}` : "");

  const html = `<!DOCTYPE html>
<html lang="${LOCALE_HREFLANG[locale]}">
<head>
${head}
</head>
<body>

    <nav class="article-nav">
        <a href="${backToBlogHref()}" class="back-link">${escapeHtml(LOCALE_BACK_TO_BLOG[locale])}</a>
${langSwitcher}
    </nav>

    <header class="article-header">
        <h1>${escapeHtml(fm.title)}</h1>
        <p class="article-meta">
${meta}
        </p>
    </header>
${tldr}
    <article class="article-body">
${bodyHtml}
    </article>
${faq}${cta}${related}${footer}
</body>
</html>
`;

  const outDir = postOutDir(locale, slug);
  await mkdir(outDir, { recursive: true });
  const outPath = path.join(outDir, "index.html");
  await writeFile(outPath, html);
  return { filePath, outPath, slug, locale };
}

async function collectMdxFiles(filter) {
  const files = [];
  for (const locale of LOCALES) {
    if (filter.locale && filter.locale !== locale) continue;
    const dir = path.join(PROJECT_ROOT, "content", "blog", locale);
    if (!existsSync(dir)) continue;
    const entries = await readdir(dir);
    for (const f of entries) {
      if (!f.endsWith(".mdx")) continue;
      const slug = f.replace(/\.mdx$/, "");
      if (filter.only && filter.only !== slug) continue;
      files.push(path.join(dir, f));
    }
  }
  return files;
}

async function main() {
  const args = parseArgs(argv.slice(2));
  const slugIndex = await buildSlugIndex();
  const files = await collectMdxFiles(args);
  if (files.length === 0) {
    console.error("No MDX files matched.");
    exit(1);
  }
  console.log(`Rendering ${files.length} post(s)...`);
  for (const f of files) {
    try {
      const r = await renderPost(f, slugIndex);
      console.log(
        `✓ ${path.relative(process.cwd(), r.filePath)}  →  ${path.relative(process.cwd(), r.outPath)}`,
      );
    } catch (e) {
      console.error(`✗ ${path.relative(process.cwd(), f)}: ${e.message}`);
      if (process.env.DEBUG) console.error(e.stack);
      exit(1);
    }
  }
  console.log(`\nRendered ${files.length} post(s).`);
}

main().catch((e) => {
  console.error(`Error: ${e.message}`);
  if (process.env.DEBUG) console.error(e.stack);
  exit(1);
});
