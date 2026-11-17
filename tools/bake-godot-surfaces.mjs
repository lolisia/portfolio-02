// Reuse the web recipes verbatim. No browser or canvas dependency is needed
// for surfaces.js's pixel textures. Run: node tools/bake-godot-surfaces.mjs
import fs from 'node:fs';
import zlib from 'node:zlib';
import * as T from 'three';

function crc32(data) {
  let crc = -1;
  for (const b of data) {
    crc ^= b;
    for (let i = 0; i < 8; i++) crc = (crc >>> 1) ^ (0xedb88320 & -(crc & 1));
  }
  return (crc ^ -1) >>> 0;
}
function chunk(type, data) {
  const body = Buffer.concat([Buffer.from(type), data]);
  const head = Buffer.alloc(4), tail = Buffer.alloc(4);
  head.writeUInt32BE(data.length); tail.writeUInt32BE(crc32(body));
  return Buffer.concat([head, body, tail]);
}
function png(canvas, path) {
  const { width: w, height: h, pixels } = canvas;
  const rows = Buffer.alloc(h * (w * 4 + 1));
  for (let y = 0; y < h; y++) Buffer.from(pixels.buffer).copy(rows, y * (w * 4 + 1) + 1, y * w * 4, (y + 1) * w * 4);
  const header = Buffer.alloc(13);
  header.writeUInt32BE(w); header.writeUInt32BE(h, 4); header[8] = 8; header[9] = 6;
  fs.writeFileSync(path, Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]), chunk('IHDR', header), chunk('IDAT', zlib.deflateSync(rows)), chunk('IEND', Buffer.alloc(0))]));
}
globalThis.document = { createElement: () => {
  const canvas = { width: 0, height: 0 };
  canvas.getContext = () => ({
    createImageData: (w, h) => ({ data: new Uint8ClampedArray(w * h * 4) }),
    putImageData: image => { canvas.pixels = image.data; },
  });
  return canvas;
}};
const { surface, field } = await import('../src/surfaces.js');
const out = new URL('../godot/assets/textures/', import.meta.url);
fs.mkdirSync(out, { recursive: true });
for (const name of ['stone', 'clay', 'bark', 'wood', 'plaster']) {
  const mat = surface(name);
  png(mat.map.image, new URL(`${name}_albedo.png`, out));
  png(mat.normalMap.image, new URL(`${name}_normal.png`, out));
}
const coarse = field(5, 722), fine = field(27, 998);
const cloud = { width: 256, height: 256, pixels: new Uint8ClampedArray(256 * 256 * 4) };
for (let y = 0; y < 256; y++) for (let x = 0; x < 256; x++) {
  const u = x / 256, v = y / 256, k = (y * 256 + x) * 4;
  const n = 255 * (.60 * coarse(u,v) + .25 * coarse(2*u,2*v) + .12 * coarse(4*u,4*v) + .03 * fine(u,v));
  cloud.pixels.set([n,n,n,255], k);
}
png(cloud, new URL('web_cloud.png', out));

// cascade.js uses a unit-radius displaced dodecahedron, not a .52 sphere.
const rock = new T.DodecahedronGeometry(1, 1), pos = rock.attributes.position;
for (let i = 0; i < pos.count; i++) {
  const x = pos.getX(i), y = pos.getY(i), z = pos.getZ(i);
  const d = 1 + .12 * Math.sin(4 * x + z) * Math.cos(5 * z - y);
  pos.setXYZ(i, x * d, y * d, z * d);
}
rock.computeVertexNormals();
function writeRock(mesh, filename) {
  const pos = mesh.attributes.position, normals = mesh.attributes.normal;
  const lines = ['# Baked from web Three.js geometry'];
  for (let i = 0; i < pos.count; i++) lines.push(`v ${pos.getX(i)} ${pos.getY(i)} ${pos.getZ(i)}`);
  for (let i = 0; i < pos.count; i++) lines.push(`vn ${normals.getX(i)} ${normals.getY(i)} ${normals.getZ(i)}`);
  for (let i = 0; i < pos.count; i += 3) lines.push(`f ${i+1}//${i+1} ${i+2}//${i+2} ${i+3}//${i+3}`);
  fs.writeFileSync(new URL('../godot/assets/models/' + filename, import.meta.url), lines.join('\n') + '\n');
}
writeRock(rock, 'cascade_rock.obj');
writeRock(new T.DodecahedronGeometry(.52), 'field_rock.obj');
console.log('Baked stone, clay, bark, clouds and rock meshes from web sources.');
