#!/usr/bin/env node
// topics-spec.mjs — author-friendly source for the per-slug, per-locale topic matrix.
// Run this to regenerate topics.csv from the SPECS array below.
//
// Each spec entry is one slug. key_facts/internal_links/read_min/template are shared
// across locales; title/description/tags are per-locale.
//
// Usage:
//   node scripts/blog/topics-spec.mjs   →   writes topics.csv

import { writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const PROJECT_ROOT = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
  "..",
);

const LOCALES = ["en", "zh", "ja", "ko"];

const SPECS = [
  {
    slug: "how-to-ocr-from-zoom-meetings-on-mac",
    template: "howto",
    read_min: 9,
    internal_links: [
      "copy-text-from-video-on-mac",
      "cheese-ocr-vs-live-text",
      "extract-text-from-screenshot-on-mac",
    ],
    key_facts: [
      "macOS Live Text does not work in Zoom, Microsoft Teams, Google Meet (in Chrome), or Webex meeting windows because they are not AppKit image views",
      "Live Text only works inside Apple's own apps (Photos, Preview, Safari, Notes, QuickLook) and WebKit-rendered images",
      "Apple ships ScreenCaptureKit since macOS 12.3 (April 2022) for low-overhead screen capture",
      "When a meeting host enables DRM screen-protection, Cmd+Shift+4 screenshots return a black rectangle — set by the host, not the meeting app",
      "Cheese! OCR uses the Screen Recording permission to read screen pixels; macOS prompts for it on first hotkey use",
      "Cheese! OCR's default hotkey is Shift+Command+E and is configurable in Settings",
      "Cheese! OCR is built on the Apple Vision framework — same engine as Live Text",
      "In ordinary meetings without DRM, Cheese! OCR / Text Sniper / similar Vision-based tools recognize on-screen text fine",
      "Apple Vision auto-detects English, Simplified Chinese, Traditional Chinese, Japanese, Korean — no manual language switch",
      "Hotkey-drag-paste workflow takes ~2 seconds per text grab once muscle memory kicks in",
      "Cheese! OCR's sandbox declares zero network entitlements — verifiable in the Mac App Store privacy report",
      "Zoom's built-in 'save chat' and 'save transcript' do not include text on the presenter's slides",
      "What Cmd+Shift+4 can capture, Cheese! OCR can also OCR — same underlying screen-capture API",
    ],
    locales: {
      en: {
        title: "How to OCR Text from a Zoom Meeting on Mac (Teams, Meet, Webex too)",
        description:
          "Why macOS Live Text doesn't work in Zoom meeting windows, what DRM screen-protection means, and three reliable ways to copy text from Zoom, Teams, Meet, and Webex on Mac.",
        tags: [
          "Mac OCR",
          "Zoom",
          "Microsoft Teams",
          "Google Meet",
          "Webex",
          "video conferencing",
          "screenshot OCR",
        ],
      },
      zh: {
        title: "如何在 Mac 上从 Zoom 会议中提取文字（含 Teams、Meet、Webex）",
        description:
          "Zoom 会议窗口里 Live Text 不工作的原因、DRM 屏保护的影响，以及在 Zoom、Teams、Meet、Webex 会议中复制文字的三种可靠方法。",
        tags: ["Mac OCR", "Zoom", "Microsoft Teams", "Google Meet", "Webex", "视频会议", "截图 OCR"],
      },
      ja: {
        title: "Mac で Zoom ミーティングのテキストを OCR する方法（Teams・Meet・Webex も）",
        description:
          "macOS のライブテキストが Zoom ミーティングウィンドウで動作しない理由、DRM 画面保護フラグの仕組み、Zoom・Teams・Meet・Webex からテキストを取り出す確実な 3 つの方法。",
        tags: ["Mac OCR", "Zoom", "Microsoft Teams", "Google Meet", "Webex", "ビデオ会議", "スクリーンショット OCR"],
      },
      ko: {
        title: "Mac에서 Zoom 회의 텍스트를 OCR하는 방법 (Teams·Meet·Webex 포함)",
        description:
          "Zoom 회의 창에서 macOS 라이브 텍스트가 작동하지 않는 이유, DRM 화면 보호의 영향, Zoom·Teams·Meet·Webex에서 텍스트를 복사하는 세 가지 방법.",
        tags: ["Mac OCR", "Zoom", "Microsoft Teams", "Google Meet", "Webex", "화상 회의", "스크린샷 OCR"],
      },
    },
  },

  {
    slug: "how-to-ocr-code-from-tutorial-video-on-mac",
    template: "howto",
    read_min: 8,
    internal_links: [
      "copy-text-from-video-on-mac",
      "extract-text-from-screenshot-on-mac",
      "how-on-device-ocr-works",
    ],
    key_facts: [
      "Live Text recognizes code in paused video frames inside Safari but does not work in Chrome, Firefox, Edge, Brave, or Arc — they use their own rendering engines",
      "Live Text does not work in IINA, VLC, or most third-party Mac video players",
      "Apple Vision recognizes monospace fonts well but commonly confuses 0/O, 1/l/I, and similar pairs in code",
      "OCR of multi-line code typically loses indentation; you have to re-indent manually after pasting",
      "Special characters in code can misrecognize: `→` may read as `>` or `-`, `=>` as `=`, ligatures from Fira Code/Cascadia may produce odd results",
      "Higher source resolution improves accuracy substantially — 1080p source is fine, 720p is risky for small fonts",
      "Cheese! OCR works in Chrome and any other browser because it reads screen pixels via Screen Recording, not Live Text",
      "Cheese! OCR's default hotkey is Shift+Command+E, configurable in Settings",
      "Cheese! OCR uses Apple Vision under the hood — accuracy comparable to Live Text on the same content",
      "After OCR'ing code, manually validate by running it; common substitutions to search for: 0↔O, 1↔l, 5↔S, rn↔m",
      "Tutorial videos on YouTube paused in Safari work with Live Text; the same video paused in Chrome does not",
      "Code on dark backgrounds with syntax highlighting recognizes fine — high contrast helps regardless of color scheme",
    ],
    locales: {
      en: {
        title: "How to Copy Code from a Tutorial Video on Mac (Without Retyping)",
        description:
          "Why Live Text only catches code in Safari, the common 0/O confusion to watch for, and how to OCR code from a paused YouTube or Loom frame in any browser.",
        tags: ["Mac OCR", "code", "tutorial video", "YouTube", "Loom", "developer", "screenshot OCR"],
      },
      zh: {
        title: "如何在 Mac 上从教程视频里复制代码（免重打）",
        description:
          "为什么 Live Text 只能识别 Safari 里的代码、要警惕的 0/O 混淆，以及如何在任何浏览器从暂停的 YouTube 或 B 站视频帧中 OCR 出代码。",
        tags: ["Mac OCR", "代码", "教程视频", "YouTube", "B 站", "开发者", "截图 OCR"],
      },
      ja: {
        title: "Mac でチュートリアル動画からコードをコピーする方法（再入力不要）",
        description:
          "Safari でしかコードに反応しないライブテキストの制限、注意すべき 0/O の誤認識、ブラウザを問わず一時停止した YouTube や Loom のフレームからコードを OCR する方法。",
        tags: ["Mac OCR", "コード", "チュートリアル動画", "YouTube", "Loom", "開発者", "スクリーンショット OCR"],
      },
      ko: {
        title: "Mac에서 튜토리얼 영상의 코드를 복사하는 방법 (다시 입력 불필요)",
        description:
          "Safari에서만 코드를 인식하는 라이브 텍스트의 한계, 0/O 혼동 주의점, 어떤 브라우저에서든 일시정지한 YouTube나 Loom 프레임에서 코드를 OCR하는 방법.",
        tags: ["Mac OCR", "코드", "튜토리얼 영상", "YouTube", "Loom", "개발자", "스크린샷 OCR"],
      },
    },
  },

  {
    slug: "how-to-ocr-receipt-on-mac",
    template: "howto",
    read_min: 8,
    internal_links: [
      "extract-text-from-screenshot-on-mac",
      "how-on-device-ocr-works",
      "ocr-asian-languages-on-mac",
    ],
    key_facts: [
      "Photos.app and Preview.app on macOS 12+ support Live Text on receipt photos and PDF scans",
      "Apple Vision handles printed receipt thermal-paper text well in good lighting; faded thermal print is unreliable regardless of OCR engine",
      "Live Text in Photos surfaces phone numbers, addresses, dates, and amounts as tappable data — useful for receipts",
      "PDFs from email receipts (Uber Eats, Amazon, airlines) are usually native PDFs with selectable text already — no OCR needed",
      "Scanned PDF receipts (e.g., from a flatbed scanner) need OCR; Preview's Live Text handles many; Adobe Acrobat Pro's OCR or ocrmypdf (open source CLI) handle the rest",
      "iPhone Notes and Files apps have a 'Scan Documents' feature that produces searchable PDFs — these are auto-OCR'd",
      "For batch receipt processing (expense reports), workflows that work: take photos → AirDrop to Mac → Photos → Live Text select → paste",
      "Cheese! OCR works on receipt photos opened in any app, including third-party photo viewers Live Text doesn't reach",
      "Apple Vision recognizes English, Simplified/Traditional Chinese, Japanese, Korean, French, German, Italian, Spanish, Portuguese on receipts",
      "Receipts in unsupported scripts (Russian/Cyrillic, Arabic, Hebrew, Thai) require Tesseract or a cloud OCR service",
      "Receipt amounts with commas vs dots as decimal separator (US vs EU) are preserved — OCR doesn't normalize",
      "Cheese! OCR's default hotkey is Shift+Command+E, all processing on-device, no network entitlements — relevant for receipts containing personal info",
    ],
    locales: {
      en: {
        title: "How to OCR a Receipt on Mac (For Expense Reports and Tax Time)",
        description:
          "Three reliable ways to extract text from a receipt on Mac — Live Text in Photos, scanned PDF OCR, and a hotkey OCR tool — plus the cases where each one fails.",
        tags: ["Mac OCR", "receipt", "expense report", "tax", "Live Text", "scanned PDF", "screenshot OCR"],
      },
      zh: {
        title: "如何在 Mac 上 OCR 识别小票（报销与报税）",
        description:
          "Mac 上从小票中提取文字的三种方法——Photos 里的 Live Text、扫描 PDF OCR、快捷键 OCR 工具——以及它们各自失效的场景。",
        tags: ["Mac OCR", "小票", "报销", "报税", "Live Text", "扫描 PDF", "截图 OCR"],
      },
      ja: {
        title: "Mac でレシートを OCR する方法（経費精算・確定申告に）",
        description:
          "Mac でレシートからテキストを取り出す確実な 3 つの方法——写真アプリのライブテキスト、スキャン PDF の OCR、ホットキー OCR ツール——それぞれが効かないケースも解説。",
        tags: ["Mac OCR", "レシート", "経費精算", "確定申告", "ライブテキスト", "スキャン PDF", "スクリーンショット OCR"],
      },
      ko: {
        title: "Mac에서 영수증을 OCR하는 방법 (경비 보고서와 연말 정산용)",
        description:
          "Mac에서 영수증 텍스트를 추출하는 세 가지 방법 — 사진 앱의 라이브 텍스트, 스캔 PDF OCR, 단축키 OCR 도구 — 그리고 각각이 실패하는 경우.",
        tags: ["Mac OCR", "영수증", "경비 보고서", "연말 정산", "라이브 텍스트", "스캔 PDF", "스크린샷 OCR"],
      },
    },
  },

  {
    slug: "ocr-handwriting-on-mac-honest-guide",
    template: "guide",
    read_min: 9,
    internal_links: [
      "ocr-asian-languages-on-mac",
      "how-on-device-ocr-works",
      "extract-text-from-screenshot-on-mac",
    ],
    key_facts: [
      "Apple Vision is trained primarily on printed text; handwriting recognition is more limited and language-dependent",
      "Live Text supports some English print-style handwriting in macOS 14 Sonoma and later; very limited for non-Latin scripts",
      "Recognition rate depends on legibility, ink-to-background contrast, language, print vs cursive, and lighting in the photo",
      "Chinese cursive (草书 / 行书) recognition rate with Apple Vision is near zero",
      "Japanese tegaki (手書き) printed-style is partial; freehand and cursive are not reliable",
      "Korean handwriting (손글씨) similarly limited — printed forms recognize, freehand does not",
      "For dense handwritten notes, Apple Notes' built-in 'Search Handwriting' uses a different model tuned specifically for handwriting and works better than Live Text",
      "Apple Notes' 'Scan Documents' feature produces searchable PDFs with handwriting search via the same handwriting model",
      "GoodNotes and Notability use their own handwriting recognition models, often more accurate for cursive English",
      "Transkribus is the dedicated tool for archive-quality handwriting OCR (research-grade, free tier limited)",
      "Cheese! OCR uses Apple Vision so inherits its strengths and limits — printed handwriting may work, cursive will not",
      "Improving photo quality (lighting, focus, contrast) helps far more than switching tools for handwriting OCR",
    ],
    locales: {
      en: {
        title: "Handwriting OCR on Mac: An Honest Guide to What Works and What Doesn't",
        description:
          "What Apple Vision can and can't read in handwritten notes, why cursive Chinese fails, and which tools actually help when Live Text gives up.",
        tags: ["Mac OCR", "handwriting", "Apple Vision", "Live Text", "Apple Notes", "GoodNotes", "Transkribus"],
      },
      zh: {
        title: "Mac 手写文字 OCR 实情指南：哪些能识，哪些识不出",
        description:
          "Apple Vision 在手写笔记上能识别什么、识不出什么，为什么中文草书几乎完全失效，以及 Live Text 不行时用哪些工具。",
        tags: ["Mac OCR", "手写", "Apple Vision", "Live Text", "备忘录", "GoodNotes", "Transkribus"],
      },
      ja: {
        title: "Mac で手書き文字を OCR：正直なガイド——できること・できないこと",
        description:
          "Apple Vision が手書きノートで読めるもの・読めないもの、日本語の手書きが部分的にしか認識されない理由、ライブテキストが諦めたときに使えるツール。",
        tags: ["Mac OCR", "手書き", "Apple Vision", "ライブテキスト", "メモアプリ", "GoodNotes", "Transkribus"],
      },
      ko: {
        title: "Mac에서 손글씨 OCR: 솔직한 가이드 — 되는 것과 안 되는 것",
        description:
          "Apple Vision이 손글씨 메모에서 인식하는 것과 못하는 것, 한글 손글씨의 한계, 라이브 텍스트가 안 될 때 쓸만한 도구들.",
        tags: ["Mac OCR", "손글씨", "Apple Vision", "라이브 텍스트", "메모 앱", "GoodNotes", "Transkribus"],
      },
    },
  },

  {
    slug: "how-to-ocr-foreign-language-screenshot-on-mac",
    template: "guide",
    read_min: 8,
    internal_links: [
      "ocr-asian-languages-on-mac",
      "extract-text-from-screenshot-on-mac",
      "how-on-device-ocr-works",
    ],
    key_facts: [
      "Apple Vision recognizes English, Simplified Chinese, Traditional Chinese, Japanese, Korean, French, German, Italian, Spanish, Portuguese as of macOS 14",
      "macOS 12 supported English/French/Italian/German/Portuguese/Spanish/Chinese; Japanese and Korean were added in macOS 13",
      "Live Text and Cheese! OCR auto-detect the language — you do not select one manually",
      "Apple Vision does NOT recognize Cyrillic (Russian, Ukrainian), Arabic, Hebrew, Thai, Vietnamese as of early 2026",
      "For unsupported scripts: Tesseract (open-source CLI) with the appropriate language data, or cloud OCR (Google Cloud Vision, Azure AI Vision)",
      "Apple Translate is built into macOS 12+ and does on-device translation for many language pairs without sending text to the cloud",
      "Mixed-language text (e.g., English embedded in a Japanese page) is handled automatically — Apple Vision recognizes both",
      "Right-to-left scripts (Arabic, Hebrew) require RTL-aware OCR; Apple Vision does not currently support them",
      "After OCR, common translation paths: Apple Translate (on-device), DeepL (cloud, generally best for European languages), Google Translate (cloud, broadest coverage)",
      "Cheese! OCR is built on Apple Vision and inherits the supported-language list — same on-device, no network",
      "For Chinese, Apple Vision auto-handles both Simplified and Traditional script — no toggle needed",
      "For Japanese, Apple Vision handles hiragana, katakana, and printed kanji; freehand handwriting is partial",
    ],
    locales: {
      en: {
        title: "How to OCR a Foreign-Language Screenshot on Mac (and What Mac Can't Read)",
        description:
          "Which languages Apple Vision recognizes on Mac, which scripts it can't handle, and how to fall back to Tesseract or a cloud OCR service when needed.",
        tags: ["Mac OCR", "foreign language", "translation", "Apple Vision", "Tesseract", "Apple Translate", "DeepL"],
      },
      zh: {
        title: "Mac 上如何 OCR 外文截图（以及哪些文字 Mac 识别不了）",
        description:
          "Apple Vision 在 Mac 上支持哪些语言、不支持哪些字符（俄文、阿拉伯文、希伯来文、泰文、越南文），以及需要时如何回退到 Tesseract 或云端 OCR。",
        tags: ["Mac OCR", "外语", "翻译", "Apple Vision", "Tesseract", "Apple 翻译", "DeepL"],
      },
      ja: {
        title: "Mac で外国語スクリーンショットを OCR する方法（読めない文字も解説）",
        description:
          "Apple Vision が Mac でサポートする言語、サポート外の文字（キリル・アラビア・ヘブライ・タイ・ベトナム）、そして必要なときに Tesseract やクラウド OCR に切り替える方法。",
        tags: ["Mac OCR", "外国語", "翻訳", "Apple Vision", "Tesseract", "Apple 翻訳", "DeepL"],
      },
      ko: {
        title: "Mac에서 외국어 스크린샷을 OCR하는 방법 (Mac이 못 읽는 문자까지)",
        description:
          "Apple Vision이 Mac에서 지원하는 언어, 지원하지 않는 문자(키릴·아랍·히브리·태국·베트남), 필요할 때 Tesseract나 클라우드 OCR로 대체하는 방법.",
        tags: ["Mac OCR", "외국어", "번역", "Apple Vision", "Tesseract", "Apple 번역", "DeepL"],
      },
    },
  },
];

// CSV escaping: wrap in double quotes, escape inner double quotes by doubling them.
function csvCell(value) {
  const s = String(value ?? "");
  if (s === "") return "";
  if (/[,"\n]/.test(s)) {
    return `"${s.replace(/"/g, '""')}"`;
  }
  return s;
}

function buildRow(spec, locale) {
  const loc = spec.locales[locale];
  const cells = [
    spec.slug,
    locale,
    loc.title,
    loc.description,
    loc.tags.join(";"),
    spec.template,
    // key_facts uses `||` as separator since individual facts often contain
    // inline ASCII semicolons. tags and internal_links keep `;` since they're
    // short single-word values.
    spec.key_facts.join(" || "),
    spec.internal_links.join(";"),
    spec.read_min,
    spec.competitor_name || "",
  ];
  return cells.map(csvCell).join(",");
}

function main() {
  const HEADER =
    "slug,locale,title,description,tags,template,key_facts,internal_links,read_min,competitor_name";
  const rows = [HEADER];
  for (const spec of SPECS) {
    for (const locale of LOCALES) {
      if (!spec.locales[locale]) continue;
      rows.push(buildRow(spec, locale));
    }
  }
  const csv = rows.join("\n") + "\n";
  const out = path.join(PROJECT_ROOT, "topics.csv");
  return writeFile(out, csv).then(() => {
    console.log(
      `✓ ${path.relative(process.cwd(), out)}  (${rows.length - 1} rows)`,
    );
  });
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
