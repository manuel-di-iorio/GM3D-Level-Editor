// Organizes scripts into IDE subfolders (one-shot).
// Usage: node tools/organize_folders.js
const fs = require("fs");
const path = require("path");
const root = path.join(__dirname, "..");

const folders = ["Core", "Scene", "Viewport"];
const parentOf = {
  gm3d_ed_core: "Core",
  gm3d_ed_files: "Core",
  gm3d_ed_input: "Core",
  gm3d_ed_math: "Core",
  gm3d_ed_shaders: "Core",
  gm3d_ed_registry: "Scene",
  gm3d_ed_props: "Scene",
  gm3d_ed_scene_ops: "Scene",
  gm3d_ed_scene_walk: "Scene",
  gm3d_ed_stage: "Scene",
  gm3d_ed_serialize: "Scene",
  gm3d_load: "Scene",
  gm3d_ed_history: "Scene",
  gm3d_ed_camera: "Viewport",
  gm3d_ed_viewport: "Viewport",
  gm3d_ed_viewcube: "Viewport",
  gm3d_ed_overlay: "Viewport",
  gm3d_ed_outline: "Viewport",
  gm3d_ed_gpu_pick: "Viewport",
  imgui_enums: "ImGUI",
};

for (const [name, folder] of Object.entries(parentOf)) {
  const p = path.join(root, "scripts", name, name + ".yy");
  const raw = fs.readFileSync(p, "utf8");
  const eol = raw.indexOf("\r\n") >= 0 ? "\r\n" : "\n";
  const lines = raw.split(eol);
  const idx = lines.findIndex((l) => l.trim() === '"parent":{');
  if (idx < 0 || lines[idx + 1].indexOf('"name"') < 0 || lines[idx + 2].indexOf('"path"') < 0) {
    throw new Error("parent anchor missing in " + name);
  }
  lines[idx + 1] = '    "name":"' + folder + '",';
  lines[idx + 2] = '    "path":"folders/GM3D Level Editor/' + folder + '.yy",';
  fs.writeFileSync(p, lines.join(eol));
  console.log(name + " -> " + folder);
}

let yyp = fs.readFileSync(path.join(root, "GM3D-Level-Editor.yyp"), "utf8");
const anchor =
  '{"$GMFolder":"","%Name":"ImGUI","folderPath":"folders/GM3D Level Editor/ImGUI.yy","name":"ImGUI","resourceType":"GMFolder","resourceVersion":"2.0",},';
if (yyp.indexOf(anchor) < 0) throw new Error("yyp folders anchor missing");
const add = folders
  .map(
    (f) =>
      '\n    {"$GMFolder":"","%Name":"' +
      f +
      '","folderPath":"folders/GM3D Level Editor/' +
      f +
      '.yy","name":"' +
      f +
      '","resourceType":"GMFolder","resourceVersion":"2.0",},'
  )
  .join("");
yyp = yyp.replace(anchor, anchor + add);
fs.writeFileSync(path.join(root, "GM3D-Level-Editor.yyp"), yyp);
console.log("folders registered");
