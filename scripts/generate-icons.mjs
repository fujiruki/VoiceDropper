import sharp from 'sharp';
import { readFileSync, writeFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = join(__dirname, '..');
const svgPath = join(root, 'assets', 'icon.svg');
const svgBuffer = readFileSync(svgPath);

const sizes = [16, 32, 48, 64, 128, 256];

async function generatePngs() {
  const pngBuffers = [];
  for (const size of sizes) {
    const buf = await sharp(svgBuffer)
      .resize(size, size)
      .png()
      .toBuffer();
    pngBuffers.push({ size, buf });
  }

  // 256px PNG for web/LP
  const png256 = pngBuffers.find(p => p.size === 256).buf;
  writeFileSync(join(root, 'web', 'assets', 'icon.png'), png256);
  console.log('web/assets/icon.png (256px)');

  // favicon
  const png32 = pngBuffers.find(p => p.size === 32).buf;
  writeFileSync(join(root, 'web', 'assets', 'favicon.png'), png32);
  console.log('web/assets/favicon.png (32px)');

  // ICO (multi-size)
  const icoBuffer = buildIco(pngBuffers.filter(p => [16, 32, 48, 64, 256].includes(p.size)));
  writeFileSync(join(root, 'assets', 'VoiceDropper.ico'), icoBuffer);
  console.log('assets/VoiceDropper.ico');
}

function buildIco(images) {
  const count = images.length;
  const headerSize = 6;
  const entrySize = 16;
  const dataOffset = headerSize + entrySize * count;

  let currentOffset = dataOffset;
  const entries = [];
  for (const img of images) {
    const w = img.size >= 256 ? 0 : img.size;
    const h = w;
    entries.push({ w, h, offset: currentOffset, size: img.buf.length });
    currentOffset += img.buf.length;
  }

  const totalSize = currentOffset;
  const buf = Buffer.alloc(totalSize);

  // ICONDIR header
  buf.writeUInt16LE(0, 0);      // reserved
  buf.writeUInt16LE(1, 2);      // type: ICO
  buf.writeUInt16LE(count, 4);  // count

  // ICONDIRENTRY
  for (let i = 0; i < count; i++) {
    const off = headerSize + i * entrySize;
    const e = entries[i];
    buf.writeUInt8(e.w, off);
    buf.writeUInt8(e.h, off + 1);
    buf.writeUInt8(0, off + 2);   // palette
    buf.writeUInt8(0, off + 3);   // reserved
    buf.writeUInt16LE(1, off + 4);  // planes
    buf.writeUInt16LE(32, off + 6); // bpp
    buf.writeUInt32LE(e.size, off + 8);
    buf.writeUInt32LE(e.offset, off + 12);
  }

  // Image data
  for (let i = 0; i < count; i++) {
    images[i].buf.copy(buf, entries[i].offset);
  }

  return buf;
}

generatePngs().then(() => console.log('Done!')).catch(e => { console.error(e); process.exit(1); });
