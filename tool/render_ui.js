// Draws the menu art (tool/ui_art/*.svg) as PNG files in game/textures/ui/,
// which Godot imports as textures for the menus.
//   node tool/render_ui.js      (needs Playwright with Chromium)
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const SRC = path.join(__dirname, 'ui_art');
const DIR = path.join(__dirname, '..', 'game', 'textures', 'ui');
// Width in pixels to draw at; icons at 128 are scaled down in the game.
const WIDTH = { mohalla: 1080, title_art: 1080, bunting: 1080, band: 104, rahim: 256, monir: 256, babu: 256, julekha: 256, ratul: 256, kashem: 256 };

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage();
  for (const file of fs.readdirSync(SRC).filter((f) => f.endsWith('.svg')).sort()) {
    const name = file.slice(0, -4);
    const svg = fs.readFileSync(path.join(SRC, file), 'utf8');
    const w0 = Number(/width="(\d+)"/.exec(svg)[1]);
    const h0 = Number(/height="(\d+)"/.exec(svg)[1]);
    const w = WIDTH[name] || 128;
    const h = Math.round((h0 * w) / w0);
    const sized = svg.replace(/width="\d+"/, `width="${w}"`).replace(/height="\d+"/, `height="${h}"`);
    await page.setViewportSize({ width: w, height: h });
    await page.setContent(`<html><body style="margin:0;background:transparent">${sized}</body></html>`);
    await page.screenshot({ path: path.join(DIR, name + '.png'), omitBackground: true, clip: { x: 0, y: 0, width: w, height: h } });
  }
  await browser.close();
})();
