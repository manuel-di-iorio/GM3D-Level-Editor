// Generates datafiles/__PolygonEditor__/models/sphere.glb : UV sphere r=1 for material previews.
// Layout mirrors the working editor files (COLOR_0 + placeholder material,
// min/max on every accessor). Tangents included: T=(-sin ph,0,cos ph), w=-1.
const fs = require("fs");
const path = require("path");
const LON = 16,
  LAT = 8;
const pos = [],
  nrm = [],
  uv = [],
  tan = [],
  col = [],
  idx = [];
const pushV = (x, y, z, u, v, tx, tz) => {
  const l = Math.sqrt(x * x + y * y + z * z) || 1;
  pos.push(x, y, z);
  nrm.push(x / l, y / l, z / l);
  uv.push(u, v);
  tan.push(tx, 0, tz, -1);
  return pos.length / 3 - 1;
};
const NP = pushV(0, 1, 0, 0.5, 1, 1, 0);
const rings = [];
for (let j = 1; j < LAT; j++) {
  const th = (j / LAT) * Math.PI;
  const st = Math.sin(th),
    ct = Math.cos(th);
  const ring = [];
  for (let i = 0; i <= LON; i++) {
    const ph = (i / LON) * Math.PI * 2;
    const sp = Math.sin(ph),
      cp = Math.cos(ph);
    ring.push(pushV(st * cp, ct, st * sp, i / LON, 1 - j / LAT, -sp, cp));
  }
  rings.push(ring);
}
const SP = pushV(0, -1, 0, 0.5, 0, 1, 0);
for (let i = 0; i < LON; i++) idx.push(NP, rings[0][i + 1], rings[0][i]);
for (let j = 0; j < rings.length - 1; j++) {
  const r0 = rings[j],
    r1 = rings[j + 1];
  for (let i = 0; i < LON; i++) {
    const a = r0[i],
      b = r0[i + 1],
      c = r1[i],
      d = r1[i + 1];
    idx.push(a, b, c, b, d, c);
  }
}
{
  const rl = rings[rings.length - 1];
  for (let i = 0; i < LON; i++) idx.push(SP, rl[i], rl[i + 1]);
}
for (let v = 0; v < pos.length / 3; v++) col.push(1, 1, 1, 1);
const f32 = (a) => Buffer.from(new Float32Array(a).buffer);
const u16 = (a) => Buffer.from(new Uint16Array(a).buffer);
const bPos = f32(pos),
  bNrm = f32(nrm),
  bUv = f32(uv),
  bTan = f32(tan),
  bCol = f32(col),
  bIdx = u16(idx);
const bin = Buffer.concat([bPos, bNrm, bUv, bTan, bCol, bIdx]);
const off = {
  pos: 0,
  nrm: bPos.length,
  uv: bPos.length + bNrm.length,
  tan: bPos.length + bNrm.length + bUv.length,
  col: bPos.length + bNrm.length + bUv.length + bTan.length,
  idx: bPos.length + bNrm.length + bUv.length + bTan.length + bCol.length,
};
const acc = (view, comp, count, type, min, max) => {
  const a = { bufferView: view, componentType: comp, count, type };
  if (min) {
    a.min = min;
    a.max = max;
  }
  return a;
};
const mm = (arr, stride) => {
  const mn = [],
    mx = [];
  for (let k = 0; k < stride; k++) {
    mn.push(Infinity);
    mx.push(-Infinity);
  }
  for (let i = 0; i < arr.length; i += stride) {
    for (let k = 0; k < stride; k++) {
      if (arr[i + k] < mn[k]) mn[k] = arr[i + k];
      if (arr[i + k] > mx[k]) mx[k] = arr[i + k];
    }
  }
  return [mn, mx];
};
const idxMax = idx.reduce((m, v) => (v > m ? v : m), 0);
const json = {
  asset: { version: "2.0", generator: "gm3d-sphere-gen" },
  scene: 0,
  scenes: [{ nodes: [0] }],
  nodes: [{ mesh: 0, name: "Sphere" }],
  meshes: [
    {
      name: "Sphere",
      primitives: [
        {
          attributes: {
            POSITION: 0,
            NORMAL: 1,
            TEXCOORD_0: 2,
            TANGENT: 3,
            COLOR_0: 4,
          },
          indices: 5,
          material: 0,
          mode: 4,
        },
      ],
    },
  ],
  materials: [
    {
      name: "SpherePreview",
      doubleSided: true,
      pbrMetallicRoughness: {
        baseColorFactor: [1, 1, 1, 1],
        metallicFactor: 0,
        roughnessFactor: 0.9,
      },
    },
  ],
  accessors: [
    acc(0, 5126, pos.length / 3, "VEC3", [-1, -1, -1], [1, 1, 1]),
    acc(1, 5126, nrm.length / 3, "VEC3", ...mm(nrm, 3)),
    acc(2, 5126, uv.length / 2, "VEC2", ...mm(uv, 2)),
    acc(3, 5126, tan.length / 4, "VEC4", ...mm(tan, 4)),
    acc(4, 5126, col.length / 4, "VEC4", ...mm(col, 4)),
    acc(5, 5123, idx.length, "SCALAR", [0], [idxMax]),
  ],
  bufferViews: [
    { buffer: 0, byteOffset: off.pos, byteLength: bPos.length, target: 34962 },
    { buffer: 0, byteOffset: off.nrm, byteLength: bNrm.length, target: 34962 },
    { buffer: 0, byteOffset: off.uv, byteLength: bUv.length, target: 34962 },
    { buffer: 0, byteOffset: off.tan, byteLength: bTan.length, target: 34962 },
    { buffer: 0, byteOffset: off.col, byteLength: bCol.length, target: 34962 },
    { buffer: 0, byteOffset: off.idx, byteLength: bIdx.length, target: 34963 },
  ],
  buffers: [{ byteLength: bin.length }],
};
const jstr = Buffer.from(JSON.stringify(json), "utf8");
const jpad = (4 - (jstr.length % 4)) % 4;
const jsonPad = Buffer.concat([jstr, Buffer.alloc(jpad, 0x20)]);
const total =
  12 + 8 + jsonPad.length + 8 + bin.length + ((4 - (bin.length % 4)) % 4);
const glb = Buffer.alloc(total);
let o = 0;
glb.writeUInt32LE(0x46546c67, o);
o += 4;
glb.writeUInt32LE(2, o);
o += 4;
glb.writeUInt32LE(total, o);
o += 4;
glb.writeUInt32LE(jsonPad.length, o);
o += 4;
glb.writeUInt32LE(0x4e4f534a, o);
o += 4;
jsonPad.copy(glb, o);
o += jsonPad.length;
const bpad = (4 - (bin.length % 4)) % 4;
glb.writeUInt32LE(bin.length + bpad, o);
o += 4;
glb.writeUInt32LE(0x004e4942, o);
o += 4;
bin.copy(glb, o);
const out = path.join(
  __dirname,
  "..",
  "..",
  "datafiles",
  "__PolygonEditor__/models/sphere.glb"
);
fs.writeFileSync(out, glb);
console.log(
  "wrote",
  out,
  total,
  "bytes;",
  pos.length / 3,
  "verts,",
  idx.length / 3,
  "tris"
);
const back = fs.readFileSync(out);
const jl = back.readUInt32LE(12);
const jo = JSON.parse(back.subarray(20, 20 + jl).toString("utf8"));
console.log(
  "attrs:",
  JSON.stringify(jo.meshes[0].primitives[0].attributes),
  "| accessors:",
  jo.accessors.length
);
