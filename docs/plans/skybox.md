# Plan: Skydome Skybox

## Goal
Add a sky background to the demo scene. The GM3D runtime has no native
skybox/cubemap API and no way to build meshes from code, so the sky is a
hand-made skydome integrated like the editor grid: present in the render,
invisible to tracking, save/undo, picking and outline.

## Findings (docs/GM3D.md)
- `GM3D_EnvironmentVolumeComponent` only does ambient color + fog.
- Meshes only come from loaded files (`loadGltf`); no mesh constructor.
- Materials support `setShader(pass, shader)`, `setTexture(name, id)`,
  `setFloat`/`setFloatArray`; custom shaders can ignore lighting and fog.
- Mesh components opt in/out of shadows via `GM3D_EMeshComponentFlags`.

## Design
1. **Geometry**: tiny `datafiles/skybox.glb` (inside-out sphere), loaded
   once with `GM3D_Scene.loadGltf` + `freeze`, spawned once in `demo_create`.
2. **Shader**: new `shGM3DSky` (.vsh/.fsh), unlit. Procedural gradient
   (top / horizon / bottom colors as uniforms) + sun glow from the dot
   with the `Sun` direction. No texture needed; later an equirectangular
   texture can be sampled via `setTexture("u_skyTexture", tex)`.
3. **Camera follow**: each step the sky node copies the camera position
   (`demo_step` and editor frozen step). Radius ~4000, inside far 10000.
   Shadows off via `setFlags(0)`.
4. **Editor integration**: never tracked (save/undo/Scene ignore it by
   construction). Exclude from GPU pick render and outline walk by naming
   the node `__skybox` and extending the `__gm3d_ed_is_grid`-style check
   in both passes (two lines).

## Touch list
- `datafiles/skybox.glb` (new) + project include entry.
- `shaders/shGM3DSky/` (.vsh/.fsh, new) + warmup list entry.
- `scripts/scr_demo/scr_demo.gml`: spawn in `demo_create`, follow in
  `demo_step`, release in `demo_destroy`.
- `scripts/gm3d_ed_gpu_pick/gm3d_ed_gpu_pick.gml`: skip `__skybox` root.
- `scripts/gm3d_ed_outline/gm3d_ed_outline.gml`: skip `__skybox` subtree.

## Non-goals
- Real cubemap support (runtime lacks it).
- Changing window colour / fog behavior (stays as fallback background).
