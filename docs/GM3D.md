# GM3D in GameMaker

Operational guide to the GMRT runtime 3D module, based on the official project [YoYoGames/GM3D-Samples](https://github.com/YoYoGames/GM3D-Samples) and the reference included in the repository.

## Contents

- [Mental model](#mental-model)
- [Quick start](#quick-start)
- [Lifecycle](#lifecycle)
- [Scenes and nodes](#scenes-and-nodes)
- [Transformations and math](#transformations-and-math)
- [Components](#components)
- [Materials, shaders and textures](#materials-shaders-and-textures)
- [Animation](#animation)
- [Camera and rendering](#camera-and-rendering)
- [Lights, environment and fog](#lights-environment-and-fog)
- [glTF loading and instances](#gltf-loading-and-instances)
- [The four official samples](#the-four-official-samples)
- [Performance and ownership](#performance-and-ownership)
- [API by type](#api-by-type)
- [Documentation limits](#documentation-limits)
- [Sources](#sources)

## Mental model

GM3D is a **scene graph** renderer:

```text
GM3D_Scene
└── GM3D_SceneNode
    ├── local transformation
    ├── child nodes
    └── components
        ├── GM3D_CameraComponent
        ├── GM3D_LightComponent
        ├── GM3D_EnvironmentVolumeComponent
        ├── GM3D_MeshComponent
        ├── GM3D_SkinnedMeshComponent
        └── GM3D_AnimationComponent
```

A `GM3D_Scene` contains nodes. A node defines hierarchy and transformation; components add behavior or renderable content. A `GM3D_Renderer` traverses the scene and draws it using the cameras, lights, materials, and environment present in the graph.

The typical pipeline is:

1. create the scenes live and the renderer;
2. load one or more glTF scenes as source assets;
3. assign the shader to the materials loaded;
4. call `freeze()` on the source asset;
5. create instances with `spawnInto()`;
6. add a camera, light, and environment volume;
7. run `scene.update(delta_seconds)` on every Step;
8. run `renderer.render(scene)` in the Draw event;
9. destroy the live scene and loaded assets in Clean Up.

## Quick start

The `GM3D_*` module is provided by GMRT: the sample repository does not contain an extension to import.

### Create

```gml
#macro DELTA_SECONDS (delta_time * 0.000001)

scene = GM3D_Scene.createEmpty();
renderer = new GM3D_Renderer();
assets = [];

var model = GM3D_Scene.loadGltf("kenney_platformer-kit/tree.glb");

// Every material must use a shader compatible with GM3D.
var materials = model.getMaterials();
for (var i = 0; i < array_length(materials); ++i) {
    materials[i].setShader(sStatic);
}

model.freeze();
array_push(assets, model);

var root = model.spawnInto(scene, undefined);
root.setLocalPosition(new GM3D_Vec3(0, 0, 0));

var camera_node = scene.createNode("Camera");
var camera = new GM3D_CameraComponent();
camera_node.addComponent(camera);
camera.setProjection(GM3D_ECameraProjection.Perspective);
camera.setFovY(degtorad(60));
camera.setNear(0.1);
camera.setFar(1000);
```

### Step

```gml
scene.update(DELTA_SECONDS);
```

`delta_time` is expressed in microseconds; GM3D uses seconds.

### Draw

```gml
renderer.render(scene);
```

### Clean Up

```gml
scene.destroy();

for (var i = 0; i < array_length(assets); ++i) {
    assets[i].destroy();
}

assets = [];
renderer = undefined;
```

## Lifecycle

### Initialization

`GM3D_Scene.createEmpty()` creates the live container. Assets loaded with `GM3D_Scene.loadGltf()` remain separate scenes: `spawnInto(dest, parent)` copies their hierarchy into the destination scene and returns the root node of the new instance.

Do not use the asset scenes directly as the live world when you expect multiple instances. Keep the asset instead and create copies in the main scene.

### Updating

```gml
scene.update(delta_seconds);
```

Updates the graph, transformations and animated components. After structural changes or when a scene has just been created, `scene.update(0.0)` forces synchronization without advancing time.

### Rendering

```gml
renderer.render(scene);
```

The renderer uses the enabled cameras contained in the scene. Multiple cameras can render into different rectangles and in a different order.

### Destruction

Whoever creates a `GM3D_Scene` owns its lifetime. Destroy both the live scene and every loaded asset scene. After `destroy()`, remove application references to avoid accidental reuse.

## Scenes and nodes

### `GM3D_Scene`

Creation and queries:

```gml
var scene = GM3D_Scene.createEmpty();
var asset = GM3D_Scene.loadGltf(path);

var node = scene.createNode("Player");
var by_name = scene.getNode("Player");
var by_index = scene.getNode(0);
var nodes = scene.getNodes();
var names = scene.getNodeNames();
```

Materials and animations:

```gml
var material = asset.getMaterial(0);       // also by name
var materials = asset.getMaterials();
var material_names = asset.getMaterialNames();

var animation = asset.getAnimation(0);    // also by name
var animations = asset.getAnimations();
var animation_names = asset.getAnimationNames();
var exists = asset.hasAnimation(0);
```

Useful read-only properties: `nodeCount`, `materialCount`, `animationCount` and `path`.

### `GM3D_SceneNode`

Hierarchy:

```gml
parent.addChild(child);
var children = parent.getChildren();
child.removeFromParent();
```

Components:

```gml
node.addComponent(component);
node.removeComponent(component);
node.removeAllComponents();

var camera = node.getCameraComponent();
var light = node.getLightComponent();
var environment = node.getEnvironmentVolumeComponent();
var mesh = node.getMeshComponent();
var skinned = node.getSkinnedMeshComponent();
var animation = node.getAnimationComponent();
var animations = node.getAnimationComponents();
```

`getAnimationComponent()` returns the first component on the node, not a recursive search through the entire subtree. The sample implements a recursive helper to find the animator of an imported model.

## Transformations and math

Local transformations are relative to the parent; world transformations derive from the entire hierarchy chain.

```gml
node.setLocalPosition(new GM3D_Vec3(x, y, z));
node.setLocalRotation(GM3D_Quaternion.fromAxisAngle(GM3D_Vec3.up(), angle));
node.setLocalScale(new GM3D_Vec3(sx, sy, sz));

var local_matrix = node.getLocalMatrix();
var world_matrix = node.getWorldMatrix();
var world_position = node.getWorldPosition();
var forward = node.getWorldForward();
var right = node.getWorldRight();
var up = node.getWorldUp();
```

Equivalent getters are available for local and world position, rotation, scale, matrix, and axes.

### Mathematical types

| Type | Main use |
| --- | --- |
| `GM3D_Vec2`, `GM3D_Vec3`, `GM3D_Vec4` | vectors, products, normalization, interpolation and transformations |
| `GM3D_Matrix2`, `GM3D_Matrix3`, `GM3D_Matrix4` | composition, inversion, projection and transformations |
| `GM3D_Quaternion` | robust rotations, `slerp`, axis-angle/Euler/matrix conversion |
| `GM3D_Euler` | angles with configurable rotation order |
| `GM3D_DualQuaternion` | combined rotation and translation, useful for interpolation and skinning |

Common operations:

```gml
var direction = target.subtract(position).normalize();
var rotation = GM3D_Quaternion.fromAxisAngle(GM3D_Vec3.up(), degtorad(yaw));

var matrix = new GM3D_Matrix4();
matrix.compose(position, rotation, scale);
matrix.decompose(out_position, out_rotation, out_scale);
```

Matrices expose `elements` in column-major order. Prefer GM3D methods to native array matrices when working with GM3D nodes and components.

## Components

### Camera

```gml
var component = new GM3D_CameraComponent();
node.addComponent(component);

component.setEnabled(true);
component.setProjection(GM3D_ECameraProjection.Perspective);
component.setFovY(degtorad(60));
component.setNear(0.1);
component.setFar(500);
component.setAspectRatio(16 / 9);
```

For orthographic projection, use `setOrthoWidth()` and `setOrthoHeight()`.

### Light

```gml
var component = new GM3D_LightComponent();
node.addComponent(component);

component.setType(GM3D_ELightType.Directional);
component.setColor(c_white);
component.setIntensity(1.0);
component.setEnabled(true);
```

Point and spot lights also use `setRange()`. Spot lights expose `setInnerConeAngle()` and `setOuterConeAngle()`, in radians.

### Environment volume

```gml
var component = new GM3D_EnvironmentVolumeComponent();
node.addComponent(component);

component.setSize(100, 100, 100);
component.setAmbientColor(make_color_rgb(80, 90, 100));
component.setFogEnabled(true);
component.setFogColor(c_silver);
component.setFogStart(20);
component.setFogEnd(100);
```

The volume is an AABB centered on its node. Size it so that it contains the rendered area.

### Mesh

```gml
var component = new GM3D_MeshComponent(mesh, material);
component.setMesh(mesh);
component.setMaterial(material);
component.setEnabled(true);
```

`GM3D_SkinnedMeshComponent` has the same base interface and adds `jointCount`. `GM3D_Mesh` exposes `isSkinned`, `primitiveType`, `vertexBuffer`, `vertexFormat`, `getBoundingBoxMin()`, and `getBoundingBoxMax()`.

## Materials, shaders and textures

### Shader assignment

glTF files import materials, but the sample explicitly assigns a GameMaker shader to each material before `freeze()`:

```gml
var materials = asset.getMaterials();
for (var i = 0; i < array_length(materials); ++i) {
    materials[i].setShader(sStatic);
}
```

Skinned meshes require the animated shader. The sample distinguishes four variants:

| Geometry | Normal | Instanced |
| --- | --- | --- |
| static | `shStatic` | `shStaticInstanced` |
| skinned | `shAnimated` | `shAnimatedInstanced` |

Shaders are not automatically part of the module: they are GLSL resources from the sample project and show the attributes and uniforms required by the pipeline.

### `GM3D_Material`

```gml
var material = new GM3D_Material("Ground");
material.setShader(sStatic);
material.setTexture("u_baseTexture", texture_id);
material.setFloat("u_roughness", 0.8);
material.setFloatArray("u_tint", [1, 1, 1, 1]);
material.setInt("u_mode", 0);
```

Supported states:

- blend: enable, mode, separate factors, and blend equation;
- depth: Z test, Z write, and comparison function;
- stencil: function, reference, mask, and operations;
- culling and color write mask;
- alpha test, fog and lighting;
- uniform float, int, array and texture.

Corresponding getters start with `get`; `clone()` duplicates the material and `destroy()` releases its owned resources.

### Global uniforms

`GM3D_Shader` is a static class:

```gml
GM3D_Shader.setGlobalFloat("u_time", current_time * 0.001);
GM3D_Shader.setGlobalFloatArray("u_wind", [1, 0, 0]);
GM3D_Shader.setGlobalInt("u_quality", 2);
GM3D_Shader.setGlobalTexture("u_noise", texture_id);
```

The corresponding `getGlobal*()` functions read the registered value.

### Texture parameters

`GM3D_Texture` exposes static methods for linear filtering, repeat, mip enable/filter, min/max mip, bias, and anisotropy:

```gml
GM3D_Texture.setFilter(texture_id, true);
GM3D_Texture.setRepeat(texture_id, true);
GM3D_Texture.setMaxAniso(texture_id, 8);
```

## Animation

An asset glTF can contain clips and one or more `GM3D_AnimationComponent` instances.

```gml
var animation = asset.getAnimation(index);
show_debug_message(animation.path);
show_debug_message(animation.duration);

animator.play(index, true);
animator.setSpeed(1.0);
animator.setTime(0.0);
```

Available controls:

```gml
animator.pause();
animator.resume();
animator.setEnabled(false);

var playing = animator.isPlaying;
var time = animator.getTime();
var speed = animator.getSpeed();
```

The sample searches for a clip first by exact case-insensitive name, then by substring, and finally uses index `0`. To avoid thousands of perfectly synchronized animated instances, assign slightly different initial speeds and times.

## Camera and rendering

### Projection and target

```gml
camera.setProjection(GM3D_ECameraProjection.Perspective);
camera.setTarget(GM3D_ECameraTarget.Screen);
camera.setRenderSizeMode(GM3D_ECameraRenderSizeMode.Auto);
```

For render-to-texture:

```gml
camera.setTarget(GM3D_ECameraTarget.Texture);
camera.setRenderSizeMode(GM3D_ECameraRenderSizeMode.Fixed);
camera.setRenderWidth(1024);
camera.setRenderHeight(1024);

var color_texture = camera.renderTexture;
var depth_texture = camera.depthTexture;
```

### Rectangle, order, and alpha

`setScreenRect([x, y, width, height])` uses normalized coordinates. The split-screen sample sets:

```gml
left_camera.setScreenRect([0.0, 0.0, 0.5, 1.0]);
right_camera.setScreenRect([0.5, 0.0, 0.5, 1.0]);
left_camera.setOrder(0);
right_camera.setOrder(1);
```

`setAlpha()` controls camera compositing; `setEnabled()` includes or excludes it from rendering.

### Free-look controller

The sample stores position, yaw, and pitch in the application, then applies the result to the camera node:

```gml
cam_pitch = clamp(cam_pitch, -85, 85);

var rotation = GM3D_Quaternion.fromEuler(
    new GM3D_Euler(degtorad(cam_pitch), degtorad(cam_yaw), 0)
);

camera_node.setLocalPosition(cam_position);
camera_node.setLocalRotation(rotation);
```

The sample uses the right mouse button for mouse-look, `WASD` for horizontal movement, `Q/E` for vertical movement, and Shift as a speed multiplier.

## Lights, environment and fog

Official light types:

```gml
GM3D_ELightType.Directional
GM3D_ELightType.Point
GM3D_ELightType.Spot
```

A directional light uses the node orientation. Point and spot lights also use position; a spot light uses orientation and cone angles. GameMaker colors and intensity are separate properties.

Fog is configured on the `GM3D_EnvironmentVolumeComponent` and can be disabled per volume. `fogStart` and `fogEnd` define the linear range shown by the sample.

## glTF loading and instances

### Pattern asset

```gml
function load_model(_path, _instanced) {
    var asset = GM3D_Scene.loadGltf(_path);
    assign_compatible_shaders(asset, _instanced);
    asset.freeze();
    array_push(assets, asset);
    return asset;
}
```

`freeze()` completes preparation of the source scene in the official pattern. Call it after changes to materials that must be shared by instances and before `spawnInto()`.

### Spawn and parent

```gml
var root = asset.spawnInto(scene, undefined);
var child_root = asset.spawnInto(scene, parent_node);
```

The returned node is the control point for the instance: position, rotation, and scale applied to the root affect the entire imported hierarchy.

### Format supported by the sample

The included assets are `.glb`, that is, binary glTF with meshes, materials, skinning, and animations. The repository does not demonstrate OBJ, FBX, collision meshes, raycasts, or physics; do not assume they are GM3D services.

## The four official samples

### 0. Static model

Loads a static tree, assigns its shader, computes its bounding box, and orbits the camera around the center. It is the minimum reference for:

- `loadGltf()` → shader → `freeze()` → `spawnInto()`;
- perspective camera;
- directional light and environment;
- mesh bounding box and automatic framing.

### 1. Animated model

Loads a skinned character and demonstrates:

- recursive search for the animation component;
- listing clips with `animationCount` and `getAnimation()`;
- `play(index, true)`, speed, and changing clips;
- shader dedicated to the skinned mesh.

### 2. Scene composition

Composes platforms, vegetation, rocks, a character, and an animal. Demonstrates:

- multiple assets and many instances in the same scene;
- local transformations with quaternions;
- two cameras and split-screen;
- free-look and 3D movement;
- fog and an environment volume;
- GameMaker UI overlaid on GM3D rendering.

### 3. Instanced forest

Generates about 20,000 trees and 2,000 animated foxes with a deterministic seed. Demonstrates:

- static and animated shaders prepared for instancing;
- reuse of frozen asset scenes;
- many calls `spawnInto()`;
- variations in position, yaw, scale, animation time, and animation speed;
- fog to limit visible distance.

This sample is a throughput test, not a promise of identical performance on every target.

## Performance and ownership

### Practical rules

- Load each model once and keep it as a source asset.
- Assign the shader before `freeze()`.
- Use `spawnInto()` for instances.
- Use instanced shaders when the content and platform allow it.
- Do not recreate renderers, scenes, materials, or assets every frame.
- Update the scene once per Step using seconds, not microseconds.
- Size near/far planes and fog for the scene: excessive ranges reduce depth precision.
- Explicitly destroy all owned scenes.

### Suggested ownership

| Resource | Typical creator | Cleanup |
| --- | --- | --- |
| live scene | level controller | `scene.destroy()` |
| glTF asset scene | asset registry/loader | `asset.destroy()` once |
| spawned node | live scene | destroy the node or scene |
| runtime-created material | material system | `material.destroy()` |
| renderer | controller | remove the reference |

Avoid destroying a shared asset while systems can still generate instances from it.

## API by type

This is a quick-reference map, not a complete reproduction of the reference.

### Scene graph

| Type | Main members |
| --- | --- |
| `GM3D_Scene` | `createEmpty`, `loadGltf`, `createNode`, `getNode(s)`, `getMaterial(s)`, `getAnimation(s)`, `applyAnimation`, `spawnInto`, `freeze`, `update`, `destroy` |
| `GM3D_SceneNode` | hierarchy, components, local/world transformations, local/world axes, `destroy` |

### Components

| Type | Main members |
| --- | --- |
| `GM3D_CameraComponent` | projection, FOV/ortho, near/far, target, render size, screen rect, order, alpha, enabled |
| `GM3D_AnimationComponent` | `play`, `pause`, `resume`, time, speed, enabled, `isPlaying` |
| `GM3D_LightComponent` | type, color, intensity, range, cone angles, enabled |
| `GM3D_EnvironmentVolumeComponent` | size, ambient color, fog color/start/end, enabled |
| `GM3D_MeshComponent` | mesh, material, enabled |
| `GM3D_SkinnedMeshComponent` | mesh, material, enabled, `jointCount` |

### Resources and rendering

| Type | Main members |
| --- | --- |
| `GM3D_Renderer` | `render(scene, deltaTime?)` |
| `GM3D_Material` | shader, uniform, texture, blend/depth/stencil/cull/alpha/fog/lighting, clone/destroy |
| `GM3D_Shader` | global float/int/array/texture uniforms |
| `GM3D_Texture` | filter, repeat, mipmap, and anisotropy |
| `GM3D_Mesh` | buffer/format/primitive, skinning, bounding box |
| `GM3D_Animation` | `path`, `duration` |

### Enums main

```gml
GM3D_ECameraProjection.Perspective
GM3D_ECameraProjection.Orthographic

GM3D_ECameraRenderSizeMode.Auto
GM3D_ECameraRenderSizeMode.Fixed

GM3D_ECameraTarget.Screen
GM3D_ECameraTarget.Texture

GM3D_ELightType.Directional
GM3D_ELightType.Point
GM3D_ELightType.Spot
```
