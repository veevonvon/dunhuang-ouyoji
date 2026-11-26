import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import { activities, facts, historyEvents, stages } from '../../src/content.ts';
import { chapters, encounters } from '../../src/adventure-data.ts';
import { campNotes, campSpots, campVoices, decorations, defaultCampNotes, letters } from '../../src/camp-data.ts';
import { pigmentColors } from '../../src/state.ts';
import { imageAssets, musicPath, voiceLines, voicePath } from '../../src/canvas/asset-catalog.ts';

const root = resolve(import.meta.dirname, '..');
const original = resolve(root, '..');
const verify = process.argv.includes('--check');
const collections = { stages, activities, facts, historyEvents, chapters, encounters, letters, decorations, campNotes, campVoices, campSpots };
const counts = { stages: 6, activities: 11, facts: 31, historyEvents: 12, chapters: 6, encounters: 18, letters: 3, decorations: 9, campNotes: 6, campVoices: 3, campSpots: 6 };
for (const [key, count] of Object.entries(counts)) assert.equal(collections[key].length, count, `Original ${key} must remain complete`);
const images = Object.fromEntries(Object.entries(imageAssets).map(([id, value]) => [id, `res://assets/images/${id}.${value.alpha ? 'png' : 'jpg'}`]));
const voices = Object.fromEntries(voiceLines.map(({ id }) => [id, `res://assets/voice/${id}.mp3`]));
const tracks = ['map', 'wuwei', 'zhangye', 'jiuquan', 'jiayuguan', 'guazhou', 'dunhuang', 'ending'];
const manifest = [];

async function output(relative, bytes) {
  const target = join(root, relative);
  if (verify) {
    assert.deepEqual(await readFile(target), bytes, `Migrated file differs: ${relative}`);
  } else {
    await mkdir(dirname(target), { recursive: true });
    await writeFile(target, bytes);
  }
}

async function copyAsset(source, target) {
  const relative = `public/canvas/${source}`;
  const bytes = await readFile(join(original, relative));
  assert.ok(bytes.length > 0, `Empty original asset: ${relative}`);
  await output(target, bytes);
  manifest.push({ source: `../${relative}`, path: target, bytes: bytes.length, sha256: createHash('sha256').update(bytes).digest('hex') });
}

for (const [id, image] of Object.entries(imageAssets)) await copyAsset(image.path, images[id].slice('res://'.length));
for (const id of tracks) await copyAsset(musicPath(id), `assets/music/${id}.mp3`);
for (const line of voiceLines) await copyAsset(voicePath(line.id), `assets/voice/${line.id}.mp3`);
for (const voice of campVoices) for (let note = 0; note < 5; note++) await copyAsset(`assets/notes/${voice.id}-${note}.mp3`, `assets/notes/${voice.id}-${note}.mp3`);

const content = { schemaVersion: 1, ...collections, defaultCampNotes, pigmentColors, images, voices, voiceLines };
await output('data/content.json', Buffer.from(`${JSON.stringify(content, null, 2)}\n`));
await output('assets/manifest.json', Buffer.from(`${JSON.stringify({ schemaVersion: 1, source: '原版 TypeScript / Canvas 工程的已优化离线素材，逐字节迁移，未重新编辑', counts: { images: 13, music: 8, notes: 15, voice: voiceLines.length }, files: manifest }, null, 2)}\n`));
console.log(`${verify ? '校验通过' : '迁移完成'}：6 章，18 处发现，31 张知识卡，12 段历史，11 种玩法，3 封问候，9 件摆设；13 幅图片，8 段音乐，15 个音符，${voiceLines.length} 条语音。`);
