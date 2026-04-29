// Shared helpers for the blog pipeline.

import { readFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

export const PROJECT_ROOT = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
  "..",
);

export const LOCALE_LANG = {
  en: "American English",
  zh: "Simplified Chinese (大陆), 大陆习惯",
  ja: "Japanese (丁寧語: です・ます調)",
  ko: "Korean (합쇼체: -ㅂ니다 / -습니다)",
};

export const LOCALE_OG = {
  en: "en_US",
  zh: "zh_CN",
  ja: "ja_JP",
  ko: "ko_KR",
};

export const LOCALE_HREFLANG = {
  en: "en",
  zh: "zh-Hans",
  ja: "ja",
  ko: "ko",
};

export const LOCALE_LABEL = {
  en: "EN",
  zh: "中文",
  ja: "日本語",
  ko: "한국어",
};

export const LOCALE_DATE_FORMAT = {
  en: (iso) => {
    const d = new Date(iso + "T00:00:00Z");
    return d.toLocaleDateString("en-US", {
      year: "numeric",
      month: "long",
      day: "numeric",
      timeZone: "UTC",
    });
  },
  zh: (iso) => {
    const d = new Date(iso + "T00:00:00Z");
    return `${d.getUTCFullYear()}年${d.getUTCMonth() + 1}月${d.getUTCDate()}日`;
  },
  ja: (iso) => {
    const d = new Date(iso + "T00:00:00Z");
    return `${d.getUTCFullYear()}年${d.getUTCMonth() + 1}月${d.getUTCDate()}日`;
  },
  ko: (iso) => {
    const d = new Date(iso + "T00:00:00Z");
    return `${d.getUTCFullYear()}년 ${d.getUTCMonth() + 1}월 ${d.getUTCDate()}일`;
  },
};

export const LOCALE_READ_MIN_LABEL = {
  en: (n) => `${n} min read`,
  zh: (n) => `约 ${n} 分钟`,
  ja: (n) => `約 ${n} 分`,
  ko: (n) => `약 ${n}분`,
};

export const LOCALE_BACK_TO_BLOG = {
  en: "← Blog",
  zh: "← 博客",
  ja: "← ブログ",
  ko: "← 블로그",
};

export const LOCALE_TLDR = {
  en: "TL;DR",
  zh: "速览",
  ja: "要点",
  ko: "요약",
};

export const LOCALE_FAQ_HEADING = {
  en: "Frequently Asked Questions",
  zh: "常见问题",
  ja: "よくある質問",
  ko: "자주 묻는 질문",
};

export const LOCALE_RELATED_HEADING = {
  en: "Related articles",
  zh: "相关文章",
  ja: "関連記事",
  ko: "관련 글",
};

export const LOCALE_CTA = {
  en: {
    heading: "Try Cheese! OCR",
    body: "One hotkey. Drag-select. Text on your clipboard. $5.99 one-time, on-device, works in any app you can see.",
    button: "Try Cheese! OCR — Mac App Store",
  },
  zh: {
    heading: "试试 Cheese! OCR",
    body: "一个快捷键,框选,文字到剪贴板。一次性 $5.99,完全本地运行,任何你能看到的 app 都能用。",
    button: "在 Mac App Store 下载",
  },
  ja: {
    heading: "Cheese! OCR を試す",
    body: "ホットキー一つ、ドラッグで範囲選択、テキストはクリップボードへ。買い切り $5.99、完全オンデバイス、画面に表示されているものなら何でも対応。",
    button: "Mac App Store で入手",
  },
  ko: {
    heading: "Cheese! OCR 사용해보기",
    body: "단축키 하나, 드래그로 영역 선택, 텍스트가 클립보드에. 일회성 결제 $5.99, 완전 온디바이스, 화면에 보이는 모든 앱에서 작동합니다.",
    button: "Mac App Store에서 다운로드",
  },
};

export const LOCALE_FOOTER = {
  en: {
    home: "Home",
    privacy: "Privacy Policy",
    contact: "Contact",
    copyright: "&copy; 2026 Cheese! OCR. All rights reserved.",
  },
  zh: {
    home: "主页",
    privacy: "隐私政策",
    contact: "联系我们",
    copyright: "&copy; 2026 Cheese! OCR. 版权所有。",
  },
  ja: {
    home: "ホーム",
    privacy: "プライバシーポリシー",
    contact: "お問い合わせ",
    copyright: "&copy; 2026 Cheese! OCR. All rights reserved.",
  },
  ko: {
    home: "홈",
    privacy: "개인정보 처리방침",
    contact: "문의하기",
    copyright: "&copy; 2026 Cheese! OCR. All rights reserved.",
  },
};

export const SITE_URL = "https://kaedeeeeeeeeee.github.io/OCR_LLM";
export const APP_STORE_URL = "https://apps.apple.com/app/cheese-ocr/id6760889131";
export const CONTACT_EMAIL = "nicholaslck@icloud.com";

export async function loadConfig() {
  const p = path.join(PROJECT_ROOT, "seo-blog.config.json");
  if (!existsSync(p)) throw new Error(`Missing ${p}`);
  return JSON.parse(await readFile(p, "utf8"));
}

export async function loadStyleGuide() {
  const p = path.join(PROJECT_ROOT, "style-guide.md");
  if (!existsSync(p)) return "";
  return readFile(p, "utf8");
}

/** Parse simple CSV: handles quoted fields, escaped quotes, semicolon-separated list cells. */
export function parseCSV(text) {
  const lines = [];
  let row = [];
  let cell = "";
  let i = 0;
  let inQuotes = false;
  while (i < text.length) {
    const c = text[i];
    if (inQuotes) {
      if (c === '"') {
        if (text[i + 1] === '"') {
          cell += '"';
          i += 2;
          continue;
        }
        inQuotes = false;
        i++;
        continue;
      }
      cell += c;
      i++;
      continue;
    }
    if (c === '"') {
      inQuotes = true;
      i++;
      continue;
    }
    if (c === ",") {
      row.push(cell);
      cell = "";
      i++;
      continue;
    }
    if (c === "\n" || c === "\r") {
      if (c === "\r" && text[i + 1] === "\n") i++;
      row.push(cell);
      cell = "";
      lines.push(row);
      row = [];
      i++;
      continue;
    }
    cell += c;
    i++;
  }
  if (cell || row.length > 0) {
    row.push(cell);
    lines.push(row);
  }
  if (lines.length === 0) return [];
  const headers = lines[0].map((h) => h.trim());
  return lines.slice(1)
    .filter((r) => r.length > 0 && r.some((c) => c.trim() !== ""))
    .map((r) => {
      const obj = {};
      headers.forEach((h, idx) => {
        obj[h] = (r[idx] ?? "").trim();
      });
      return obj;
    });
}

/**
 * Split a "a;b;c" or "a；b；c" cell into a clean array.
 * Accepts both ASCII `;` and CJK fullwidth `；` as separators since CSVs
 * for zh/ja/ko posts naturally contain both.
 */
export function splitList(s) {
  if (!s) return [];
  return s.split(/[;；]/).map((x) => x.trim()).filter(Boolean);
}

/** Render a YAML list of strings (each prefixed with two-space + dash). */
export function yamlList(items, indent = 2) {
  const pad = " ".repeat(indent);
  return items.map((s) => `${pad}- "${s.replace(/"/g, '\\"')}"`).join("\n");
}

/** Replace {{KEY}} placeholders in a template. */
export function fillTemplate(tmpl, vars) {
  return tmpl.replace(/\{\{(\w+)\}\}/g, (_, k) => {
    if (!(k in vars)) {
      throw new Error(`Template placeholder {{${k}}} has no value`);
    }
    return vars[k];
  });
}
