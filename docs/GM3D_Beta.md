# GM3D Beta in GameMaker

Operational guide to the GMRT runtime 3D module, **Beta / `develop` branch**.
It starts from `GM3D.md` (stable, 4 samples) and incorporates everything new
found in [YoYoGames/GM3D-Samples `develop`](https://github.com/YoYoGames/GM3D-Samples/tree/develop)
— `scripts/`, `objects/`, `shaders/` and `notes/GM3D_API.md`.

> Everything in Beta is experimental and may change. When in doubt the
> `notes/GM3D_API.md` index inside the sample repo is the authority, not this file.

## Contents

- [Mental model](#mental-model)
- [Quick start](#quick-start)
- [Lifecycle](#lifecycle)
- [Scenes and nodes](#scenes-and-nodes)
- [Transformations and math](#transformations-and-math)
- [Components](#components)
- [Materials, shaders and textures](#materials-shaders-and-textures)
- [Shadows and render passes](#shadows-and-render-passes)
- [Animation](#animation)
- [Camera and rendering](#camera-and-rendering)
- [Lights, environment and fog](#lights-environment-and-fog)
- [glTF loading and instances](#gltf-loading-and-instances)
- [Physics](#physics)
- [Character controller](#character-controller)
- [Vehicles](#vehicles)
- [FPS patterns: hitscan, pickups, debris](#fps-patterns-hitscan-pickups-debris)
- [The seven Beta samples](#the-seven-beta-samples)
- [Performance and ownership](#performance-and-ownership)
- [Migration from stable GM3D.md](#migration-from-stable-gmdmd)
- [API by type](#api-by-type)
- [Documentation limits](#documentation-limits)
- [Sources](#sources)

## Mental model

Beta keeps the stable scene-graph renderer but adds a parallel
physics simulation:

```text
GM3D_Scene
└── GM3D_SceneNode
    ├── local transformation
    ├── child nodes
    └── components
        ├── GM3D_CameraComponent
        ├── GM3D_LightComponent (+ shadows)
        ├── GM3D_EnvironmentVolumeComponent
        ├── GM3D_MeshComponent / GM3D_SkinnedMeshComponent (+ flags)
        ├── GM3D_AnimationComponent
        ├── GM3D_PhysicsBodyComponent + GM3D_PhysicsShapeComponent
        ├── GM3D_PhysicsConstraintComponent
        ├── GM3D_CharacterControllerComponent
        └── GM3D_PhysicsVehicle* (Wheel, Powertrain, Differential,
            AntiRollBar, Motorcycle, Tracked, Vehicle)
```

A `GM3D_Renderer` traverses the scene and draws it. A `GM3D_PhysicsWorld`
simulates the bodies registered from that same scene. Typical Beta pipeline:

1. create live scene + renderer (+ optional `GM3D_PhysicsWorld`);
2. load glTF scenes as source assets (`working_directory + path`);
3. assign **two** shaders per material (Forward + Shadow);
4. call `freeze()` on the source asset;
5. create instances with `spawnInto()` and attach physics/vehicle/character components;
6. add camera, shadow-casting directional light, environment volume;
7. per Step: input → `scene.update(dt)` → `physicsWorld.step(dt)` → `physicsWorld.interpolateForRender()`;
8. in Draw: `renderer.render(scene)` then `physicsWorld.restoreSimulationPositions()`;
9. destroy live scene, assets, and physics world in Clean Up.

Non-physics samples skip steps with `physicsWorld` entirely.

## Quick start

The `GM3D_*` module is provided by GMRT: the sample repo contains no
extension to import. Eight shaders **are** part of the sample project.

### Create

```gml
#macro DELTA_SECONDS (delta_time * 0.000001)

scene = GM3D_Scene.createEmpty();
renderer = new GM3D_Renderer();
assets = [];

var model = GM3D_Scene.loadGltf(working_directory + "kenney_platformer-kit/tree.glb");

// Beta: one shader per render pass.
var _shStatic = shStatic;
var _shStaticShadow = shStaticShadow;
var _shAnimated = shAnimated;
var _shAnimatedShadow = shAnimatedShadow;

model.forEachMaterial(method({ _shStatic, _shAnimated, _shStaticShadow, _shAnimatedShadow }, function(_mat, _ctx) {
    var _skinned = (_ctx.skinnedMeshCount > 0);
    _mat.setShader(GM3D_ERenderPass.Forward, _skinned ? _shAnimated : _shStatic);
    _mat.setShader(GM3D_ERenderPass.Shadow, _skinned ? _shAnimatedShadow : _shStaticShadow);
}));

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

### Step (no physics)

```gml
scene.update(DELTA_SECONDS);
```

### Step (with physics)

```gml
// 1. write inputs (character velocity, vehicle input, kinematic poses)
scene.update(DELTA_SECONDS);
physicsWorld.step(DELTA_SECONDS);
physicsWorld.interpolateForRender();
// ... camera follow, HUD reads ...
```

### Draw

```gml
renderer.render(scene);
// Beta physics only:
physicsWorld.restoreSimulationPositions();
```

`restoreSimulationPositions()` must run **after** render, otherwise the
interpolated pose leaks into the next simulation step.

### Clean Up

```gml
if (physicsWorld != undefined) physicsWorld.destroy();

scene.destroy();
for (var i = 0; i < array_length(assets); ++i) {
    assets[i].destroy();
}
assets = [];
renderer = undefined;
```

## Lifecycle

### Initialization

`GM3D_Scene.createEmpty()` creates the live container. `GM3D_Scene.loadGltf()`
loads a separate asset scene. `spawnInto(dest, parent)` copies hierarchy into
the live scene. `parent = undefined` spawns at scene root; any node spawns as
child (used for visuals parented to physics bodies, avatars parented to
character nodes, weapons parented to cameras).

Physics registration happens **once at startup**, after a stabilizing
`scene.update(0.0)`:

```gml
scene.update(0.0);
physicsWorld.syncScene();          // bulk register
// or granular:
physicsWorld.addNode(node);        // body + shape required
physicsWorld.addCharacter(node);   // character controller required
physicsWorld.addVehicle(vehicle);  // configured vehicle component
```

Constructor observed in samples:

```gml
physicsWorld = new GM3D_PhysicsWorld(scene, { maxBodies: 512, fixedTimeStep: 1/60, maxSubSteps: 4 });
physicsWorld.setGravity(new GM3D_Vec3(0, -9.81, 0));
physicsWorld.setDebugDrawEnabled(false); // P toggles it in samples
```

### Updating

Non-physics: `scene.update(delta_seconds)` once per Step.

Physics: strict order used by samples 4/5/6:

```text
input → setCharacterVelocity / setVehicleInput / setBodyPositionRotation
      → scene.update(dt) → physicsWorld.step(dt) → interpolateForRender()
      → readback (ground state, velocity, speed) → camera → render
```

`delta_time` is microseconds; GM3D and physics both use seconds.

### Rendering

```gml
renderer.render(scene, deltaTime?);
```

The Beta `render()` accepts an optional `deltaTime` (seconds since last
render). Samples call it with one argument. The renderer uses enabled cameras
in `order` sequence, each clipped to its `screenRect`.

### Destruction

Destroy in reverse order of creation: vehicles/characters/nodes are owned by
the scene, but the world must be destroyed **before** the scene:

```gml
physicsWorld.destroy();
scene.destroy();
asset.destroy(); // once per loadScene() entry
```

## Scenes and nodes

### `GM3D_Scene`

Creation and queries (unchanged + new iteration helpers):

```gml
var scene = GM3D_Scene.createEmpty();
var asset = GM3D_Scene.loadGltf(working_directory + path);

var node = scene.createNode("Player");
var by_name = scene.getNode("Player");
var by_index = scene.getNode(0);
var nodes = scene.getNodes();
var names = scene.getNodeNames();

scene.forEachNode(function(_node) { /* stable order, created-during-callback not visited */ });
scene.forEachMaterial(function(_mat, _ctx) {
    // _ctx.staticMeshCount, _ctx.skinnedMeshCount
});
```

Materials and animations:

```gml
var material = asset.getMaterial(0);       // also by name
var materials = asset.getMaterials();
var material_names = asset.getMaterialNames();
scene.setMaterial(0, replacement);         // NEW in Beta index

var animation = asset.getAnimation(0);     // also by name
var animations = asset.getAnimations();
var animation_names = asset.getAnimationNames();
var exists = asset.hasAnimation(0);
scene.applyAnimation(index_or_name_or_struct, time_seconds); // NEW: pose without component
```

Bounds (NEW — replaces manual min/max math):

```gml
var bb = asset.getBoundingBox();     // { min: GM3D_Vec3, max: GM3D_Vec3 } world space
var bs = asset.getBoundingSphere();  // { origin: GM3D_Vec3, radius: real } world space
```

Sample 0 frames the orbit camera from `getBoundingSphere()`. Sample 4 centers
coin visuals from `getBoundingBox()`. Sample 5 derives wheel radius/width from
mesh bounds (see Vehicles).

Read-only counts: `nodeCount`, `materialCount`, `animationCount`, `path`.

### `GM3D_SceneNode`

Hierarchy (unchanged + `destroy` flag + search):

```gml
parent.addChild(child);
var children = parent.getChildren();
child.removeFromParent();
node.destroy();        // Beta: destroy(recursive?) — true destroys subtree,
                       // false reparents children to own parent
node.forEachNode(function(_n) { /* depth-first self + descendants */ });
var found = root.findNodeByName("wheel-front-left");
```

Direct components:

```gml
node.addComponent(component);
node.removeComponent(component);
node.removeAllComponents();

var camera = node.getCameraComponent();
var light = node.getLightComponent();
var environment = node.getEnvironmentVolumeComponent();
var mesh = node.getMeshComponent();
var meshes = node.getMeshComponents();       // NEW plural
var skinned = node.getSkinnedMeshComponent();
var animation = node.getAnimationComponent();
var animations = node.getAnimationComponents();
```

Recursive search (NEW — preferred over hand-rolled recursion):

```gml
var animator  = root.findAnimationComponent();
var cam       = root.findCameraComponent();
var light     = root.findLightComponent();
var env       = root.findEnvironmentVolumeComponent();
var mesh      = root.findMeshComponent();
var skinned   = root.findSkinnedMeshComponent();
var body      = root.findPhysicsBodyComponent();
var shape     = root.findPhysicsShapeComponent();
var constraint= root.findPhysicsConstraintComponent();
var character = root.findCharacterControllerComponent();
var vehicle   = root.findPhysicsVehicleComponent();
var wheel     = root.findPhysicsVehicleWheelComponent();
// + AntiRollBar, Differential, Motorcycle, Powertrain, Tracked variants
```

`getAnimationComponent()` returns the first component **on that node only**.
`findAnimationComponent()` searches the subtree depth-first — this is what
samples 1/2/3/4 use after `spawnInto()`.

Node identity: `name`, `parent` (undefined at root).

## Transformations and math

Local is relative to parent; world derives from the chain.

```gml
node.setLocalPosition(new GM3D_Vec3(x, y, z));
node.setLocalRotation(GM3D_Quaternion.fromAxisAngle(GM3D_Vec3.up(), angle));
node.setLocalScale(new GM3D_Vec3(sx, sy, sz));
node.setLocalMatrix(matrix); // NEW

var local_matrix = node.getLocalMatrix();
var world_matrix = node.getWorldMatrix();
var world_position = node.getWorldPosition();
var forward = node.getWorldForward();
var right = node.getWorldRight();
var up = node.getWorldUp();
// + getLocalForward/Right/Up, getLocalPosition/Rotation/Scale,
//   getWorldRotation/Scale
```

Beta helpers seen everywhere:

```gml
// Orient node along a direction (lights, cameras, orbit):
node.setLocalRotation(GM3D_Quaternion.fromLookRotation(direction));
// Safe normalize after fromAxisAngle (samples 2/4):
_root.setLocalRotation(_rot.normalizeSafe(0.000001));
// Planar movement basis (samples 2/3/4/6):
var fwd = camNode.getLocalForward();
var planar = new GM3D_Vec3(fwd.x, 0, fwd.z).normalize();
```

### Mathematical types

Same five types as stable, now with full method lists in `GM3D_API.md`
(Vec2/Vec3/Vec4, Matrix2/3/4, Quaternion, Euler, DualQuaternion).
Practical additions used by samples:

| Addition | Use |
| --- | --- |
| `GM3D_Quaternion.fromLookRotation(fwd[, up])` | aim camera/light/node, orbit logic |
| `Quaternion.normalizeSafe(eps)` | guard degenerate yaw rotations |
| `GM3D_Mesh.getBoundingBox()` → `{min, max}` | replace old `getBoundingBoxMin/Max` |
| `GM3D_Scene.getBoundingBox/Sphere()` | auto-framing, spawn layout |
| `GM3D_Vec3.forward/up/right/one/zero` | canonical axes |

Matrices expose `elements` column-major. Prefer GM3D methods over native
array matrices.

## Components

### Camera

```gml
var component = new GM3D_CameraComponent();
node.addComponent(component);

component.setEnabled(true);
component.setProjection(GM3D_ECameraProjection.Perspective);
component.setFovY(degtorad(60));
component.setNear(0.1);
component.setFar(500); // 0 = infinite in perspective mode (Beta)
component.setAspectRatio(16 / 9);
```

Ortho: `setOrthoWidth()` / `setOrthoHeight()`. Render target / rect / order /
alpha unchanged from stable (see Camera and rendering).

NEW camera utilities:

```gml
// Free-look without manual Euler math (samples 2/3/4/5/6, RMB + limits):
camComponent.updateMouselook(deltaYawDeg, deltaPitchDeg, -85, 85);
// delta from: window_mouse_get_delta_x() / window_mouse_get_delta_y()

// Gameplay queries:
var ray = camComponent.screenPointToRay({ x: 0.5, y: 0.5 });
// → { origin, direction } or undefined (FPS crosshair raycast)

var ndc = camComponent.worldToScreen(worldPos);
// → GM3D_Vec3 with camera screenRect applied, z = 0..1 depth, or undefined
//   (FPS ammo labels, viewport outlines)
```

Properties `renderTexture`, `depthTexture` expose render-to-texture results.

### Light

```gml
var component = new GM3D_LightComponent();
node.addComponent(component);

component.setType(GM3D_ELightType.Directional);
component.setColor(c_white);   // packed 0x00BBGGRR
component.setIntensity(1.0);
component.setEnabled(true);
```

Point/spot also use `setRange()` (0 = infinite). Spot uses
`setInnerConeAngle()` / `setOuterConeAngle()` in radians.

NEW shadow API (directional only, used by `createDirLight` helper):

```gml
component.setShadowEnabled(true);
component.setShadowResolution(2048);
component.setShadowDistance(20.0);
component.setShadowNormalOffset(0.05);
// getters: getShadowEnabled/Resolution/Distance/NormalOffset
```

### Environment volume

```gml
var component = new GM3D_EnvironmentVolumeComponent();
node.addComponent(component);

component.setSize(new GM3D_Vec3(100, 100, 100)); // Beta takes Vec3, not 3 reals
component.setAmbientColor(make_color_rgb(80, 90, 100));
component.setFogEnabled(true);
component.setFogColor(c_silver);
component.setFogStart(20);
component.setFogEnd(100);
// getters: getSize/AmbientColor/FogColor/FogStart/FogEnd/FogEnabled
```

Volume is an AABB centered on node world position. Samples size it generously
(`20000`, `50000`) and tune fog per scene (e.g. forest `22 → 95`,
physics `14 → 78`, vehicle `25 → 140`, FPS `30 → 180`).

### Mesh

```gml
var component = new GM3D_MeshComponent(mesh, material);
component.setMaterial(material); // setMesh removed in Beta index; construct with both
component.setEnabled(true);
```

`GM3D_SkinnedMeshComponent(mesh, material)` same shape + `jointCount`.

NEW shadow flags (both default **on**):

```gml
component.setFlags(GM3D_EMeshComponentFlags.CastShadows | GM3D_EMeshComponentFlags.ReceiveShadows);
var flags = component.getFlags();
// GM3D_EMeshComponentFlags.CastShadows = 1, ReceiveShadows = 2
```

`GM3D_Mesh` Beta surface: `name`, `isSkinned`, `primitiveType`,
`vertexBuffer`, `vertexFormat`, `getBoundingBox()` (single call returning
`{min, max}` — replaces stable `getBoundingBoxMin/Max`).

## Materials, shaders and textures

### Shader assignment — BREAKING CHANGE

Stable: `material.setShader(shader)`.

Beta: `material.setShader(pass, shader)` / `material.getShader(pass)`, where
`pass` is `GM3D_ERenderPass`:

```gml
GM3D_ERenderPass.Shadow  = 0  // shadow-map pass
GM3D_ERenderPass.Forward = 1  // scene geometry
GM3D_ERenderPass.Custom  = 2  // base for user passes: Custom + N in [0, 255]
```

Passing `undefined` clears a non-forward pass or restores the default forward
shader. Canonical Beta helper (`scrSampleScene`):

```gml
function assignShaders(_scene, _instanced = false) {
    var _shStatic = _instanced ? shStaticInstanced : shStatic;
    var _shAnimated = _instanced ? shAnimatedInstanced : shAnimated;
    var _shStaticShadow = _instanced ? shStaticInstancedShadow : shStaticShadow;
    var _shAnimatedShadow = _instanced ? shAnimatedInstancedShadow : shAnimatedShadow;
    var _ctx = { _shStatic, _shAnimated, _shStaticShadow, _shAnimatedShadow };
    _scene.forEachMaterial(method(_ctx, function(_material, _context) {
        var _skinned = (_context.skinnedMeshCount > 0);
        var _shader = _skinned ? _shAnimated : _shStatic;
        var _shadowShader = _skinned ? _shAnimatedShadow : _shStaticShadow;
        _material.setShader(GM3D_ERenderPass.Forward, _shader);
        _material.setShader(GM3D_ERenderPass.Shadow, _shadowShader);
    }));
}
```

Eight shader variants ship with the project:

| Geometry | Forward | Forward instanced | Shadow | Shadow instanced |
| --- | --- | --- | --- | --- |
| static | `shStatic` | `shStaticInstanced` | `shStaticShadow` | `shStaticInstancedShadow` |
| skinned | `shAnimated` | `shAnimatedInstanced` | `shAnimatedShadow` | `shAnimatedInstancedShadow` |

Shaders show required attributes (`in_Position/Normais/Colour/TextureCoord/Tangent`),
TBN frame, world position, fog factor, and `gm_ShadowNormalOffset`.

### `GM3D_Material`

```gml
var material = new GM3D_Material("Ground");
material.setShader(GM3D_ERenderPass.Forward, shStatic);
material.setTexture("u_baseTexture", texture_id);
material.setFloat("u_roughness", 0.8);
material.setFloatArray("u_tint", [1, 1, 1, 1]);
material.setInt("u_mode", 0);
```

Full state list unchanged (blend, depth, stencil, cull, color-write, alpha
test, fog, lighting, float/int/array/texture uniforms) — see `GM3D_API.md`
for the ~60 getters/setters. `clone()` / `destroy()` / `getName/setName`
unchanged. New: `setMaterial()` on scene to swap a slot by name/index.

### Global uniforms

`GM3D_Shader.setGlobalFloat/FloatArray/Int/IntArray/Texture` +
`getGlobal*` — unchanged.

### Texture parameters

`GM3D_Texture` static get/set for filter, repeat, mip enable/filter,
min/max mip, bias, anisotropy — unchanged, now with getters for every setter.

## Shadows and render passes

New section (no equivalent in stable doc):

- Directional light owns the shadow map: enable + resolution + distance +
  normal offset.
- Each mesh component opts in/out via `GM3D_EMeshComponentFlags`.
- Each material binds **two** shaders: Forward (visible) and Shadow
  (depth). Forgetting the Shadow pass = correct lighting but no shadows.
- Instanced variants exist for both passes; forest sample proves the
  combination (`assignShaders(src, true)` + `CastShadows` default).
- Debug: `physicsWorld.setDebugDrawEnabled()` is physics debug, unrelated to
  shadow maps.

```gml
// Minimal shadow setup (from scrSampleNodeFactory.createDirLight):
var _light = new GM3D_LightComponent();
_light.setType(GM3D_ELightType.Directional);
_light.setColor(_color);
_light.setShadowEnabled(true);
_light.setShadowResolution(2048);
_light.setShadowDistance(20.0);
_light.setShadowNormalOffset(0.05);
_node.setLocalRotation(GM3D_Quaternion.fromLookRotation(_direction));
```

## Animation

Asset clips + `GM3D_AnimationComponent` — same controls, new lookup helper:

```gml
var animation = asset.getAnimation(index); // path, duration
animator.play(index, true);
animator.setSpeed(1.0);
animator.setTime(0.0);
animator.pause();
animator.resume();
animator.setEnabled(false);
var playing = animator.isPlaying;
var time = animator.getTime();
var speed = animator.getSpeed();
```

Beta pattern (`scrSampleAnimation.findAnimIndex` + samples 1/2/3/4):

```gml
animator = root.findAnimationComponent(); // NOT getAnimationComponent()
animator.setEnabled(true);
var idx = findAnimIndex(asset, "idle");   // exact match → substring → 0
animator.setTime(0);
animator.setSpeed(1.0);
animator.play(idx, true);
```

Desync trick (forest, 2000 foxes): random `setSpeed(0.85–1.15)` and
`setTime(random(10))` per instance.

`GM3D_Scene.applyAnimation(nameOrIndexOrStruct, time)` poses a scene without a
component — useful for thumbnails/debris, not used by current samples.

## Camera and rendering

Projection/target/size/rect/order/alpha — same API, plus Beta extras above
(`updateMouselook`, `screenPointToRay`, `worldToScreen`, `far = 0` infinite).

Free-look controller (Beta canonical, samples 2–6):

```gml
if (mouse_check_button(mb_right)) {
    camComponent.updateMouselook(
        window_mouse_get_delta_x() * lookSense,
        -window_mouse_get_delta_y() * lookSense,
        -85, 85
    );
}
camPos = moveCam(camPos, camNode, camSpeed, fastMult); // WASD + Q/E + Shift
camNode.setLocalPosition(camPos);
// moveCam uses getLocalForward/Right planarized on XZ, Q/E on Y
```

Split-screen (sample 2): two cameras, `setScreenRect([0,0,0.5,1])` /
`[0.5,0,0.5,1]`, `setOrder`, `setAlpha`, `setEnabled`, toggle with `P`,
switch active viewport with `Tab`. Viewport outline in Draw GUI Begin via
`getScreenRect()`.

Follow cameras (samples 5/6): `getWorldPosition/Forward`, `getLinearVelocity`,
`lerp` smoothing, occlusion raycast (sample 4), head-bob + recoil offsets
(sample 6).

## Lights, environment and fog

Types `Directional / Point / Spot` unchanged. Directional uses orientation,
point/spot use position, spot adds cones. Color + intensity separate.

Fog lives on the environment volume and can be disabled per volume.
`fogStart/fogEnd` linear range. Beta adds shadow config on the light (above)
and per-mesh shadow flags.

## glTF loading and instances

Pattern asset (Beta):

```gml
function loadScene(_fileName) {
    var _scene = GM3D_Scene.loadGltf(working_directory + _fileName);
    if (_scene == undefined) return undefined;
    assignShaders(_scene);
    _scene.freeze();
    array_push(assets, _scene);
    return _scene;
}
```

`freeze()` after material edits, before `spawnInto()`. Supported format in
repo is `.glb` (meshes, materials, skinning, animations). No OBJ/FBX/collision
mesh/raycast/physics assumptions in stable doc — **Beta adds physics shapes
that approximate meshes** (`Mesh`, `ConvexHull`, `ConvexDecomposition` shape
types) but still no asset-pipeline physics import.

Spawn and parent:

```gml
var root = asset.spawnInto(scene, undefined);  // root instance
var child_root = asset.spawnInto(scene, parent_node); // visual under body
```

Visual offset/scale pattern (physics samples): spawn under a unit-scaled
physics node, center via bounding box, scale visual independently.

## Physics

Entirely new vs stable. Jolt-style API surfaced as components + world.

### Body and shape

```gml
var body = new GM3D_PhysicsBodyComponent();
body.setMotionType(GM3D_EPhysicsMotionType.Static); // Static | Kinematic | Dynamic
body.setLayer(GM3D_EPhysicsLayer.Static);           // Static=1 Default=2 Character=4 Trigger=8 Debris=16 All=31
body.setMass(2.0);
body.setLinearDamping(0.15);
body.setAngularDamping(0.35);
body.setGravityFactor(1.0);
body.setIsSensor(false);      // true for triggers
body.setStartAwake(false);
body.setMotionQuality(GM3D_EPhysicsMotionQuality.Discrete);
body.setAllowSleeping(true);
// + center-of-mass offset, locked axes, collision group/subgroup,
//   contact callbacks (below)

var shape = new GM3D_PhysicsShapeComponent();
shape.setShapeType(GM3D_EPhysicsShapeType.Box); // Box Sphere Capsule Cylinder Mesh ConvexHull ConvexDecomposition
shape.setHalfExtents(new GM3D_Vec3(hx, hy, hz)); // sphere/capsule/cylinder: x=radius y=half-height
shape.setLocalOffset(offset);
shape.setLocalRotation(rot);
shape.setFriction(0.95);
shape.setRestitution(0.0);

node.addComponent(body);
node.addComponent(shape);
```

Helpers in `scrSamplePhysicsSpawn`: `sampleSpawnVisual` (transform only),
`sampleSpawnStaticBox` (node + body + box), `sampleSpawnStaticSceneShape`
(scene-driven collider), `sampleSpawnCoinPickup` (visual + point light +
sensor sphere + trigger body), `sampleSpawnConeWithPhysics` /
`sampleSpawnConeLoopWithPhysics` (dynamic convex-hull cones).

### World

```gml
world = new GM3D_PhysicsWorld(scene, { maxBodies: 512, fixedTimeStep: 1/60, maxSubSteps: 4 });
world.setGravity(new GM3D_Vec3(0, -9.81, 0));
world.syncScene();
world.step(DELTA_SECONDS);
world.interpolateForRender();
world.restoreSimulationPositions(); // after render
world.destroy();
```

Registration: `addNode / removeNode / rebuildNode / addTree`.
Simulation control: `activateBody / deactivateBody / isBodyActive`,
`get/setBodyPositionRotation`, `get/setLinearVelocity/AngularVelocity`,
`addForce / addTorque / addLinearImpulse / addAngularImpulse` (+ `AtPoint`
variants), `setBodyFriction/Restitution/MotionQuality/AllowSleeping/DOFLock`,
`setMass/LinearDamping/AngularDamping/GravityFactor/IsSensor` per node.
Layers: `setLayerCollision(a, b, collides)` / `getLayerCollision`.
Groups: `setCollisionGroupPair`.
Gravity: `setGravity / getGravity`. Debug: `setDebugDrawEnabled`.

### Queries

```gml
var hit = world.raycast(origin, dir, maxDist, layerMask, ignoreNodes);
// → GM3D_RaycastHit { node, point, normal, distance } or undefined
var hits = world.raycastAll(origin, dir, maxDist, mask, ignore, maxHits);
var swept = world.shapeCast(shapeType, halfExtents, origin, rot, sweep, mask, ignore, max);
var ov = world.overlapSphere(center, radius, mask, ignore, max);
var ov = world.overlapBox(center, halfExtents, rot, mask, ignore, max);
var ov = world.overlapCapsule(center, radius, halfHeight, rot, mask, ignore, max);
var ov = world.overlapPoint(point, mask, ignore, max);
// → GM3D_OverlapHit { node, closestPoint }
var cp = world.getClosestPointOnBody(node, worldPoint);
```

Used: camera occlusion raycast (sample 4), FPS hitscan raycast with
`[playerNode]` exclusion (sample 6). Overlap/shapeCast are available but
unused by current samples.

### Contacts and callbacks

```gml
// Per-body:
id = body.addContactCallback(function(_ev) {
    // _ev: GM3D_ContactEvent { nodeA, nodeB, point, normal,
    //   impactVelocity, type, selfNode, otherNode }
}, GM3D_EPhysicsContactEventMask.Enter);
body.removeContactCallback(id);
body.clearContactCallbacks();
body.setContactCallbacksEnabled(true);

// World poll:
var evs = world.getContactEvents();
var evs = world.getContactEventsFiltered(eventMask, layerMask, node);
var acts = world.getActivationEvents();
```

Enums: `GM3D_EPhysicsContactEvent.Enter/Stay/Exit = 0/1/2`,
`...Mask.Enter/Stay/Exit/All = 1/2/4/7`.
Used: coin/ammo pickups filter `type == Enter && otherNode == playerNode`,
then `node.destroy(true)`.

### Constraints

Component + world factory (available, unused by current samples):

```gml
var c = new GM3D_PhysicsConstraintComponent();
// type Fixed/Point/Hinge/Slider/Cone/Distance, nodeB, pivots, axes,
// limits, cone/twist angles, spring frequency/damping, friction
world.addConstraint(c);
world.createPointConstraintBetween(a, b, pivotA, pivotB);
world.createDistanceConstraintBetween(a, b, pivotA, pivotB);
world.createHingeConstraintBetween(a, b, pivotA, pivotB, axisA, normalA);
world.createSliderConstraintBetween(a, b, pivotA, pivotB, axisA);
// + removeConstraint, setConstraintEnabled/Limits/Motor*/Pivots/Frame
```

## Character controller

New component + world interface (samples 4 and 6):

```gml
var cc = new GM3D_CharacterControllerComponent();
cc.setRadius(0.33);
cc.setHalfHeight(0.92);   // cylinder part, hemispheres excluded
cc.setStepHeight(0.3);
cc.setMaxSlopeAngle(degtorad(55));
cc.setLayer(GM3D_EPhysicsLayer.Character);
cc.setMass(80);
cc.setMaxStrength(160);
cc.setPredictiveContactDistance(0.12);
// + padding, penetration speed, edge removal, supporting volume,
//   push flags
node.addComponent(cc);
physicsWorld.addCharacter(node);
physicsWorld.setCharacterVelocity(node, new GM3D_Vec3(vx, vy, vz));
```

Per-frame (sample 4 third-person, sample 6 first-person):

```gml
// planar WASD from camera, vertical gravity/double-jump manual:
physicsWorld.setCharacterVelocity(playerNode, nextVel);
scene.update(dt);
physicsWorld.step(dt);
physicsWorld.interpolateForRender();
var state = physicsWorld.getCharacterGroundState(playerNode);
// OnGround | OnSteepGround | NotSupported | InAir
var vel = physicsWorld.getCharacterVelocity(playerNode);
var nrm = physicsWorld.getCharacterGroundNormal(playerNode);
var groundNode = physicsWorld.getCharacterGroundNode(playerNode);
// + setCharacterShape, characterJump(jumpSpeed), setCharacterStickToGroundEnabled,
//   getCharacterContacts, setCharacterVelocity
```

Avatar animation follows state: `idle / walk / run / sprint / jump / fall`
clips selected by name, `play` + `setSpeed` scaled by horizontal speed.
Camera: third-person smoothed follow + occlusion raycast (sample 4),
eye-level follow + head-bob (sample 6).

## Vehicles

New stack (sample 5, `kenney_car-kit/race.glb` + cones):

```gml
// 1. rig node + visual + dynamic body
carRig = scene.createNode("carRig");
visual = assetCar.spawnInto(scene, carRig);
bodyNode = visual.findNodeByName("body"); // fallback: createNode + addChild
var body = new GM3D_PhysicsBodyComponent();
body.setMotionType(GM3D_EPhysicsMotionType.Dynamic);
body.setLayer(GM3D_EPhysicsLayer.Default);
body.setMass(1325);
body.setLinearDamping(0.08);
body.setAngularDamping(1.05);
var shape = new GM3D_PhysicsShapeComponent();
shape.setShapeType(GM3D_EPhysicsShapeType.ConvexHull);
shape.setFriction(0.22);

// 2. wheels (found by name wheel-*, else created)
var dims = sampleGetWheelDimensionsFromMesh(wheelNode, 0.33, 0.24);
var wheel = new GM3D_PhysicsVehicleWheelComponent();
wheel.setRadius(dims.radius);
wheel.setWidth(dims.width);
wheel.setMaxSteerAngle(isFront ? 0.5 : 0.0);
wheel.setTrackSide(isLeft ? GM3D_EPhysicsTrackSide.Left : GM3D_EPhysicsTrackSide.Right);
// + suspension dir/axes/lengths/frequency/damping, inertia,
//   friction curves, stiffness, brake torques, driven flag

// 3. powertrain / differentials / anti-roll bars
var pt = new GM3D_PhysicsVehiclePowertrainComponent();
pt.setMaxTorque(500);
pt.setMinRPM(900); pt.setMaxRPM(6000);
pt.setShiftUpRPM(5200); pt.setShiftDownRPM(2200);
pt.setFinalDriveRatio(3.4);
pt.setGearCount(6); pt.setGearRatio(i, r); pt.setReverseGearRatio(-3.2);
pt.setClutchStrength(8.0);
pt.setAutomaticTransmission(true);

var diff = new GM3D_PhysicsVehicleDifferentialComponent();
diff.setLeftWheelIndex(li); diff.setRightWheelIndex(ri);
// + limited slip / torque ratios

var arb = new GM3D_PhysicsVehicleAntiRollBarComponent();
arb.setLeftWheelIndex(li); arb.setRightWheelIndex(ri);
arb.setStiffness(12000);

// 4. vehicle
var veh = new GM3D_PhysicsVehicleComponent();
veh.addComponent? // no — wheels/diffs/bars added as components to wheel/body nodes,
// then handles registered:
veh.addWheel(wheel);
veh.setPowertrain(pt);
veh.addDifferential(diff);
veh.addAntiRollBar(arb);
veh.setControllerType(GM3D_EPhysicsVehicleControllerType.Wheeled);
// + local up/forward, steering curves, collision tester, pitch/roll, gravity

scene.update(0.0);
physicsWorld.syncScene();
physicsWorld.addVehicle(veh);
physicsWorld.setVehicleTransmissionMode(veh, true);
physicsWorld.setVehicleTargetGear(veh, 1);
```

Per-frame:

```gml
physicsWorld.setVehicleInput(veh, throttle, steering, brake, handBrake);
// throttle/steering in [-1,1], brake/handBrake in [0,1]
if (speed > 2) physicsWorld.addForce(carNode, downforce);
// + tracked input, clutch, engine running, lean controllers,
//   wheel steer/brake/omega overrides, collision tester
var kmh = physicsWorld.getVehicleSpeedMPS(veh) * 3.6;
var rpm = physicsWorld.getVehicleEngineRPM(veh);
var gear = physicsWorld.getVehicleCurrentGear(veh);
// + wheel/track state getters, rebuildVehicle/removeVehicle
```

Motorcycle (`Motorcycle` component: lean angles/springs/smoothing) and
tracked (`Tracked` component: per-side wheels/inertia/damping/brake/ratios)
variants exist in the index but have no sample yet.

## FPS patterns: hitscan, pickups, debris

Sample 6 (`Mini FPS Range`, 816-line Create) is the reference for shooters:

- Weapon visual parented to camera: `weaponNode = scene.createNode();
  camNode.addChild(weaponNode); blasterAsset.spawnInto(scene, weaponNode)`.
- Aim with pointer lock: `window_mouse_set_locked(aiming)`.
- Hitscan from screen center:

```gml
var ray = camComponent.screenPointToRay({ x: 0.5, y: 0.5 });
var hit = physicsWorld.raycast(ray.origin, ray.direction, 95,
    GM3D_EPhysicsLayer.Default | GM3D_EPhysicsLayer.Static, [playerNode]);
```

- Targets: `Kinematic / Default / ConvexHull` bodies created per slot,
  resolved via parent-chain walk (`resolveTargetSlotFromNode`), destroyed with
  `physicsWorld.removeNode + node.destroy(true)` + debris burst
  (`Dynamic / Debris / ConvexHull` + `addLinearImpulse/AngularImpulse`) + smoke
  visual (`sampleSpawnVisual`).
- Ammo: `Kinematic / Trigger / IsSensor` sphere + point light +
  `addContactCallback(..., Enter)` + bob animation via
  `setBodyPositionRotation` before step.
- HUD labels projected with `camComponent.worldToScreen()`, crosshair drawn in
  Draw GUI End, score/accuracy/combo tracked in GML (not GM3D).
- Dynamic cleanup: expired bursts `removeNode/destroy`.

## The seven Beta samples

| # | Object | Title | What it proves |
| --- | --- | --- | --- |
| 0 | `objSample_0_Static` | Static Model | `loadGltf → forEachMaterial → freeze → spawnInto`, `getBoundingSphere` auto-framing, `orbitCamera` |
| 1 | `objSample_1_Animated` | Animated Model | `findAnimationComponent`, `animationCount/getAnimation`, `findAnimIndex`, `play/speed/time`, skinned shaders, `Next Animation` button |
| 2 | `objSample_2_Scene` | Composed Scene | multi-asset composition, quaternion placement, dual camera split-screen (`ScreenRect/Order/Alpha`), `updateMouselook` + `moveCam`, fog volume, GUI overlay + viewport outline |
| 3 | `objSample_3_Forest` | Instanced Forest | `assignShaders(src, true)`, 20k trees + 2k foxes, seeded `random_set_seed(12345)`, per-instance yaw/scale/anim-time/speed, fog culling |
| 4 | `objSample_4_Physics` | Physics Playground | `PhysicsWorld` lifecycle, static boxes/scene shapes, character capsule, sensor coin triggers + contact callbacks, ground-state avatar switching, camera occlusion raycast, debug-draw toggle |
| 5 | `objSample_5_Vehicle` | Vehicle Showcase | convex-hull car body, wheel discovery + `sampleGetWheelDimensionsFromMesh`, powertrain/diff/anti-roll setup, `setVehicleInput`, speed/RPM/gear telemetry, downforce, follow camera |
| 6 | `objSample_6_FPS` | Mini FPS Range | pointer-lock look, `screenPointToRay` hitscan, kinematic targets + dynamic debris impulses, sensor ammo + lights, `worldToScreen` labels, head-bob/recoil, combo scoring |

Navigation: `objMain` owns `samples[]`, `gotoSample/shiftSample`,
`createNavButton`, `DELTA_SECONDS` macro. `objSample` parent owns
`scene/renderer/assets`, `scene.update` in Step, `renderer.render` in Draw,
full destroy in Clean Up. Physics children override Step/Draw/Clean Up but
call `event_inherited()` to reuse the base.

Sample helpers (`scripts/`):

| Script | Helpers |
| --- | --- |
| `scrMain` | `gotoSample`, `shiftSample` |
| `scrSampleScene` | `loadScene`, `assignShaders(scene[, instanced])` |
| `scrSampleNodeFactory` | `createCamera`, `createDirLight` (shadowed), `createEnvVolume`, `orbitCamera` |
| `scrSampleCameraInput` | `moveCam` (planar WASD + Q/E + Shift) |
| `scrSampleAnimation` | `findAnimIndex` |
| `scrSamplePhysicsSpawn` | `sampleSpawnVisual/StaticBox/StaticSceneShape/CoinPickup` |
| `scrSampleVehicleSetup` | `sampleSpawnConeWithPhysics/Loop`, `sampleGetWheelDimensionsFromMesh` |
| `scrUI` | `CButtonBase/CButton/CIconButton`, `createNavButton` |

## Performance and ownership

Stable rules still apply (load once, shader before freeze, `spawnInto` for
instances, instanced shaders, no per-frame allocation, seconds not
microseconds, tight near/far + fog, explicit destroy). Beta adds:

- `freeze()` uploads meshes to GPU — call once after shader assignment.
- `syncScene()` once after `scene.update(0)`; per-frame use `step()` only.
- `interpolateForRender()` before render, `restoreSimulationPositions()` after.
- Reuse frozen assets for thousands of instances (forest: 22k spawns).
- Physics bodies: prefer boxes/spheres/capsules; `Mesh/ConvexHull/
  ConvexDecomposition` cost more. Static for level, kinematic for scripted
  movers/targets/pickups, dynamic only where simulated.
- Sensors/triggers (`IsSensor + Trigger layer`) for pickups, not solid bodies.
- Character: one `setCharacterVelocity` per step; read ground state after step
  for animation/camera branches.
- Vehicles: set input once per step; avoid per-frame rebuild.
- Shadows double draw cost: keep `ShadowResolution/Distance` minimal, disable
  `CastShadows` on tiny/irrelevant meshes.
- Ownership:

| Resource | Creator | Cleanup |
| --- | --- | --- |
| live scene | level controller | `scene.destroy()` |
| glTF asset | `loadScene` registry | `asset.destroy()` once |
| spawned node | live scene | `node.destroy(recursive?)` or scene destroy |
| runtime material | material system | `material.destroy()` |
| renderer | controller | drop reference |
| physics world | level controller | `physicsWorld.destroy()` **before** scene |
| physics node | live scene + world | `world.removeNode()` then `node.destroy()` |
| contact callback | body | `removeContactCallback/clear` (world destroy clears) |
| vehicle | scene + world | `world.removeVehicle()` then scene destroy |

## Migration from stable GM3D.md

### Breaking / renamed

| Stable | Beta | Note |
| --- | --- | --- |
| `material.setShader(shader)` | `material.setShader(pass, shader)` + `getShader(pass)` | must bind Forward **and** Shadow |
| `mesh.getBoundingBoxMin/Max()` | `mesh.getBoundingBox()` → `{min, max}` | single call |
| `env.setSize(w, h, d)` | `env.setSize(vec3)` | Vec3 form in samples |
| `getAnimationComponent()` only | + `findAnimationComponent()` (+ all `find*`) | use `find*` after `spawnInto` |
| 4 shaders (`shStatic/shAnimated/…Instanced`) | 8 shaders (+ `…Shadow`, `…InstancedShadow`) | missing shadow shader = no shadows |
| manual material loop | `scene.forEachMaterial(cb)` with `{staticMeshCount, skinnedMeshCount}` | instancing flag included |

### New (no stable equivalent)

Cameras: `updateMouselook`, `screenPointToRay`, `worldToScreen`,
`far = 0` infinite, `renderTexture/depthTexture` props.
Scenes: `forEachNode`, `setMaterial`, `applyAnimation`,
`getBoundingBox/Sphere`.
Nodes: `findNodeByName`, `forEachNode`, `getMeshComponents`,
`destroy(recursive?)`, `setLocalMatrix`, local/world axis getters.
Meshes: `get/setFlags` (`CastShadows/ReceiveShadows`), `getBoundingBox`.
Lights: shadow getters/setters.
Enums: `GM3D_ERenderPass`, `GM3D_EMeshComponentFlags`, all
`GM3D_EPhysics*`, `GM3D_ECharacterGroundState`, `GM3D_EConstraintMotorMode`.
Systems: `GM3D_PhysicsBody/Shape/Constraint`, `GM3D_PhysicsWorld` (~90
methods), `GM3D_CharacterControllerComponent`, all
`GM3D_PhysicsVehicle*`, `GM3D_RaycastHit/OverlapHit/ContactEvent`.
Samples 4/5/6, `working_directory +` load paths, `syncScene/step/
interpolate/restore` ordering.

### Deleted / superseded

- Single-shader assignment pattern.
- Manual recursive animator search (replaced by `find*`).
- Manual Euler free-look math (replaced by `updateMouselook`).
- Manual bounding-box accumulation (replaced by scene/mesh getters).
- “No physics” assumption: stable doc stated no collision/raycast/physics —
  Beta provides all three.

## API by type

Quick map; full signatures in `notes/GM3D_API.md`.

### Scene graph

| Type | Main members |
| --- | --- |
| `GM3D_Scene` | `createEmpty`, `loadGltf`, `createNode`, `getNode(s)`, `getMaterial(s)`, `setMaterial`, `getAnimation(s)`, `applyAnimation`, `hasAnimation`, `forEachMaterial`, `forEachNode`, `getBoundingBox/Sphere`, `spawnInto`, `freeze`, `update`, `destroy` |
| `GM3D_SceneNode` | hierarchy + `destroy(recursive?)`, direct + `find*` components, `forEachNode`, `findNodeByName`, local/world transforms + axes, `setLocalMatrix` |

### Components

| Type | Main members |
| --- | --- |
| `GM3D_CameraComponent` | projection, FOV/ortho, near/far (0=inf), target, render size, screen rect, order, alpha, enabled, `renderTexture/depthTexture`, `updateMouselook`, `screenPointToRay`, `worldToScreen` |
| `GM3D_AnimationComponent` | `play`, `pause`, `resume`, time, speed, enabled, `isPlaying` |
| `GM3D_LightComponent` | type, color, intensity, range, cones, enabled, shadow enabled/resolution/distance/normal-offset |
| `GM3D_EnvironmentVolumeComponent` | size (Vec3), ambient, fog color/start/end/enabled |
| `GM3D_MeshComponent` | mesh, material, enabled, flags |
| `GM3D_SkinnedMeshComponent` | mesh, material, enabled, flags, `jointCount` |
| `GM3D_PhysicsBodyComponent` | motion type, layer, mass, damping, gravity, sensor, awake, quality, sleeping, COM, locks, groups, contact callbacks |
| `GM3D_PhysicsShapeComponent` | shape type, half extents, offset, rotation, friction, restitution, subshape layer |
| `GM3D_PhysicsConstraintComponent` | type, nodes, pivots, axes, limits, cone/twist, springs, friction |
| `GM3D_CharacterControllerComponent` | radius, half-height, slope, step, layer, mass, strength, prediction, padding, recovery, edge removal, push flags |
| `GM3D_PhysicsVehicle*` | Wheel, Powertrain, Differential, AntiRollBar, Motorcycle, Tracked, Vehicle (wheels/diffs/bars/powertrain/settings/curves/tester) |

### Resources and rendering

| Type | Main members |
| --- | --- |
| `GM3D_Renderer` | `render(scene, deltaTime?)` |
| `GM3D_Material` | per-pass shader, uniforms, textures, blend/depth/stencil/cull/alpha/fog/lighting, clone/destroy |
| `GM3D_Shader` | global float/int/array/texture uniforms |
| `GM3D_Texture` | filter, repeat, mipmap, anisotropy (get + set) |
| `GM3D_Mesh` | name, buffer/format/primitive, skinning, `getBoundingBox` |
| `GM3D_Animation` | `path`, `duration` |
| `GM3D_PhysicsWorld` | construct, gravity, sync/add/remove/rebuild, step/interpolate/restore, velocities/forces/impulses, raycast/overlap/shapeCast/closest-point, contacts/activations, layers/groups, constraints, characters, vehicles, debug draw, destroy |
| Hits | `GM3D_RaycastHit{node,point,normal,distance}`, `GM3D_OverlapHit{node,closestPoint}`, `GM3D_ContactEvent{nodeA,nodeB,point,normal,impactVelocity,type,selfNode,otherNode}` |

### Enums

```gml
GM3D_ECameraProjection.Perspective / Orthographic
GM3D_ECameraRenderSizeMode.Auto / Fixed
GM3D_ECameraTarget.Screen / Texture
GM3D_ELightType.Directional / Point / Spot
GM3D_EMeshComponentFlags.CastShadows(=1) / ReceiveShadows(=2)
GM3D_ERenderPass.Shadow(=0) / Forward(=1) / Custom(=2 + N)
// Physics:
GM3D_EPhysicsMotionType.Static / Kinematic / Dynamic
GM3D_EPhysicsShapeType.Box / Sphere / Capsule / Cylinder / Mesh / ConvexHull / ConvexDecomposition
GM3D_EPhysicsLayer.Static(=1) / Default(=2) / Character(=4) / Trigger(=8) / Debris(=16) / All(=31)
GM3D_ECharacterGroundState.OnGround / OnSteepGround / NotSupported / InAir
GM3D_EPhysicsConstraintType.Fixed / Point / Hinge / Slider / Cone / Distance
GM3D_EPhysicsContactEvent.Enter / Stay / Exit
GM3D_EPhysicsContactEventMask.Enter(=1) / Stay(=2) / Exit(=4) / All(=7)
GM3D_EConstraintMotorMode.Off / Velocity / Position
GM3D_EPhysicsMotionQuality.Discrete / LinearCast
GM3D_EPhysicsAxisLock.None / X / Y / Z / All
GM3D_EPhysicsVehicleControllerType.Wheeled / Motorcycle / Tracked
GM3D_EPhysicsVehicleCollisionTesterType.Ray / CastSphere / CastCylinder
GM3D_EPhysicsTrackSide.Left / Right
```

## Documentation limits

- Beta index lists signatures + one-line descriptions, not semantics, units
  (mostly metres / seconds / radians — verify per method), or error cases.
- Constraint, motorcycle, tracked, overlap, and shape-cast APIs are indexed
  but have no sample coverage — behavior unverified here.
- `.glb` is the only format demonstrated; physics `Mesh` shape fidelity,
  skinning limits, and platform performance are not documented upstream.
- `GM3D_API.md` itself warns everything is experimental.

## Sources

- `https://github.com/YoYoGames/GM3D-Samples/tree/develop/scripts`
  (`scrMain`, `scrSampleAnimation`, `scrSampleCameraInput`,
  `scrSampleNodeFactory`, `scrSamplePhysicsSpawn`, `scrSampleScene`,
  `scrSampleVehicleSetup`, `scrUI`).
- `objects/` in the same branch (`objMain`, `objSample`,
  `objSample_0_Static` … `objSample_6_FPS` — Create/Step/Draw/Clean Up).
- `shaders/` — `shStatic/shAnimated` × `Instanced` × `Shadow` (8 variants).
- `notes/GM3D_API.md` — full struct/method/enum index (source for API tables).
- Base: `docs/GM3D.md` in this repository (stable structure and wording reused).
