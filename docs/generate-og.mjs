// Generate docs/og-image.png (1200x630) from docs/og-image.html
// Usage: node docs/generate-og.mjs
import { chromium } from 'playwright';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));

async function main() {
  const browser = await chromium.launch();
  const context = await browser.newContext({
    viewport: { width: 1200, height: 630 },
    deviceScaleFactor: 1,
  });
  const page = await context.newPage();
  const url = `file://${resolve(__dirname, 'og-image.html')}`;
  await page.goto(url, { waitUntil: 'load' });
  await page.waitForTimeout(300);
  await page.screenshot({
    path: resolve(__dirname, 'og-image.png'),
    clip: { x: 0, y: 0, width: 1200, height: 630 },
    type: 'png',
  });
  await browser.close();
  console.log('Wrote docs/og-image.png (1200x630)');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
