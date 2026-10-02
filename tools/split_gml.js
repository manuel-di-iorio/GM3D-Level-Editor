// Splits oversized GML modules by moving whole functions to new/existing scripts.
// Usage: node tools/split_gml.js
// GML functions are project-global, so moves are behavior-preserving as long as
// every function exists exactly once afterwards (verified by re-running grep).
const fs = require("fs");
const path = require("path");
const root = path.join(__dirname, "..", "scripts");

const moves = [
  { from: "gm3d_ed_registry/gm3d_ed_registry.gml", to: "gm3d_ed_props/gm3d_ed_props.gml", fns: [
    "__gm3d_ed_light_defaults", "__gm3d_ed_camera_defaults", "__gm3d_ed_env_defaults",
    "__gm3d_ed_comp_get", "__gm3d_ed_light_type_to_str", "__gm3d_ed_light_type_to_enum",
    "__gm3d_ed_cam_proj_to_str", "__gm3d_ed_cam_proj_to_enum",
    "__gm3d_ed_light_read", "__gm3d_ed_light_apply", "__gm3d_ed_shadow_warn",
    "__gm3d_ed_shadowpreview_apply", "__gm3d_ed_camera_read", "__gm3d_ed_camera_apply",
    "__gm3d_ed_env_read", "__gm3d_ed_env_apply",
    "__gm3d_ed_track_light", "__gm3d_ed_track_camera",
    "__gm3d_ed_gamecam_resolve", "__gm3d_ed_gamecam_ensure",
    "__gm3d_ed_track_env", "__gm3d_ed_create_light", "__gm3d_ed_create_camera",
    "__gm3d_ed_create_env", "__gm3d_ed_env_node",
    "__gm3d_ed_cameras_mute", "__gm3d_ed_cameras_restore",
  ]},
  { from: "gm3d_ed_gizmo/gm3d_ed_gizmo.gml", to: "gm3d_ed_gizmo_draw/gm3d_ed_gizmo_draw.gml", fns: [
    "__gm3d_ed_gizmo_draw", "__gm3d_ed_gizmo_draw_selboxes",
    "__gm3d_ed_gizmo_draw_translate_quads", "__gm3d_ed_gizmo_draw_axes",
    "__gm3d_ed_gizmo_draw_viewring", "__gm3d_ed_gizmo_draw_center",
    "__gm3d_ed_gizmo_draw_rotate_sweep", "__gm3d_ed_gizmo_draw_trail",
    "__gm3d_ed_arrow", "__gm3d_ed_gizmo_shaft", "__gm3d_ed_draw_selbox",
  ]},
  { from: "gm3d_ed_imgui/gm3d_ed_imgui.gml", to: "gm3d_ed_imgui_assets/gm3d_ed_imgui_assets.gml", fns: [
    "__gm3d_ed_imgui_asset_list", "__gm3d_ed_imgui_small_btn", "__gm3d_ed_imgui_small_btn_w",
    "__gm3d_ed_imgui_asset_cards", "__gm3d_ed_imgui_trunc_text", "__gm3d_ed_imgui_asset_card",
  ]},
  { from: "gm3d_ed_scene_ops/gm3d_ed_scene_ops.gml", to: "gm3d_ed_stage/gm3d_ed_stage.gml", fns: [
    "__gm3d_ed_is_grid", "__gm3d_ed_is_sky",
    "__gm3d_ed_grid_ensure", "__gm3d_ed_grid_step_sync", "__gm3d_ed_grid_set_step",
    "__gm3d_ed_grid_bg_sync", "__gm3d_ed_grid_remove", "__gm3d_ed_grid_follow",
    "__gm3d_ed_sky_find", "__gm3d_ed_sky_ensure", "__gm3d_ed_sky_remove",
    "__gm3d_ed_sky_sun_dir", "__gm3d_ed_sky_paint", "__gm3d_ed_sky_sync",
  ]},
  { from: "gm3d_ed_serialize/gm3d_ed_serialize.gml", to: "gm3d_load/gm3d_load.gml", fns: [
    "gm3d_load", "__gm3d_load_node", "__gm3d_load_prop",
    "__gm3d_load_vec3", "__gm3d_load_quat",
  ]},
  { from: "gm3d_ed_core/gm3d_ed_core.gml", to: "gm3d_ed_files/gm3d_ed_files.gml", fns: [
    "__gm3d_ed_save_as", "__gm3d_ed_save_or_ask",
    "__gm3d_ed_confirm_ask", "__gm3d_ed_confirm_do", "__gm3d_ed_load_ask",
    "gm3d_editor_new_scene",
  ]},
  { from: "gm3d_ed_core/gm3d_ed_core.gml", to: "gm3d_ed_input/gm3d_ed_input.gml", append: true, fns: [
    "__gm3d_ed_wrap_begin", "__gm3d_ed_wrap_end", "__gm3d_ed_wrap_step",
    "__gm3d_ed_wrap_camera", "__gm3d_ed_drag_in_viewport",
  ]},
];

function findBlock(lines, name) {
  const starts = [];
  for (let i = 0; i < lines.length; i++) {
    if (lines[i] === "function " + name + "(" || lines[i].startsWith("function " + name + "(")) {
      // exact: "function NAME("
      if (lines[i].slice(0, ("function " + name + "(").length) === "function " + name + "(") starts.push(i);
    }
  }
  if (starts.length !== 1) throw new Error(name + ": found " + starts.length + " definitions");
  let s = starts[0];
  // attach contiguous // comment lines directly above
  while (s > 0 && lines[s - 1].startsWith("//")) s--;
  // brace match from function line
  let depth = 0, seen = false, inStr = false, e = -1;
  outer:
  for (let i = starts[0]; i < lines.length; i++) {
    const ln = lines[i];
    for (let c = 0; c < ln.length; c++) {
      const ch = ln[c];
      if (inStr) {
        if (ch === "\\") { c++; continue; }
        if (ch === '"') {
          if (ln[c + 1] === '"') { c++; continue; }
          inStr = false;
        }
        continue;
      }
      if (ch === '"') { inStr = true; continue; }
      if (ch === "/" && ln[c + 1] === "/") break;
      if (ch === "{") { depth++; seen = true; }
      if (ch === "}") {
        depth--;
        if (seen && depth === 0) { e = i; break outer; }
      }
    }
  }
  if (e < 0) throw new Error(name + ": unbalanced braces");
  return { s, e };
}

for (const m of moves) {
  const fromPath = path.join(root, m.from);
  let lines = fs.readFileSync(fromPath, "utf8").split("\n");
  const blocks = m.fns.map((n) => ({ n, b: findBlock(lines, n) }));
  blocks.sort((a, b) => b.b.s - a.b.s);
  const moved = [];
  for (const { n, b } of blocks) {
    moved.unshift(lines.slice(b.s, b.e + 1).join("\n"));
    lines.splice(b.s, b.e - b.s + 1);
  }
  fs.writeFileSync(fromPath, lines.join("\n"));
  const text = moved.join("\n\n") + "\n";
  const toPath = path.join(root, m.to);
  if (m.append) {
    let cur = fs.readFileSync(toPath, "utf8");
    if (!cur.endsWith("\n")) cur += "\n";
    fs.writeFileSync(toPath, cur + "\n" + text);
  } else {
    fs.mkdirSync(path.dirname(toPath), { recursive: true });
    fs.writeFileSync(toPath, text);
  }
  console.log(m.to + ": +" + moved.length + " fns (" + text.split("\n").length + " lines)");
}
console.log("done");
