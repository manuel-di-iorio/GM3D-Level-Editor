// Generates datafiles/__PolygonEditor__/models/skybox.glb: inside-out UV sphere (node "__skybox").
// Usage: node tools/gen_skybox_glb.js
const fs = require("fs");
const path = require("path");

const R = 4000,
  NX = 32,
  NY = 16;
const pos = [],
  nrm = [],
  uv = [],
  col = [],
  idx = [];
for (let iy = 0; iy <= NY; iy++) {
  const phi = (iy / NY) * Math.PI;
  const sp = Math.sin(phi),
    cp = Math.cos(phi);
  for (let ix = 0; ix <= NX; ix++) {
    const th = (ix / NX) * Math.PI * 2;
    const ct = Math.cos(th),
      st = Math.sin(th);
    const x = R * sp * ct,
      y = R * cp,
      z = R * sp * st;
    pos.push(x, y, z);
    nrm.push(-x / R, -y / R, -z / R);
    uv.push(ix / NX, iy / NY);
    col.push(1, 1, 1, 1);
  }
}
for (let iy = 0; iy < NY; iy++) {
  for (let ix = 0; ix < NX; ix++) {
    const a = iy * (NX + 1) + ix,
      b = a + 1,
      c = a + NX + 1,
      d = c + 1;
    idx.push(a, c, b, b, c, d); // reversed winding => inside-out
  }
}

const vcount = pos.length / 3,
  icount = idx.length;
const posBuf = Buffer.alloc(vcount * 12);
pos.forEach((v, i) => posBuf.writeFloatLE(v, i * 4));
let pmin = [Infinity, Infinity, Infinity],
  pmax = [-Infinity, -Infinity, -Infinity];
for (let i = 0; i < vcount; i++) {
  for (let k = 0; k < 3; k++) {
    const v = pos[i * 3 + k];
    if (v < pmin[k]) pmin[k] = v;
    if (v > pmax[k]) pmax[k] = v;
  }
}
const nrmBuf = Buffer.alloc(vcount * 12);
nrm.forEach((v, i) => nrmBuf.writeFloatLE(v, i * 4));
const uvBuf = Buffer.alloc(vcount * 8);
uv.forEach((v, i) => uvBuf.writeFloatLE(v, i * 4));
const colBuf = Buffer.alloc(vcount * 16);
col.forEach((v, i) => colBuf.writeFloatLE(v, i * 4));
const idxBuf = Buffer.alloc(icount * 2);
idx.forEach((v, i) => idxBuf.writeUInt16LE(v, i * 2));
const bin = Buffer.concat([posBuf, nrmBuf, uvBuf, colBuf, idxBuf]);

const json = JSON.stringify({
  asset: { version: "2.0", generator: "gm3d-skybox" },
  scene: 0,
  scenes: [{ nodes: [0] }],
  nodes: [{ name: "__skybox", mesh: 0 }],
  meshes: [
    {
      name: "SkyMesh",
      primitives: [
        {
          attributes: { POSITION: 0, NORMAL: 1, TEXCOORD_0: 2, COLOR_0: 3 },
          indices: 4,
          material: 0,
          mode: 4,
        },
      ],
    },
  ],
  materials: [
    {
      name: "SkyMat",
      doubleSided: true,
      pbrMetallicRoughness: {
        baseColorFactor: [1, 1, 1, 1],
        metallicFactor: 0,
        roughnessFactor: 0.9,
      },
    },
  ],
  accessors: [
    {
      bufferView: 0,
      componentType: 5126,
      count: vcount,
      type: "VEC3",
      min: pmin,
      max: pmax,
    },
    { bufferView: 1, componentType: 5126, count: vcount, type: "VEC3" },
    { bufferView: 2, componentType: 5126, count: vcount, type: "VEC2" },
    { bufferView: 3, componentType: 5126, count: vcount, type: "VEC4" },
    { bufferView: 4, componentType: 5123, count: icount, type: "SCALAR" },
  ],
  bufferViews: [
    { buffer: 0, byteOffset: 0, byteLength: posBuf.length, target: 34962 },
    {
      buffer: 0,
      byteOffset: posBuf.length,
      byteLength: nrmBuf.length,
      target: 34962,
    },
    {
      buffer: 0,
      byteOffset: posBuf.length + nrmBuf.length,
      byteLength: uvBuf.length,
      target: 34962,
    },
    {
      buffer: 0,
      byteOffset: posBuf.length + nrmBuf.length + uvBuf.length,
      byteLength: colBuf.length,
      target: 34962,
    },
    {
      buffer: 0,
      byteOffset: posBuf.length + nrmBuf.length + uvBuf.length + colBuf.length,
      byteLength: idxBuf.length,
      target: 34963,
    },
  ],
  buffers: [{ byteLength: bin.length }],
});
const jsonPadded = json + " ".repeat((4 - (json.length % 4)) % 4);
const total = 12 + 8 + Buffer.byteLength(jsonPadded) + 8 + bin.length;
const out = Buffer.alloc(total);
let o = 0;
out.writeUInt32LE(0x46546c67, o);
o += 4; // 'glTF'
out.writeUInt32LE(2, o);
o += 4;
out.writeUInt32LE(total, o);
o += 4;
out.writeUInt32LE(Buffer.byteLength(jsonPadded), o);
o += 4;
out.writeUInt32LE(0x4e4f534a, o);
o += 4; // 'JSON'
o += out.write(jsonPadded, o);
out.writeUInt32LE(bin.length, o);
o += 4;
out.writeUInt32LE(0x004e4942, o);
o += 4; // 'BIN\0'
bin.copy(out, o);

const dest = path.join(
  __dirname,
  "..",
  "datafiles",
  "__gm3deditor/models/skybox.glb"
);
fs.writeFileSync(dest, out);
console.log(
  "wrote " +
    dest +
    " (" +
    total +
    " bytes, " +
    vcount +
    " verts, " +
    icount / 3 +
    " tris)"
);
