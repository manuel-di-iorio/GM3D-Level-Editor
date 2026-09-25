// Generates datafiles/grid.glb: a single large quad at Y=0; the grid lines
// themselves are procedural in the sGrid fragment shader (Unity-style:
// per-pixel lines with fwidth anti-aliasing + distance fade, so distant
// lines can never shimmer). No line geometry, no pillars, no axes.
// Run: node tools/make_grid_glb.js
// The node is named __editor_grid so the editor can always recognize it:
// scene nodes have no stable identity across getNodes() calls.
var fs = require("fs");
var path = require("path");

var GRID_NODE_NAME = "__editor_grid";
var HALF = 300; // must cover the horizon fade (150..280) with margin

var C_WHITE = [1.0, 1.0, 1.0, 1.0];

var positions = [];
var normals = [];
var uvs = [];
var colors = [];
var indices = [];

function pushVert(x, y, z, c) {
	positions.push(x, y, z);
	normals.push(0, 1, 0);
	uvs.push(0, 0);
	colors.push(c[0], c[1], c[2], c[3]);
	return positions.length / 3 - 1;
}

function pushQuad(a, b, c, d) {
	indices.push(a, b, c, a, c, d);
}

// The whole grid: one quad, lines come from the shader.
(function gridQuad() {
	var a = pushVert(-HALF, 0, -HALF, C_WHITE);
	var b = pushVert(HALF, 0, -HALF, C_WHITE);
	var c = pushVert(HALF, 0, HALF, C_WHITE);
	var d = pushVert(-HALF, 0, HALF, C_WHITE);
	pushQuad(a, b, c, d);
})();

var vCount = positions.length / 3;
var iCount = indices.length;

function minmax(arr, dim) {
	var mn = [];
	var mx = [];
	var n = arr.length / dim;
	for (var k = 0; k < dim; k++) {
		mn.push(Infinity);
		mx.push(-Infinity);
	}
	for (var v = 0; v < n; v++) {
		for (var k = 0; k < dim; k++) {
			var val = arr[v * dim + k];
			if (val < mn[k]) mn[k] = val;
			if (val > mx[k]) mx[k] = val;
		}
	}
	return [mn, mx];
}

var posMM = minmax(positions, 3);
var nrmMM = minmax(normals, 3);
var uvMM = minmax(uvs, 2);
var colMM = minmax(colors, 4);

var posBytes = vCount * 3 * 4;
var nrmBytes = vCount * 3 * 4;
var uvBytes = vCount * 2 * 4;
var colBytes = vCount * 4 * 4;
var idxBytes = iCount * 2;

var binLen = posBytes + nrmBytes + uvBytes + colBytes + idxBytes;
var bin = Buffer.alloc(binLen);
var off = 0;
var v;
for (v = 0; v < positions.length; v++) {
	bin.writeFloatLE(positions[v], off);
	off += 4;
}
for (v = 0; v < normals.length; v++) {
	bin.writeFloatLE(normals[v], off);
	off += 4;
}
for (v = 0; v < uvs.length; v++) {
	bin.writeFloatLE(uvs[v], off);
	off += 4;
}
for (v = 0; v < colors.length; v++) {
	bin.writeFloatLE(colors[v], off);
	off += 4;
}
for (v = 0; v < indices.length; v++) {
	bin.writeUInt16LE(indices[v], off);
	off += 2;
}

var gltf = {
	asset: { version: "2.0", generator: "GM3D_Editor make_grid_glb" },
	scene: 0,
	scenes: [{ nodes: [0], name: "GridScene" }],
	nodes: [{ mesh: 0, name: GRID_NODE_NAME }],
	meshes: [
		{
			name: "GridMesh",
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
			name: "GridMat",
			doubleSided: true,
			pbrMetallicRoughness: {
				baseColorFactor: [1, 1, 1, 1],
				metallicFactor: 0.0,
				roughnessFactor: 0.9,
			},
		},
	],
	accessors: [
		{ bufferView: 0, componentType: 5126, count: vCount, type: "VEC3", min: posMM[0], max: posMM[1] },
		{ bufferView: 1, componentType: 5126, count: vCount, type: "VEC3", min: nrmMM[0], max: nrmMM[1] },
		{ bufferView: 2, componentType: 5126, count: vCount, type: "VEC2", min: uvMM[0], max: uvMM[1] },
		{ bufferView: 3, componentType: 5126, count: vCount, type: "VEC4", min: colMM[0], max: colMM[1] },
		{ bufferView: 4, componentType: 5123, count: iCount, type: "SCALAR", min: [0], max: [vCount - 1] },
	],
	bufferViews: [
		{ buffer: 0, byteOffset: 0, byteLength: posBytes, target: 34962 },
		{ buffer: 0, byteOffset: posBytes, byteLength: nrmBytes, target: 34962 },
		{ buffer: 0, byteOffset: posBytes + nrmBytes, byteLength: uvBytes, target: 34962 },
		{ buffer: 0, byteOffset: posBytes + nrmBytes + uvBytes, byteLength: colBytes, target: 34962 },
		{ buffer: 0, byteOffset: posBytes + nrmBytes + uvBytes + colBytes, byteLength: idxBytes, target: 34963 },
	],
	buffers: [{ byteLength: binLen }],
};

var jsonStr = JSON.stringify(gltf);
var jsonPad = (4 - (jsonStr.length % 4)) % 4;
var jsonBuf = Buffer.concat([Buffer.from(jsonStr, "utf8"), Buffer.alloc(jsonPad, 0x20)]);

var total = 12 + 8 + jsonBuf.length + 8 + bin.length;
var out = Buffer.alloc(total);
var o = 0;
out.writeUInt32LE(0x46546c67, o); o += 4; // 'glTF'
out.writeUInt32LE(2, o); o += 4;
out.writeUInt32LE(total, o); o += 4;
out.writeUInt32LE(jsonBuf.length, o); o += 4;
out.writeUInt32LE(0x4e4f534a, o); o += 4; // 'JSON'
jsonBuf.copy(out, o); o += jsonBuf.length;
out.writeUInt32LE(bin.length, o); o += 4;
out.writeUInt32LE(0x004e4942, o); o += 4; // 'BIN\0'
bin.copy(out, o); o += bin.length;

var outPath = path.join(__dirname, "..", "datafiles", "grid.glb");
fs.writeFileSync(outPath, out);
console.log("wrote " + outPath + " verts=" + vCount + " tris=" + iCount / 3 + " bytes=" + total);
