#!/usr/bin/env node
/**
 * Generate localized App Store screenshots.
 *
 * Usage:
 *   node generate.js                  # all languages
 *   node generate.js en               # English only
 *   node generate.js zh-Hans ja       # Chinese + Japanese
 */

const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");

const DIR = __dirname;
const CHROME =
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const WIDTH = 1280;
const HEIGHT = 800;
const SCALE = 2;

const i18n = JSON.parse(fs.readFileSync(path.join(DIR, "i18n.json"), "utf8"));

// Which languages to build (default: all)
const requestedLangs = process.argv.slice(2);
const langs =
  requestedLangs.length > 0
    ? requestedLangs.filter((l) => i18n[l])
    : Object.keys(i18n);

// ── Replacement map per slide ──────────────────────────────────────
// Each entry maps a literal string in the English HTML → the i18n key
// that provides the replacement.

const slideReplacements = {
  "slide1.html": {
    "Fast, Private OCR for Your Mac": "tagline",
  },
  "slide2.html": {
    "Instant Screen Capture": "title",
    "Select any area. Get text instantly.": "subtitle",
    "Hello, World! 你好世界": "hud_text",
  },
  "slide3.html": {
    ">100% Private<": { key: "title", wrap: [">", "<"] },
    ">On-Device<": { key: "point1", wrap: [">", "<"] },
    ">No Network<": { key: "point2", wrap: [">", "<"] },
    ">Zero Data Collection<": { key: "point3", wrap: [">", "<"] },
  },
  "slide4.html": {
    "Multi-language OCR": "title",
    "Recognizes text across languages, out of the box": "subtitle",
  },
  "slide5.html": {
    ">Lives in Your Menu Bar<": { key: "title", wrap: [">", "<"] },
    ">Always ready, never in the way<": { key: "subtitle", wrap: [">", "<"] },
    "Hello World 你好世...": "menu_history1",
    "The quick brown fo...": "menu_history2",
    "import SwiftUI fra...": "menu_history3",
  },
};

// Special handler for slide5 menubar labels and menu items
function applySlide5Special(html, t) {
  // Menubar Finder-style labels
  html = html.replace('>File<', `>${t.menubar_file}<`);
  html = html.replace('>Edit<', `>${t.menubar_edit}<`);
  html = html.replace('>View<', `>${t.menubar_view}<`);
  html = html.replace('>Go<', `>${t.menubar_go}<`);
  html = html.replace('>Window<', `>${t.menubar_window}<`);
  html = html.replace('>Help<', `>${t.menubar_help}<`);
  // Dropdown menu items — match indented text between tags
  html = html.replace(
    /(\s+)Capture and OCR(\s*\n\s*<span class="shortcut">)/,
    `$1${t.menu_capture}$2`
  );
  html = html.replace(
    /(\s+)Show More Result(\s*\n)/,
    `$1${t.menu_show_more}$2`
  );
  html = html.replace(
    /(\s+)Settings(\s*\n\s*<span class="shortcut">⌘,)/,
    `$1${t.menu_settings}$2`
  );
  html = html.replace(
    /(\s+)Quit(\s*\n\s*<span class="shortcut">⌘Q)/,
    `$1${t.menu_quit}$2`
  );
  return html;
}

function applyReplacements(html, replacements, translations) {
  for (const [search, spec] of Object.entries(replacements)) {
    if (spec === null) continue; // handled separately
    if (typeof spec === "string") {
      const val = translations[spec];
      if (val !== undefined) {
        html = html.replace(search, val);
      }
    } else {
      // { key, wrap: [prefix, suffix] }
      const val = translations[spec.key];
      if (val !== undefined) {
        html = html.replace(search, `${spec.wrap[0]}${val}${spec.wrap[1]}`);
      }
    }
  }
  return html;
}

// Also update <html lang="...">
function setLang(html, lang) {
  return html.replace(/lang="[^"]*"/, `lang="${lang}"`);
}

// ── Main ───────────────────────────────────────────────────────────

const slides = ["slide1.html", "slide2.html", "slide3.html", "slide4.html", "slide5.html"];

for (const lang of langs) {
  const outDir = path.join(DIR, lang);
  if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });

  // Copy icon.png into locale dir if not present (slide1 needs it)
  const iconSrc = path.join(DIR, "icon.png");
  const iconDst = path.join(outDir, "icon.png");
  if (fs.existsSync(iconSrc) && !fs.existsSync(iconDst)) {
    fs.copyFileSync(iconSrc, iconDst);
  }

  const t = i18n[lang];

  for (const slide of slides) {
    const slideKey = slide.replace(".html", "");
    const translations = t[slideKey];
    if (!translations) {
      console.log(`  [skip] ${lang}/${slide} — no translations`);
      continue;
    }

    let html = fs.readFileSync(path.join(DIR, slide), "utf8");
    const replacements = slideReplacements[slide] || {};

    html = setLang(html, lang);
    html = applyReplacements(html, replacements, translations);

    if (slide === "slide5.html") {
      html = applySlide5Special(html, translations);
    }

    // Write localized HTML
    const htmlOut = path.join(outDir, slide);
    fs.writeFileSync(htmlOut, html, "utf8");

    // Screenshot
    const pngOut = path.join(outDir, slide.replace(".html", ".png"));
    const fileUrl = `file://${htmlOut}`;
    try {
      execSync(
        `"${CHROME}" --headless --disable-gpu ` +
          `--screenshot="${pngOut}" ` +
          `--window-size=${WIDTH},${HEIGHT} ` +
          `--force-device-scale-factor=${SCALE} ` +
          `--hide-scrollbars "${fileUrl}"`,
        { stdio: "pipe" }
      );
      console.log(`  [ok] ${lang}/${slide.replace(".html", ".png")}`);
    } catch (e) {
      console.error(`  [FAIL] ${lang}/${slide}:`, e.message);
    }
  }
}

console.log("\nDone! Screenshots in:", langs.map((l) => `${l}/`).join(", "));
