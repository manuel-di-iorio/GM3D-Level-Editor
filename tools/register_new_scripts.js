// Registers new script resources in .yyp and .resource_order (one-shot).
// Usage: node tools/register_new_scripts.js
const fs = require("fs");
const path = require("path");
const root = path.join(__dirname, "..");
const scripts = [
  ["gm3d_ed_props", 19],
  ["gm3d_ed_gizmo_draw", 20],
  ["gm3d_ed_imgui_assets", 21],
  ["gm3d_ed_stage", 22],
  ["gm3d_load", 23],
  ["gm3d_ed_files", 24],
];
let yyp = fs.readFileSync(path.join(root, "GM3D-Level-Editor.yyp"), "utf8");
const yAnchor = '    {"id":{"name":"sprGM3DIconPointLight","path":"sprites/sprGM3DIconPointLight/sprGM3DIconPointLight.yy",},},';
if (yyp.indexOf(yAnchor) < 0) throw new Error("yyp anchor missing");
const yAdd = scripts.map(([n]) => '\n    {"id":{"name":"' + n + '","path":"scripts/' + n + '/' + n + '.yy",},},').join("");
yyp = yyp.replace(yAnchor, yAnchor + yAdd);
fs.writeFileSync(path.join(root, "GM3D-Level-Editor.yyp"), yyp);
let ord = fs.readFileSync(path.join(root, "GM3D-Level-Editor.resource_order"), "utf8");
const oAnchor = '    {"name":"sprGM3DIconPointLight","order":3,"path":"sprites/sprGM3DIconPointLight/sprGM3DIconPointLight.yy",},';
if (ord.indexOf(oAnchor) < 0) throw new Error("order anchor missing");
const oAdd = scripts.map(([n, o]) => '\n    {"name":"' + n + '","order":' + o + ',"path":"scripts/' + n + '/' + n + '.yy",},').join("");
ord = ord.replace(oAnchor, oAnchor + oAdd);
fs.writeFileSync(path.join(root, "GM3D-Level-Editor.resource_order"), ord);
console.log("registered " + scripts.length);
