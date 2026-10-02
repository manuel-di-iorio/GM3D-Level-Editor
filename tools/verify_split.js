// Verifies split_gml moves: every moved function defined exactly once.
const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");
const root = path.join(__dirname, "..");
const plan = fs.readFileSync(path.join(__dirname, "split_gml.js"), "utf8");
const moves = [];
{
  const re = /to: "([^"]+)", (?:append: true, )?fns: \[([\s\S]*?)\]/g;
  let mm;
  while ((mm = re.exec(plan)) !== null) moves.push([mm[0], mm[1], mm[2]]);
}
let bad = 0, total = 0;
const files = [];
(function walk(d) {
  for (const e of fs.readdirSync(d, { withFileTypes: true })) {
    const p = path.join(d, e.name);
    if (e.isDirectory()) walk(p);
    else if (e.name.endsWith(".gml")) files.push(p);
  }
})(path.join(root, "scripts"));
const src = files.map((f) => fs.readFileSync(f, "utf8")).join("\n");
for (const [, to, list] of moves) {
  const fns = [];
  {
    const fr = /"([A-Za-z_][A-Za-z_0-9]*)"/g;
    let fm;
    while ((fm = fr.exec(list)) !== null) fns.push(fm[1]);
  }
  console.log(to + ": " + fns.length);
  for (const n of fns) {
    total++;
    const re = new RegExp("^function " + n + "\\(", "gm");
    const c = (src.match(re) || []).length;
    if (c !== 1) {
      console.log("BAD " + n + " = " + c);
      bad++;
    }
  }
}
// brace balance on touched files
const touched = new Set(["scripts/gm3d_ed_registry/gm3d_ed_registry.gml"]);
for (const [, to] of moves) touched.add("scripts/" + to);
for (const [,] of [[0]]) {}
const extra = [
  "scripts/gm3d_ed_registry/gm3d_ed_registry.gml",
  "scripts/gm3d_ed_gizmo/gm3d_ed_gizmo.gml",
  "scripts/gm3d_ed_imgui/gm3d_ed_imgui.gml",
  "scripts/gm3d_ed_scene_ops/gm3d_ed_scene_ops.gml",
  "scripts/gm3d_ed_serialize/gm3d_ed_serialize.gml",
  "scripts/gm3d_ed_core/gm3d_ed_core.gml",
  "scripts/gm3d_ed_input/gm3d_ed_input.gml",
  "scripts/gm3d_ed_props/gm3d_ed_props.gml",
  "scripts/gm3d_ed_gizmo_draw/gm3d_ed_gizmo_draw.gml",
  "scripts/gm3d_ed_imgui_assets/gm3d_ed_imgui_assets.gml",
  "scripts/gm3d_ed_stage/gm3d_ed_stage.gml",
  "scripts/gm3d_load/gm3d_load.gml",
  "scripts/gm3d_ed_files/gm3d_ed_files.gml",
];
for (const f of extra) {
  const t = fs.readFileSync(path.join(root, f), "utf8");
  let o = 0, c = 0, instr = false;
  for (let i = 0; i < t.length; i++) {
    const ch = t[i];
    if (instr) {
      if (ch === "\\") { i++; continue; }
      if (ch === '"') instr = false;
      continue;
    }
    if (ch === '"') { instr = true; continue; }
    if (ch === "{") o++;
    if (ch === "}") c++;
  }
  if (o !== c) {
    console.log("UNBALANCED " + f + " " + o + "/" + c);
    bad++;
  }
}
console.log("total=" + total + " bad=" + bad);
