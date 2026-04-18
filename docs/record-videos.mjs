import { chromium } from 'playwright';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';
import { mkdirSync, rmSync } from 'fs';
import { execSync } from 'child_process';

const __dirname = dirname(fileURLToPath(import.meta.url));

const scenes = [
  { file: 'video-scene3.html', width: 1920, height: 1080, output: 'scene3-landscape-4k' },
  { file: 'video-scene6.html', width: 1920, height: 1080, output: 'scene6-landscape-4k' },
];
// viewport = CSS pixels (matches HTML body size)
// deviceScaleFactor = 2 → screenshots are 2x resolution (3840x2160 / 2160x3840)

const FPS = 60;
const DURATION_S = 6;
const TOTAL_FRAMES = FPS * DURATION_S; // 360 frames
const outputDir = resolve(__dirname, 'videos');

async function record() {
  mkdirSync(outputDir, { recursive: true });

  const browser = await chromium.launch();

  for (const scene of scenes) {
    console.log(`\nRecording ${scene.output} (${scene.width}x${scene.height} @${FPS}fps, 2x retina)...`);

    const framesDir = resolve(outputDir, `_frames_${scene.output}`);
    mkdirSync(framesDir, { recursive: true });

    const context = await browser.newContext({
      viewport: { width: scene.width, height: scene.height },
      deviceScaleFactor: 2,  // 2x retina for crisp rendering
    });

    const page = await context.newPage();
    const url = `file://${resolve(__dirname, scene.file)}`;
    await page.goto(url, { waitUntil: 'load' });

    // Wait for CDN scripts (QR code) to load
    await page.waitForTimeout(2000);

    // Reload to replay animations from the beginning
    await page.reload({ waitUntil: 'load' });

    // Small delay to ensure page is ready
    await page.waitForTimeout(100);

    // Capture frames
    const intervalMs = 1000 / FPS; // ~16.67ms per frame
    for (let i = 0; i < TOTAL_FRAMES; i++) {
      const framePath = resolve(framesDir, `frame_${String(i).padStart(4, '0')}.png`);
      await page.screenshot({ path: framePath });

      if (i % 60 === 0) {
        process.stdout.write(`  Frame ${i}/${TOTAL_FRAMES} (${Math.round(i/TOTAL_FRAMES*100)}%)\r`);
      }

      // Wait for the next frame timing
      // Using page.waitForTimeout for animation sync
      await page.waitForTimeout(intervalMs);
    }
    console.log(`  Captured ${TOTAL_FRAMES} frames                    `);

    await context.close();

    // Compile frames to MP4 with ffmpeg
    const mp4Path = resolve(outputDir, `${scene.output}.mp4`);
    console.log(`  Encoding MP4...`);
    execSync(
      `ffmpeg -y -framerate ${FPS} -i "${framesDir}/frame_%04d.png" ` +
      `-vf "scale=${scene.width * 2}:${scene.height * 2}:flags=lanczos" ` +
      `-c:v libx264 -pix_fmt yuv420p -preset slow -crf 14 ` +
      `"${mp4Path}"`,
      { stdio: 'pipe' }
    );
    console.log(`  Saved: videos/${scene.output}.mp4`);

    // Clean up frames
    rmSync(framesDir, { recursive: true, force: true });
  }

  await browser.close();
  console.log('\nAll done! High-quality videos are in docs/videos/');
}

record().catch(console.error);
